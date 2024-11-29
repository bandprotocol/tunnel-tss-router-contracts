// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

/*
Taken from https://github.com/jbaylina/ecsol and https://github.com/1Address/ecsol

License: GPL-3.0
*/

// This library was included solely for testing purposes and is not a component of FutureBridge.
library SECP256k1 {
    uint256 public constant GX = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
    uint256 public constant GY = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;
    uint256 public constant N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
    uint256 public constant A = 0;
    uint256 public constant B = 7;

    function order() public pure returns (uint256) {
        return N;
    }

    function _jAdd(uint256 x1, uint256 z1, uint256 x2, uint256 z2) public pure returns (uint256 x3, uint256 z3) {
        (x3, z3) = (addmod(mulmod(z2, x1, N), mulmod(x2, z1, N), N), mulmod(z1, z2, N));
    }

    function _jSub(uint256 x1, uint256 z1, uint256 x2, uint256 z2) public pure returns (uint256 x3, uint256 z3) {
        (x3, z3) = (addmod(mulmod(z2, x1, N), mulmod(N - x2, z1, N), N), mulmod(z1, z2, N));
    }

    function _jMul(uint256 x1, uint256 z1, uint256 x2, uint256 z2) public pure returns (uint256 x3, uint256 z3) {
        (x3, z3) = (mulmod(x1, x2, N), mulmod(z1, z2, N));
    }

    function _jDiv(uint256 x1, uint256 z1, uint256 x2, uint256 z2) public pure returns (uint256 x3, uint256 z3) {
        (x3, z3) = (mulmod(x1, z2, N), mulmod(z1, x2, N));
    }

    function _inverse(uint256 val) public pure returns (uint256 invVal) {
        uint256 t = 0;
        uint256 newT = 1;
        uint256 r = N;
        uint256 newR = val;
        uint256 q;
        while (newR != 0) {
            q = r / newR;

            (t, newT) = (newT, addmod(t, (N - mulmod(q, newT, N)), N));
            (r, newR) = (newR, r - q * newR);
        }

        return t;
    }

    function _ecAdd(uint256 x1, uint256 y1, uint256 z1, uint256 x2, uint256 y2, uint256 z2)
        public
        pure
        returns (uint256 x3, uint256 y3, uint256 z3)
    {
        uint256 lx;
        uint256 lz;
        uint256 da;
        uint256 db;

        if (x1 == 0 && y1 == 0) {
            return (x2, y2, z2);
        }

        if (x2 == 0 && y2 == 0) {
            return (x1, y1, z1);
        }

        if (x1 == x2 && y1 == y2) {
            (lx, lz) = _jMul(x1, z1, x1, z1);
            (lx, lz) = _jMul(lx, lz, 3, 1);
            (lx, lz) = _jAdd(lx, lz, A, 1);

            (da, db) = _jMul(y1, z1, 2, 1);
        } else {
            (lx, lz) = _jSub(y2, z2, y1, z1);
            (da, db) = _jSub(x2, z2, x1, z1);
        }

        (lx, lz) = _jDiv(lx, lz, da, db);

        (x3, da) = _jMul(lx, lz, lx, lz);
        (x3, da) = _jSub(x3, da, x1, z1);
        (x3, da) = _jSub(x3, da, x2, z2);

        (y3, db) = _jSub(x1, z1, x3, da);
        (y3, db) = _jMul(y3, db, lx, lz);
        (y3, db) = _jSub(y3, db, y1, z1);

        if (da != db) {
            x3 = mulmod(x3, db, N);
            y3 = mulmod(y3, da, N);
            z3 = mulmod(da, db, N);
        } else {
            z3 = da;
        }
    }

    function _ecDouble(uint256 x1, uint256 y1, uint256 z1) public pure returns (uint256 x3, uint256 y3, uint256 z3) {
        (x3, y3, z3) = _ecAdd(x1, y1, z1, x1, y1, z1);
    }

    function _ecMul(uint256 d, uint256 x1, uint256 y1, uint256 z1)
        public
        pure
        returns (uint256 x3, uint256 y3, uint256 z3)
    {
        uint256 remaining = d;
        uint256 px = x1;
        uint256 py = y1;
        uint256 pz = z1;
        uint256 acx = 0;
        uint256 acy = 0;
        uint256 acz = 1;

        if (d == 0) {
            return (0, 0, 1);
        }

        while (remaining != 0) {
            if ((remaining & 1) != 0) {
                (acx, acy, acz) = _ecAdd(acx, acy, acz, px, py, pz);
            }
            remaining = remaining / 2;
            (px, py, pz) = _ecDouble(px, py, pz);
        }

        (x3, y3, z3) = (acx, acy, acz);
    }

    function ecadd(uint256 x1, uint256 y1, uint256 x2, uint256 y2) public pure returns (uint256 x3, uint256 y3) {
        uint256 z;
        (x3, y3, z) = _ecAdd(x1, y1, 1, x2, y2, 1);
        z = _inverse(z);
        x3 = mulmod(x3, z, N);
        y3 = mulmod(y3, z, N);
    }

    function ecmul(uint256 x1, uint256 y1, uint256 scalar) public pure returns (uint256 x2, uint256 y2) {
        uint256 z;
        (x2, y2, z) = _ecMul(scalar, x1, y1, 1);
        z = _inverse(z);
        x2 = mulmod(x2, z, N);
        y2 = mulmod(y2, z, N);
    }

    function pointHash(uint256[2] memory point) public pure returns (address) {
        return address(
            uint160(
                uint256(keccak256(abi.encodePacked(point[0], point[1]))) & 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            )
        );
    }

    /**
     * hash(g^a + B^c)
     */
    function sbmulAddMul(uint256 s, uint256[2] memory b, uint256 c) public pure returns (address) {
        uint256 q = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
        s = (q - s) % q;
        s = mulmod(s, b[0], q);

        return ecrecover(bytes32(s), b[1] % 2 != 0 ? 28 : 27, bytes32(b[0]), bytes32(mulmod(c, b[0], q)));
    }

    //
    // Based on the original idea of Vitalik Buterin:
    // https://ethresear.ch/t/you-can-kinda-abuse-ecrecover-to-do-ecmul-in-secp256k1-today/2384/9
    //
    function ecmulVerify(uint256 x1, uint256 y1, uint256 scalar, uint256 qx, uint256 qy) public pure returns (bool) {
        address signer = sbmulAddMul(0, [x1, y1], scalar);
        return pointHash([qx, qy]) == signer;
    }

    function publicKey(uint256 privKey) public pure returns (uint256 qx, uint256 qy) {
        return ecmul(GX, GY, privKey);
    }

    function publicKeyVerify(uint256 privKey, uint256 x, uint256 y) public pure returns (bool) {
        return ecmulVerify(GX, GY, privKey, x, y);
    }

    function deriveKey(uint256 privKey, uint256 pubX, uint256 pubY) public pure returns (uint256 qx, uint256 qy) {
        uint256 z;
        (qx, qy, z) = _ecMul(privKey, pubX, pubY, 1);
        z = _inverse(z);
        qx = mulmod(qx, z, N);
        qy = mulmod(qy, z, N);
    }
}
