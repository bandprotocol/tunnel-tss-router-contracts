// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/FutureBridge.sol";
import "../src/SECP256k1.sol";

contract FutureBridgeTest is Test {
	// secp256k1 group order
	uint256 public constant ORDER = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
	bytes32 public constant UPDATE_KEY_OPERATION_HASH = keccak256(bytes("UPDATE_KEY_OPERATION_HASH"));

	FutureBridge public so;

	function setUp() public {
		so = new FutureBridge(27, 0xe3e216b180a2a8ec316d500faa7a44c43a87f8adcb54c553c6277d3e220a40c8);
	}

	function challenge(
		uint8 _parity,
		address rAddress,
		uint256 _px,
		bytes32 messageHash
	) public pure returns (uint256 c) {
		c = uint256(keccak256(abi.encodePacked(rAddress, _parity, _px, messageHash)));
	}

	function getPubkey(uint256 privateKey) public pure returns (uint8 parity, uint256 px) {
		uint256 py;
		(px, py) = SECP256k1.publicKey(privateKey);
		parity = 27;
		if (py & 1 == 1) {
			parity = 28;
		}
	}

	function schnorrSign(
		uint8 parity,
		uint256 px,
		bytes32 messageHash,
		uint256 privateKey
	) public pure returns (address rAddress, uint256 s) {
		// R = G * k
		uint256 k = uint256(keccak256(abi.encodePacked("salt", privateKey)));
		rAddress = vm.addr(k);

		// c = h(address(R) || compressed pubkey || m)
		uint256 c = challenge(parity, rAddress, px, messageHash);

		// cx = c*x
		uint256 cx = mulmod(c, privateKey, ORDER);

		// s = k + cx
		s = addmod(k, cx, ORDER);
	}

	function test_k_to_rAddress() public {
		assertEq(
			address(0xaAFCf9Fd2538919B20b6D92194BAA56106e55869),
			vm.addr(0x594488dd413dc58a35ddfdc13b632c9f893d6016aa063f25ab16610f124e3c69)
		);
		assertEq(
			address(0x903294c5B10708CF8b7747925d067fc2fFe526f3),
			vm.addr(0x26c3697cc95001f66e9d3826d41149bb10db2ac3b96cc2a5e936f1701639d1e5)
		);
	}

	function test_cal_challenge() public {
		assertEq(
			0x9579241dedad1ae4a2d944c22be86421de9f4962c0f5d3703e51cb1a19d1015b,
			challenge(
				27,
				address(0x8B54b734034523969E24d0107fa920744a8C97D6),
				0xe411efbe009f0f424c8320080a3fef3379dfb41932508b29ab8506c782788822,
				0x53a0c6434b51d1d77604497b43b5f5d413ba377d60ca04f7e06208e1b6fdbd50
			)
		);
		assertEq(
			0xfaa5c6ded8167ea3d72af6dcfc589d2bcebc1a9883acc393cdde502e6ba11c5b,
			challenge(
				27,
				address(0x225743E6566bE4Faa0F834bdA86b60FD0b9cF33d),
				0x258ea24862d6ff3c337cc125e8efefa87fb9d178fee0cf843afb1ae389a6db53,
				0x97acf51be6080597a20fae668f1161416f21f89963de35ece00b4da4d6bafd4e
			)
		);
	}

	function test_getPubkey() public {
		uint8 parity;
		uint256 px;

		(parity, px) = getPubkey(0xbbfee063f4b3af6cfb1e3b69944401d36dee7d295753f8e47934ce6e63e2d2d0);
		assertEq(uint8(27), parity);
		assertEq(0xbbc14502dc6f2fb3dce112a7237a57420c3b302204f021dfa60d18446789eaaa, px);

		(parity, px) = getPubkey(0x5575ba296d17a5241c58517b9c235586a2ab77deeb1b4299ecd027ace48c67d1);
		assertEq(uint8(28), parity);
		assertEq(0xd8c41847e84013f83ab06e98d5fbf75f7117ee0f20c45415c5216e7ba273789b, px);

		(parity, px) = getPubkey(0x672c7b975947e5ba6fa739540df1c7f53d0275aea1d23e626e036bec4aa24b57);
		assertEq(uint8(27), parity);
		assertEq(0x2459b0c6f115152e906d6650662109abb5f23812dc1d990dc2c1460283bc42a1, px);

		(parity, px) = getPubkey(0x93942b3b629d2464ef9eb112547de73c8043fcd6ef7ccc9bbe2325af1dbbadc8);
		assertEq(uint8(28), parity);
		assertEq(0xc266a897cf8155706f68608316c43d3ee34b600d7fc472ce487bb17cf7a5bd41, px);
	}

	function test_schnorrSign() public {
		(uint8 parity, uint256 px) = getPubkey(0x0476e639d864bd63f33c5bd8be3f5310fe3aa2768e934b8619b63e3cb6f8f9dd);
		(address rAddress, uint256 s) = schnorrSign(
			parity,
			px,
			hex"d63998219b321a434750448bdf5d7474f30befcf57157346dc3af1839a43d666",
			0x0476e639d864bd63f33c5bd8be3f5310fe3aa2768e934b8619b63e3cb6f8f9dd
		);
		assertEq(uint8(28), parity);
		assertEq(0x83a38b88ec6fb48b4ade03b58f6a298b7b45da6dd9468ffdc348331ac9784189, px);
		assertEq(address(0xFbc4Ce7C877858f60AD33fcE77Fda71f864FE82E), rAddress);
		assertEq(0x1cfcbb7275284f780b1829f4c5f263bc513f3f2e12ccb68f28da09d0e2d48ac5, s);

		(parity, px) = getPubkey(0x0be8520e9b67260bd7ec68c9d937a2ae0e11efee528dda48c6b1ff38e21588b2);
		(rAddress, s) = schnorrSign(
			parity,
			px,
			hex"3c740a1734c898f7ab1f9889e00ac96a717da51c74977086b436cf7f02bade24",
			0x0be8520e9b67260bd7ec68c9d937a2ae0e11efee528dda48c6b1ff38e21588b2
		);
		assertEq(uint8(27), parity);
		assertEq(0xc9514cb0e4fb09a827ca14401f7b254681dca69f464e948563e4874ada83fda6, px);
		assertEq(address(0x0a42bae6401fFC346c4e7Ba29FB0b1E51Ef7026D), rAddress);
		assertEq(0xb57cc365b16318dfd2e451836bc6763a42319a009178469eac3304f85ef6b7a0, s);
	}

	function test_verify() public {
		uint256 numRound = 100;
		uint256 gasUsedVerifyAcc = 0;
		uint256 gasUsedUpdateAcc = 0;
		bytes32 seed = keccak256(abi.encode("initial_random_seed"));
		uint256 privateKey = uint256(keccak256(abi.encode(seed, "privateKey")));

		for (uint256 i = 0; i < numRound; i++) {
			bytes32 anyMessageHash = keccak256(abi.encode(seed, "any message to be sign"));
			(uint8 parity, uint256 px) = getPubkey(privateKey);
			(address rAddress, uint256 s) = schnorrSign(parity, px, anyMessageHash, privateKey);

			uint256 start = gasleft();
			// verify signature
			assertEq(true, so.verify(rAddress, s, anyMessageHash));
			gasUsedVerifyAcc += start - gasleft();

			// calculate variables for the next round
			seed = keccak256(abi.encode(seed, i));

			// update pubkey
			(uint8 newParity, uint256 newPx) = getPubkey(uint256(keccak256(abi.encode(seed, "next privateKey"))));
			bytes32 messageHash = keccak256(abi.encode(UPDATE_KEY_OPERATION_HASH, newParity, newPx));
			(rAddress, s) = schnorrSign(parity, px, messageHash, privateKey);

			start = gasleft();
			so.updatePubkey(newParity, rAddress, newPx, s);
			gasUsedUpdateAcc += start - gasleft();

			assertEq(so.parity(), newParity);
			assertEq(so.px(), newPx);

			privateKey = uint256(keccak256(abi.encode(seed, "next privateKey")));

			if (i == 0) {
				console.log("initial verify gas avg = ", gasUsedVerifyAcc);
				console.log("initial update pubkey gas avg = ", gasUsedUpdateAcc);
			}
		}

		console.log("verify gas avg = ", gasUsedVerifyAcc / numRound);
		console.log("update pubkey gas avg = ", gasUsedUpdateAcc / numRound);
	}
}
