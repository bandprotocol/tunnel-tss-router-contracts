// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import "./TssSignerHelper.sol";

contract TssVerifierTest is Test, TssSignerHelper {
    function testCalChallenge() public pure {
        assertEq(
            0x0c0753165ef3bd86580a99a06e89577319e79de82cb6b5ebf7e95ffc6204d118,
            challenge(
                27,
                address(0x8B54b734034523969E24d0107fa920744a8C97D6),
                0xe411efbe009f0f424c8320080a3fef3379dfb41932508b29ab8506c782788822,
                0x53a0c6434b51d1d77604497b43b5f5d413ba377d60ca04f7e06208e1b6fdbd50
            )
        );
        assertEq(
            0xe1540ce356e232409afec4a0ffc972a516d648d2a9dbc9acbb80af4e0a588cd3,
            challenge(
                27,
                address(0x225743E6566bE4Faa0F834bdA86b60FD0b9cF33d),
                0x258ea24862d6ff3c337cc125e8efefa87fb9d178fee0cf843afb1ae389a6db53,
                0x97acf51be6080597a20fae668f1161416f21f89963de35ece00b4da4d6bafd4e
            )
        );
        assertEq(
            0x4bcd43e95085f3593a3213bddaeb1de7357e0bea1ad16a90c26ece31e6fd3e79,
            challenge(
                27,
                address(0x4991030Be950BE3dD902612585Ff64a1e5d017ec),
                0xa6ffbcd81f51883fd64cda2bdc3150fe50ccbe27f482201467d4e7a7f1a5212e,
                0xdc72d2ddbfa8bdafa3984c7884dd2fd9af7b82e2128711b1c5c508b443cf3bb4
            )
        );
    }

    function testGetPubkey() public pure {
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

    function testSchnorrSign() public pure {
        uint256 secret = 0x383b4a7a98c26e381cf5149dade39a61b3f43e1af4ff1f78d17daf9ffaf35177;
        (uint8 parity, uint256 px) = getPubkey(secret);
        (address randomAddr, uint256 s) = sign(
            parity,
            px,
            0x427d0cfec0deb6332e7961cf387a8668730cda6f5b99c2821128dab11a5c362e,
            hex"dc72d2ddbfa8bdafa3984c7884dd2fd9af7b82e2128711b1c5c508b443cf3bb4",
            secret
        );
        assertEq(uint8(27), parity);
        assertEq(px, 0xa6ffbcd81f51883fd64cda2bdc3150fe50ccbe27f482201467d4e7a7f1a5212e);
        assertEq(randomAddr, address(0x4991030Be950BE3dD902612585Ff64a1e5d017ec));
        assertEq(s, 0xc8727773e662c4c23db072ce0ce27b1ffe3f4ee8a93460efdf61b5a9af5edffd);
        secret = 0x05cff511ca26b944fb22285c8a56595baeefe399d49e5aeef27233701b59b8ad;
        (parity, px) = getPubkey(secret);
        (randomAddr, s) = sign(
            parity,
            px,
            0x419d15a75ccf9809027431b7b42cf1e0b2403eeca686fdca8497f8309b62d363,
            hex"661cde0d0f34a8c975409889bdc9d78e3b0e6c1d66997b03989d1ae3bfd14fc3",
            secret
        );
        assertEq(uint8(28), parity);
        assertEq(px, 0xa221bfe76ca3ae50df876afda2701cb1cad0527e28d0680f8af00ce14e6b079a);
        assertEq(randomAddr, address(0x2F7f7613Ab95bff1a6B23F3AFD3fA6dd80F04461));
        assertEq(s, 0xefb10cb564c33dca7d57a697941f4d182f5e80fa351a20ed5538453d6d8c2393);
    }
}
