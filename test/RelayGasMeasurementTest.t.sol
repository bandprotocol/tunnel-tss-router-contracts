// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/libraries/Originator.sol";
import "../src/router/GasPriceTunnelRouter.sol";
import "../src/PacketConsumer.sol";
import "../src/TssVerifier.sol";
import "../src/Vault.sol";
import "./helper/Constants.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./helper/RegressionTestHelper.sol";

/**
 * @title RelayGasMeasurementTest
 * @notice Measures router-internal gas for `relay(...)`, fits simple models (linear/quadratic/cubic)
 *         against calldata size, and validates model quality via cross-validation. Also calibrates
 *         `packedAdditionalGasFuncCoeffs` on the router from a quadratic fit and checks the residual error.
 *
 *         ⚠️ This test measures *nested-call* gas (not a standalone transaction).
 *         It excludes tx intrinsic (21k), tx.data gas, and per-tx cold penalties.
 */
contract RelayGasMeasurementTest is Test, Constants {
    // --- Deployed contracts under test ---
    PacketConsumer packetConsumer;
    GasPriceTunnelRouter tunnelRouter;
    TssVerifier tssVerifier;
    Vault vault;

    // --- Log topics (optional sanity checks) ---
    bytes32 constant withdrawnTopic =
        keccak256("Withdrawn(bytes32,address,uint256)");
    bytes32 constant messageProcessedTopic =
        keccak256("MessageProcessed(bytes32,uint64,bool)");

    // --- Chain identifiers (hashed) used in originator hash derivation ---
    bytes32 constant sourceChainIdHash = keccak256("bandchain");
    bytes32 constant targetChainIdHash = keccak256("testnet-evm");

    // --- Originator (precomputed for this test setup) ---
    bytes32 constant originatorHash =
        0x1930634c04eaace73b84b572782f354be5c6c84233d24c0ede853409d89c3585;

    // --- Test relayer address (whitelisted) ---
    address immutable relayer = makeAddr("relayer");

    // --- Workload shape & time seeds ---
    uint64 constant tunnelId = 1;
    uint256 constant TOTAL_SIGNALS = 200; // max signals per synthetic packet
    int64 timestamp = 1753867982; // synthetic timestamp seed
    uint64 sequence = 1;
    uint256 priceRandomSeed = 999; // pseudo-random price seed

    // --- Training/validation datasets ---
    // Pack (x, y) as (calldataLen << 128) | baseGas, where x,y < 2^128.
    uint256[] trainingSet;
    uint256[] validationSet;

    // --- Baseline relayGas records used by the calibration test ---
    uint256[] relayGasBaseline;

    // --- Metric containers for three models (linear/quadratic/cubic) ---
    struct MetricsTriple {
        uint256 linearResult;
        uint256 quadraticResult;
        uint256 cubicResult;
    }

    // --- All four metrics (MAE/RMSE/min/max) ---
    struct MetricSet {
        uint256 maeErr;
        uint256 rmsErr;
        uint256 minErr;
        uint256 maxErr;
    }

    // --- Evaluation across the three models ---
    struct Evaluation {
        MetricsTriple mae;
        MetricsTriple rms;
        MetricsTriple min;
        MetricsTriple max;
    }

    // ------------------------------------------------------------------------
    // Setup
    // ------------------------------------------------------------------------

    function setUp() public {
        tssVerifier = new TssVerifier(86400, 0x00, address(this));
        tssVerifier.addPubKeyByOwner(
            0,
            CURRENT_GROUP_PARITY - 25,
            CURRENT_GROUP_PX
        );

        vault = new Vault();
        vault.initialize(address(this), address(0x00));
        tunnelRouter = new GasPriceTunnelRouter();

        // set tx.gasprice to 1
        vm.txGasPrice(1);
        // set additionalGas_ = 0 and gasPrice_ = 1
        tunnelRouter.initialize(
            tssVerifier,
            vault,
            0,
            14000,
            // relaying 200 signals simultaneously will consume a significant amount of gas
            10_000_000,
            1,
            sourceChainIdHash,
            targetChainIdHash,
            true
        );

        address[] memory whitelist = new address[](1);
        whitelist[0] = relayer;
        tunnelRouter.grantRelayer(whitelist);

        vault.setTunnelRouter(address(tunnelRouter));

        // deploy packet Consumer with specific address.
        bytes memory packetConsumerArgs = abi.encode(
            address(tunnelRouter),
            address(this)
        );
        address packetConsumerAddr = makeAddr("PacketConsumer");
        deployCodeTo(
            "PacketConsumer.sol:PacketConsumer",
            packetConsumerArgs,
            packetConsumerAddr
        );

        packetConsumer = PacketConsumer(payable(packetConsumerAddr));

        // set latest nonce.
        packetConsumer.activate{value: 1 ether}(tunnelId, 0);

        assertEq(
            originatorHash,
            Originator.hash(
                tunnelRouter.sourceChainIdHash(),
                1,
                tunnelRouter.targetChainIdHash(),
                address(packetConsumer)
            )
        );
    }

    // ------------------------------------------------------------------------
    // Metric helpers
    // ------------------------------------------------------------------------

    /**
     * @notice Root-mean-squared error between preds and true values (unscaled).
     * @dev Guards against (a*a) overflow by requiring a <= 2^128-1.
     */
    function _rmsError(
        int256[] memory preds,
        int256[] memory vals
    ) internal pure returns (uint256) {
        uint256 n = preds.length;
        require(n > 0 && n == vals.length, "rms: bad len");

        uint256 acc = 0;
        for (uint256 i = 0; i < n; i++) {
            int256 d = vals[i] - preds[i];
            uint256 a = d < 0 ? uint256(-d) : uint256(d);
            // Ensure a*a won’t overflow (optional but defensive)
            require(a <= type(uint128).max, "rms: err too big");
            acc += a * a;
        }

        // mean square
        return Math.sqrt(acc / n);
    }

    /**
     * @notice Mean absolute error (unscaled).
     */
    function _meanAbsError(
        int256[] memory preds,
        int256[] memory vals
    ) internal pure returns (uint256) {
        uint256 n = preds.length;
        require(n > 0 && n == vals.length, "mae: bad len");

        uint256 acc = 0;
        for (uint256 i = 0; i < n; i++) {
            int256 d = vals[i] - preds[i];
            // absolute value as uint256
            uint256 a = d < 0 ? uint256(-d) : uint256(d);
            acc += a;
        }

        // mean
        return acc / n;
    }

    /**
     * @notice Maximum absolute error (unscaled).
     */
    function _maxAbsError(
        int256[] memory preds,
        int256[] memory vals
    ) internal pure returns (uint256 m) {
        uint256 n = preds.length;
        require(n > 0 && n == vals.length, "max: bad len");
        for (uint256 i = 0; i < n; i++) {
            int256 d = vals[i] - preds[i];
            uint256 a = d < 0 ? uint256(-d) : uint256(d);
            if (a > m) m = a;
        }
    }

    /**
     * @notice Minimum absolute error (unscaled).
     */
    function _minAbsError(
        int256[] memory preds,
        int256[] memory vals
    ) internal pure returns (uint256 m) {
        uint256 n = preds.length;
        require(n > 0 && n == vals.length, "min: bad len");
        m = type(uint256).max;
        for (uint256 i = 0; i < n; i++) {
            int256 d = vals[i] - preds[i];
            uint256 a = d < 0 ? uint256(-d) : uint256(d);
            if (a < m) m = a;
        }
    }

    /**
     * @notice Computes all four metrics for a set of predictions.
     */
    function _computeMetrics(
        int256[] memory preds,
        int256[] memory y
    ) internal pure returns (MetricSet memory m) {
        m.maeErr = _meanAbsError(preds, y);
        m.rmsErr = _rmsError(preds, y);
        m.minErr = _minAbsError(preds, y);
        m.maxErr = _maxAbsError(preds, y);
    }

    /**
     * @notice Asserts the quadratic model is optimal (<=) among linear/quadratic/cubic for a metric.
     */
    function _assertQuadIsOptimal(MetricsTriple memory m) internal pure {
        require(
            m.quadraticResult <= m.linearResult &&
                m.quadraticResult <= m.cubicResult,
            "quadratic is not the optimal"
        );
    }

    /**
     * @notice Logs a compact triple (linear/quadratic/cubic) for a metric line.
     */
    function _logTriple(
        string memory label,
        MetricsTriple memory m
    ) internal pure {
        console.log(label, m.linearResult, m.quadraticResult, m.cubicResult);
    }

    /**
     * @notice Evaluates linear/quadratic/cubic models on (x) and computes metrics vs ground truth (y).
     */
    function _evaluateAll(
        RegressionTestHelper.Linear memory fx,
        RegressionTestHelper.Quadratic memory gx,
        RegressionTestHelper.Cubic memory hx,
        int256[] memory x,
        int256[] memory y
    ) internal pure returns (Evaluation memory ev) {
        int256[] memory yL = RegressionTestHelper.evaluateLinear(fx, x);
        int256[] memory yQ = RegressionTestHelper.evaluateQuadratic(gx, x);
        int256[] memory yC = RegressionTestHelper.evaluateCubic(hx, x);

        MetricSet memory l = _computeMetrics(yL, y);
        MetricSet memory q = _computeMetrics(yQ, y);
        MetricSet memory c = _computeMetrics(yC, y);

        ev.mae = MetricsTriple(l.maeErr, q.maeErr, c.maeErr);
        ev.rms = MetricsTriple(l.rmsErr, q.rmsErr, c.rmsErr);
        ev.min = MetricsTriple(l.minErr, q.minErr, c.minErr);
        ev.max = MetricsTriple(l.maxErr, q.maxErr, c.maxErr);
    }

    // ------------------------------------------------------------------------
    // Synthetic packet helpers
    // ------------------------------------------------------------------------

    /**
     * @notice Builds a 32-byte signal key from `"forcing_a_signal_2b_32_bytes_" + i`.
     * @dev Right-aligns ASCII into low bytes (shifted) to match `bytes32` key usage.
     *      If your consumer uses `string` keys, build the same string on both write+read paths.
     */
    function _signal(uint256 i) internal pure returns (bytes32 s) {
        string memory _s = string(
            abi.encodePacked("forcing_a_signal_2b_32_bytes_", vm.toString(i))
        );
        assertTrue(bytes(_s).length <= 32);
        assembly {
            s := mload(add(_s, 32))
        }
        s >>= (32 - bytes(_s).length) * 8;
    }

    /**
     * @notice Pseudo-random 64-bit price (upper bits zeroed to fit `uint64` in on-chain structs if needed).
     */
    function _price(
        uint256 i,
        uint256 priceRandomSeed_
    ) internal pure returns (uint256 price) {
        price =
            0xffffffffffffffff &
            uint256(keccak256(abi.encode(i, priceRandomSeed_)));
    }

    /**
     * @notice Encodes a synthetic TSS message bytes for `relay`.
     * @dev Layout mirrors your earlier construction. The signals section appends (signal, price) pairs.
     */
    function _generateTssm(
        bytes32 originatorHash_,
        int64 timestamp_,
        uint64 sequence_,
        uint256 priceRandomSeed_,
        uint256 numberOfSignals
    ) internal pure returns (bytes memory tssm) {
        tssm = abi.encodePacked(
            originatorHash_,
            timestamp_,
            hex"0000000000000001",
            hex"d3813e0ccba0ad5a",
            hex"0000000000000000000000000000000000000000000000000000000000000020",
            uint256(sequence_),
            hex"0000000000000000000000000000000000000000000000000000000000000060",
            int256(timestamp_),
            numberOfSignals
        );
        for (uint256 i = 0; i < numberOfSignals; i++) {
            tssm = abi.encodePacked(
                tssm,
                _signal(i),
                _price(i, priceRandomSeed_)
            );
        }
    }

    // ------------------------------------------------------------------------
    // Measurement helper
    // ------------------------------------------------------------------------

    /**
     * @notice Calls `relay(...)` as a nested call and measures:
     *         - `relayGas`: router-internal gas for `relay(...)` (gasleft() delta)
     *         - `targetGasUsed`: what router pays to msg.sender (relayer) as fee (gasPrice=1, additionalGas=0 initially)
     *         - `calldataLen`: ABI-encoded calldata length for `relay(...)`
     *
     * @dev The consumer key read below must match the key used by the consumer when writing.
     *
     * NOTE: This is a *nested call* inside the Foundry test transaction.
     * baseGas := relayGas - targetGasUsed
     * is therefore the router-side residual overhead (decode/verify/loop/events/etc.),
     * excluding any transaction-level costs (intrinsic 21k, calldata 4/16 gas/byte, per-tx cold penalties).
     */
    function _relayNSignals(
        int64 timestamp_,
        uint64 sequence_,
        uint256 priceRandomSeed_,
        uint256 numberOfSignals
    )
        internal
        returns (uint256 calldataLen, uint256 targetGasUsed, uint256 relayGas)
    {
        uint256 relayerBalance = relayer.balance;

        bytes memory tssm = _generateTssm(
            originatorHash,
            timestamp_,
            sequence_,
            priceRandomSeed_,
            numberOfSignals
        );

        (address rAddr, uint256 s) = Constants.signTssm(
            tssm,
            uint256(keccak256(abi.encode(numberOfSignals)))
        );

        vm.prank(relayer);
        relayGas = gasleft();
        tunnelRouter.relay(tssm, rAddr, s);
        relayGas = relayGas - gasleft();

        PacketConsumer.Price memory p;
        for (uint256 i = 0; i < numberOfSignals; i++) {
            p = packetConsumer.getPrice(string(abi.encodePacked(_signal(i))));
            assertEq(p.price, _price(i, priceRandomSeed_));
            assertEq(p.timestamp, timestamp_);
        }

        assertEq(tunnelRouter.sequence(originatorHash), sequence_);

        // the targetGasUsed should be equal to the feeGain because the gasPrice was set to 1 and the additional gas was set to 0
        targetGasUsed = relayer.balance - relayerBalance;

        calldataLen = abi
            .encodeWithSignature("relay(bytes,address,uint256)", tssm, rAddr, s)
            .length;
    }

    // ------------------------------------------------------------------------
    // Cross-validation harness
    // ------------------------------------------------------------------------

    /**
     * @notice Splits the dataset with `split(i)` => training/validation, fits models on training,
     *         and evaluates them on validation. Prints metric triples (l, q, c) per metric.
     *
     * @dev Packs pairs as (calldataLen << 128) | baseGas; asserts bounds to prevent overflow.
     *
     * Cross-validation harness: split dataset by `split(i)` into (train, valid).
     * We pack pairs (x = calldataLen, y = baseGas) into 2x128 bits to feed the regression helpers.
     * The regressors return models from the *training* subset; we compute metrics on the *validation* subset.
     * We only rank models here (Linear vs Quadratic vs Cubic), not reconstruct full tx gasUsed.
     */
    function _crossValidate(
        function(uint256) internal pure returns (bool) split
    ) internal {
        for (uint256 i = 0; i < TOTAL_SIGNALS; i++) {
            uint256 snapshotId = vm.snapshot();
            assembly {
                // Reset free memory pointer to initial value (0x80) to avoid accumulation
                mstore(0x40, 0x80)
            }

            (
                uint256 calldataLen,
                uint256 targetGasUsed,
                uint256 relayGas
            ) = _relayNSignals(timestamp, sequence, priceRandomSeed, i);
            vm.revertTo(snapshotId);

            uint256 baseGas = relayGas - targetGasUsed;
            assertTrue(baseGas > 0);

            if (split(i)) trainingSet.push((calldataLen << 128) + baseGas);
            else validationSet.push((calldataLen << 128) + baseGas);

            timestamp++;
            priceRandomSeed++;
        }

        int256[] memory validationX = new int256[](validationSet.length);
        int256[] memory validationY = new int256[](validationSet.length);
        for (uint256 i = 0; i < validationSet.length; i++) {
            validationX[i] = int256(validationSet[i] >> 128);
            validationY[i] = int256(validationSet[i] & ((1 << 128) - 1));
        }

        Evaluation memory ev = _evaluateAll(
            RegressionTestHelper.linear(trainingSet),
            RegressionTestHelper.quadratic(trainingSet),
            RegressionTestHelper.cubic(trainingSet),
            validationX,
            validationY
        );

        console.log("metrics\\models:  l  q  c");

        _logTriple("mae           :", ev.mae);
        _assertQuadIsOptimal(ev.mae);

        _logTriple("rms           :", ev.rms);
        _assertQuadIsOptimal(ev.rms);

        _logTriple("min           :", ev.min);
        _assertQuadIsOptimal(ev.min);

        _logTriple("max           :", ev.max);
        _assertQuadIsOptimal(ev.max);
    }

    // --- Splitters for cross-validation ---

    function _isFirstHalf(uint256 i) internal pure returns (bool) {
        return i < TOTAL_SIGNALS / 2;
    }

    function _isLastHalf(uint256 i) internal pure returns (bool) {
        return i >= TOTAL_SIGNALS / 2;
    }

    function _isFirstQuartile(uint256 i) internal pure returns (bool) {
        return i < TOTAL_SIGNALS / 4;
    }

    function _isLastQuartile(uint256 i) internal pure returns (bool) {
        return i >= (3 * TOTAL_SIGNALS) / 4;
    }

    // --- Tests using the cross-validation ---

    function testFit_FirstHalf_vs_LastHalf() public {
        _crossValidate(_isFirstHalf);
    }

    function testFit_LastHalf_vs_FirstHalf() public {
        _crossValidate(_isLastHalf);
    }

    function testFit_FirstQuartile_vs_Rest() public {
        _crossValidate(_isFirstQuartile);
    }

    function testFit_LastQuartile_vs_Rest() public {
        _crossValidate(_isLastQuartile);
    }

    // ------------------------------------------------------------------------
    // Calibration test for `packedAdditionalGasFuncCoeffs`
    // ------------------------------------------------------------------------

    /**
     * @notice Fit a quadratic model on baseline data to derive `packedAdditionalGasFuncCoeffs`, set it on the router,
     *         and verify the residual error against `targetGasUsed` is small after compensating for
     *         empirical warm/cold deltas.
     *
     * @dev Uses a simple absolute tolerance on the residual (< 50 gas) and an empirical relayGas
     *      delta window (4000..4500). Widen/tune these bands if your environment changes.
     */
    function testCalibratingAdditionalGasUsed() public {
        // -------- Phase 1: baseline (no additionalGasUsed) --------
        uint256 snapshotId;
        for (uint256 i = 0; i < TOTAL_SIGNALS / 2; i++) {
            snapshotId = vm.snapshot();
            assembly {
                // Reset free memory pointer to initial value (0x80) to avoid accumulation
                mstore(0x40, 0x80)
            }

            (
                uint256 calldataLen,
                uint256 targetGasUsed,
                uint256 relayGas
            ) = _relayNSignals(timestamp, sequence, priceRandomSeed, i);
            vm.revertTo(snapshotId);

            relayGasBaseline.push(relayGas);

            uint256 baseGas = relayGas - targetGasUsed;
            assertTrue(baseGas > 0);

            trainingSet.push((calldataLen << 128) + baseGas);

            timestamp++;
            priceRandomSeed++;
        }

        // Derive the quadratic parameters
        RegressionTestHelper.Quadratic memory quad = RegressionTestHelper
            .quadratic(trainingSet);
        require(quad.c2 > 0 && quad.c1 > 0 && quad.c0 > 0, "bad quad fit");

        // Pack [c2|c1|c0] into 3x80-bit lanes (adjust if your on-chain format differs)
        {
            uint256 c2 = uint256(quad.c2);
            require(c2 < (1 << 80), "c2 too large");
            uint256 c1 = uint256(quad.c1);
            require(c1 < (1 << 80), "c1 too large");
            uint256 c0 = uint256(quad.c0);
            require(c0 < (1 << 80), "c0 too large");

            uint256 packedCoeffs = (c2 << 160) | (c1 << 80) | c0;

            // NOTE: This call warms router storage for the rest of THIS transaction.
            tunnelRouter.setPackedAdditionalGasFuncCoeffs(packedCoeffs);
        }

        // -------- Phase 2: verify compensation --------
        uint256 sumRelayGasDiff = 0;
        for (uint256 i = 0; i < TOTAL_SIGNALS; i++) {
            snapshotId = vm.snapshot();
            assembly {
                // Reset free memory pointer to initial value (0x80) to avoid accumulation
                mstore(0x40, 0x80)
            }

            (, uint256 targetGasUsed, uint256 relayGas) = _relayNSignals(
                timestamp,
                sequence,
                priceRandomSeed,
                i
            );
            vm.revertTo(snapshotId);
            assertTrue(targetGasUsed > 0 && relayGas > 0);

            uint256 relayGasDiff;
            if (i < relayGasBaseline.length) {
                // Avoid underflow: take absolute difference and then require it’s in an expected window.
                if (relayGasBaseline[i] >= relayGas) {
                    relayGasDiff = relayGasBaseline[i] - relayGas;
                } else {
                    relayGasDiff = relayGas - relayGasBaseline[i];
                }

                // The expected delta is mostly from account/slot cold→warm and/or extra code path changes.
                // For many cases 6.4k..6.6k is a reasonable envelope as it was derived from this test itself.
                require(
                    relayGasDiff >= 6400 && relayGasDiff <= 6600,
                    "relayGasDiff out of bound"
                );

                sumRelayGasDiff += relayGasDiff;
            } else {
                // fallback to the mean of the observed deltas
                relayGasDiff = sumRelayGasDiff / relayGasBaseline.length;
            }

            // After calibration we want: targetGasUsed ≈ relayGas (+ delta due to warmth/code path)
            // Compute absolute error with the compensated router gas.
            int256 err = int256(targetGasUsed) -
                int256(relayGas + relayGasDiff);
            uint256 absErr = err < 0 ? uint256(-err) : uint256(err);

            // The residual should be small.
            require(absErr < 50, "residual too large");

            timestamp++;
            priceRandomSeed++;
        }
    }
}
