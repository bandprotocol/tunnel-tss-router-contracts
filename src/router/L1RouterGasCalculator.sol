// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title L1RouterGasCalculator
 * @notice Owns and evaluates a quadratic model for base gas as a function of calldata size.
 *
 * packedAdditionalGasFuncCoeffs layout (fixed-point 1e18):
 *   packed = [ c2 | c1 | c0 ], each ci is uint80 (0..2^80-1) representing ci/1e18
 *
 * f(x) = (c2*x^2 + c1*x + c0) / 1e18, where x = calldata size in bytes.
 *
 */
abstract contract L1RouterGasCalculator is
    Initializable,
    AccessControlUpgradeable
{
    // ----- packing constants -----
    uint256 internal constant COEFF_BITS = 80;
    uint256 internal constant COEFF_MASK = (uint256(1) << COEFF_BITS) - 1;
    uint256 internal constant FP_SCALE = 1e18;
    uint256 internal constant SHIFT_C1 = COEFF_BITS;
    uint256 internal constant SHIFT_C2 = COEFF_BITS * 2;

    /// @dev packed coefficients: [c2 (80b) | c1 (80b) | c0 (80b)]
    uint256 public packedAdditionalGasFuncCoeffs;

    /// @dev maximum calldata length (bytes) the model will accept.
    uint256 public maxCalldataBytes;

    /**
     * @notice Emitted when the packed coefficients are updated.
     * @param packedCoeffs The new packed value [c2|c1|c0] (fixed-point 1e18 lanes).
     */
    event PackedAdditionalGasFuncCoeffsSet(uint256 packedCoeffs);

    /**
     * @notice Emitted when the maximum supported calldata length is updated.
     * @param maxBytes New maximum calldata bytes accepted by the model.
     */
    event MaxCalldataBytesSet(uint256 maxBytes);

    error CoefficientOutOfRange(); // any ci > 2^80-1
    error CalldataSizeTooLarge(uint256 got, uint256 maxAllowed);

    function __L1RouterGasCalculator_init(
        uint256 packedCoeffs,
        uint256 maxBytes
    ) internal onlyInitializing {
        _setPackedAdditionalGasFuncCoeffs(packedCoeffs);
        _setMaxCalldataBytes(maxBytes);
    }

    /// @notice Pack 3×80-bit fixed-point (1e18) coefficients into one uint256.
    function packCoeffs(
        uint256 c2,
        uint256 c1,
        uint256 c0
    ) public pure returns (uint256 packedCoeffs) {
        if (c2 > COEFF_MASK || c1 > COEFF_MASK || c0 > COEFF_MASK) {
            revert CoefficientOutOfRange();
        }
        unchecked {
            packedCoeffs = (c2 << SHIFT_C2) | (c1 << SHIFT_C1) | c0;
        }
    }

    /// @notice Unpack a provided packed value into its (c2, c1, c0) lanes.
    function unpackCoeffs(
        uint256 packedCoeffs
    ) public pure returns (uint256 c2, uint256 c1, uint256 c0) {
        unchecked {
            c2 = (packedCoeffs >> SHIFT_C2) & COEFF_MASK;
            c1 = (packedCoeffs >> SHIFT_C1) & COEFF_MASK;
            c0 = packedCoeffs & COEFF_MASK;
        }
    }

    /// @notice View the currently stored coefficients.
    function currentCoeffs()
        public
        view
        returns (uint256 c2, uint256 c1, uint256 c0)
    {
        return unpackCoeffs(packedAdditionalGasFuncCoeffs);
    }

    /// @dev Store a new packed coefficient triple and emit.
    function _setPackedAdditionalGasFuncCoeffs(uint256 packedCoeffs) internal {
        packedAdditionalGasFuncCoeffs = packedCoeffs;
        emit PackedAdditionalGasFuncCoeffsSet(packedCoeffs);
    }

    /// @notice Admin: set the maximum accepted calldata bytes.
    function setMaxCalldataBytes(uint256 maxBytes) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMaxCalldataBytes(maxBytes);
    }

    /// @dev Internal setter with event.
    function _setMaxCalldataBytes(uint256 maxBytes) internal {
        maxCalldataBytes = maxBytes;
        emit MaxCalldataBytesSet(maxBytes);
    }

    /**
     * @dev Evaluate baseGas(x) in *gas units* for a calldata length `x` (bytes).
     *      Reverts if `x` exceeds `maxCalldataBytes`.
     *      Returns the quadratic (c2*x^2 + c1*x + c0)/1e18 using the stored coefficients.
     *
     * @param x Calldata size in bytes (i.e., `calldatasize()` when called from a router).
     */
    function _additionalGasForCalldata(
        uint256 x
    ) internal view returns (uint256 y) {
        if (x > maxCalldataBytes)
            revert CalldataSizeTooLarge(x, maxCalldataBytes);
        (uint256 c2, uint256 c1, uint256 c0) = unpackCoeffs(
            packedAdditionalGasFuncCoeffs
        );
        unchecked {
            y = (c2 * x * x + c1 * x + c0) / FP_SCALE;
        }
    }

    /// @notice Public preview of baseGas(x) using the stored coefficients.
    function additionalGasForCalldata(
        uint256 x
    ) external view returns (uint256 y) {
        return _additionalGasForCalldata(x);
    }
}
