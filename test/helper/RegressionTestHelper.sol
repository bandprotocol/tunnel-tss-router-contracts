// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

/**
 * @title RegressionTestHelper Library
 * @notice A library for on-chain polynomial regression (least squares fitting).
 * @dev Implements mathematically correct fitting for linear, quadratic, and cubic
 * models using Cramer's rule.
 */
library RegressionTestHelper {
    /// @dev The fixed-point precision factor (1e18).
    int256 private constant FP = 1e18;

    // --- Model Structs ---
    struct Linear {
        int256 c1;
        int256 c0;
    }

    struct Quadratic {
        int256 c2;
        int256 c1;
        int256 c0;
    }

    struct Cubic {
        int256 c3;
        int256 c2;
        int256 c1;
        int256 c0;
    }

    // --- Matrix Structs ---
    struct Matrix2x2 {
        int256 a11;
        int256 a12;
        int256 a21;
        int256 a22;
    }
    struct Matrix3x3 {
        int256 a11;
        int256 a12;
        int256 a13;
        int256 a21;
        int256 a22;
        int256 a23;
        int256 a31;
        int256 a32;
        int256 a33;
    }
    struct Matrix4x4 {
        int256 a11;
        int256 a12;
        int256 a13;
        int256 a14;
        int256 a21;
        int256 a22;
        int256 a23;
        int256 a24;
        int256 a31;
        int256 a32;
        int256 a33;
        int256 a34;
        int256 a41;
        int256 a42;
        int256 a43;
        int256 a44;
    }

    // Structs to hold summation values, preventing "Stack too deep" errors.
    struct Sums1 {
        int256 S0;
        int256 S1;
        int256 S2;
        int256 T0;
        int256 T1;
    }
    struct Sums2 {
        int256 S0;
        int256 S1;
        int256 S2;
        int256 S3;
        int256 S4;
        int256 T0;
        int256 T1;
        int256 T2;
    }
    struct Sums3 {
        int256 S0;
        int256 S1;
        int256 S2;
        int256 S3;
        int256 S4;
        int256 S5;
        int256 S6;
        int256 T0;
        int256 T1;
        int256 T2;
        int256 T3;
    }

    // --- Determinant Functions ---

    /// @dev Calculates the determinant of a 2x2 matrix.
    function det2(Matrix2x2 memory m) internal pure returns (int256) {
        return m.a11 * m.a22 - m.a12 * m.a21;
    }

    /// @dev Calculates the determinant of a 3x3 matrix.
    function det3(Matrix3x3 memory m) internal pure returns (int256) {
        Matrix2x2 memory minor11 = Matrix2x2({
            a11: m.a22,
            a12: m.a23,
            a21: m.a32,
            a22: m.a33
        });
        Matrix2x2 memory minor12 = Matrix2x2({
            a11: m.a21,
            a12: m.a23,
            a21: m.a31,
            a22: m.a33
        });
        Matrix2x2 memory minor13 = Matrix2x2({
            a11: m.a21,
            a12: m.a22,
            a21: m.a31,
            a22: m.a32
        });

        return
            m.a11 *
            det2(minor11) -
            m.a12 *
            det2(minor12) +
            m.a13 *
            det2(minor13);
    }

    /// @dev Calculates the determinant of a 4x4 matrix.
    function det4(Matrix4x4 memory m) internal pure returns (int256) {
        Matrix3x3 memory minor11 = Matrix3x3({
            a11: m.a22,
            a12: m.a23,
            a13: m.a24,
            a21: m.a32,
            a22: m.a33,
            a23: m.a34,
            a31: m.a42,
            a32: m.a43,
            a33: m.a44
        });
        Matrix3x3 memory minor12 = Matrix3x3({
            a11: m.a21,
            a12: m.a23,
            a13: m.a24,
            a21: m.a31,
            a22: m.a33,
            a23: m.a34,
            a31: m.a41,
            a32: m.a43,
            a33: m.a44
        });
        Matrix3x3 memory minor13 = Matrix3x3({
            a11: m.a21,
            a12: m.a22,
            a13: m.a24,
            a21: m.a31,
            a22: m.a32,
            a23: m.a34,
            a31: m.a41,
            a32: m.a42,
            a33: m.a44
        });
        Matrix3x3 memory minor14 = Matrix3x3({
            a11: m.a21,
            a12: m.a22,
            a13: m.a23,
            a21: m.a31,
            a22: m.a32,
            a23: m.a33,
            a31: m.a41,
            a32: m.a42,
            a33: m.a43
        });

        return
            m.a11 *
            det3(minor11) -
            m.a12 *
            det3(minor12) +
            m.a13 *
            det3(minor13) -
            m.a14 *
            det3(minor14);
    }

    // --- Fitting Functions ---

    /**
     * @notice Fits a linear model y = c1*x + c0 to the provided data.
     * @param listOfXY An array of independent variable values.
     * @return fx A linear function
     */
    function linear(
        uint256[] storage listOfXY
    ) internal view returns (Linear memory fx) {
        uint256 n = listOfXY.length;
        require(n > 1, "PolyFit: linear fit requires at least 2 points");

        Sums1 memory s;
        s.S0 = int256(n);

        for (uint256 i; i < n; i++) {
            int256 x = int256(listOfXY[i] >> 128);
            int256 y = int256(listOfXY[i] & ((1 << 128) - 1));

            s.S1 += x;
            s.S2 += x * x;
            s.T0 += y;
            s.T1 += x * y;
        }

        int256 detCoef = det2(
            Matrix2x2({a11: s.S0, a12: s.S1, a21: s.S1, a22: s.S2})
        );
        require(detCoef != 0, "PolyFit: singular matrix");

        fx.c1 =
            (det2(Matrix2x2({a11: s.S0, a12: s.T0, a21: s.S1, a22: s.T1})) *
                FP) /
            detCoef;
        fx.c0 =
            (det2(Matrix2x2({a11: s.T0, a12: s.S1, a21: s.T1, a22: s.S2})) *
                FP) /
            detCoef;
    }

    /**
     * @notice Fits a quadratic model y = c2*x^2 + c1*x + c0 to the provided data.
     * @dev WARNING: Subject to overflow for large x/y values. Use with caution.
     * @param listOfXY An array of independent variable values.
     * @return fx A quadratic function
     */
    function quadratic(
        uint256[] storage listOfXY
    ) internal view returns (Quadratic memory fx) {
        uint256 n = listOfXY.length;
        require(n > 2, "PolyFit: quadratic fit requires at least 3 points");

        Sums2 memory s;
        s.S0 = int256(n);

        for (uint256 i; i < n; i++) {
            int256 x = int256(listOfXY[i] >> 128);
            int256 y = int256(listOfXY[i] & ((1 << 128) - 1));

            int256 x2 = x * x;
            int256 x3 = x2 * x;
            int256 x4 = x3 * x;
            s.S1 += x;
            s.S2 += x2;
            s.S3 += x3;
            s.S4 += x4;
            s.T0 += y;
            s.T1 += x * y;
            s.T2 += x2 * y;
        }

        int256 detCoef = det3(
            Matrix3x3({
                a11: s.S0,
                a12: s.S1,
                a13: s.S2,
                a21: s.S1,
                a22: s.S2,
                a23: s.S3,
                a31: s.S2,
                a32: s.S3,
                a33: s.S4
            })
        );
        require(detCoef != 0, "PolyFit: singular matrix");

        fx.c2 =
            (det3(
                Matrix3x3({
                    a11: s.S0,
                    a12: s.S1,
                    a13: s.T0,
                    a21: s.S1,
                    a22: s.S2,
                    a23: s.T1,
                    a31: s.S2,
                    a32: s.S3,
                    a33: s.T2
                })
            ) * FP) /
            detCoef;
        fx.c1 =
            (det3(
                Matrix3x3({
                    a11: s.S0,
                    a12: s.T0,
                    a13: s.S2,
                    a21: s.S1,
                    a22: s.T1,
                    a23: s.S3,
                    a31: s.S2,
                    a32: s.T2,
                    a33: s.S4
                })
            ) * FP) /
            detCoef;
        fx.c0 =
            (det3(
                Matrix3x3({
                    a11: s.T0,
                    a12: s.S1,
                    a13: s.S2,
                    a21: s.T1,
                    a22: s.S2,
                    a23: s.S3,
                    a31: s.T2,
                    a32: s.S3,
                    a33: s.S4
                })
            ) * FP) /
            detCoef;
    }

    /**
     * @notice Fits a cubic model y = c3*x^3 + c2*x^2 + c1*x + c0 to the data.
     * @dev DANGER: High risk of overflow and high gas usage. Only for small `n` and small `x` values.
     * @param listOfXY An array of independent variable values.
     * @return fx A cubic function
     */
    function cubic(
        uint256[] storage listOfXY
    ) internal view returns (Cubic memory fx) {
        uint256 n = listOfXY.length;
        require(n > 3, "PolyFit: cubic fit requires at least 4 points");

        Sums3 memory s;
        s.S0 = int256(n);

        for (uint256 i; i < n; i++) {
            int256 x = int256(listOfXY[i] >> 128);
            int256 y = int256(listOfXY[i] & ((1 << 128) - 1));

            int256 x2 = x * x;
            int256 x3 = x2 * x;
            int256 x4 = x3 * x;
            int256 x5 = x4 * x;
            int256 x6 = x5 * x;

            s.S1 += x;
            s.S2 += x2;
            s.S3 += x3;
            s.S4 += x4;
            s.S5 += x5;
            s.S6 += x6;
            s.T0 += y;
            s.T1 += x * y;
            s.T2 += x2 * y;
            s.T3 += x3 * y;
        }

        int256 detCoef = det4(
            Matrix4x4({
                a11: s.S0,
                a12: s.S1,
                a13: s.S2,
                a14: s.S3,
                a21: s.S1,
                a22: s.S2,
                a23: s.S3,
                a24: s.S4,
                a31: s.S2,
                a32: s.S3,
                a33: s.S4,
                a34: s.S5,
                a41: s.S3,
                a42: s.S4,
                a43: s.S5,
                a44: s.S6
            })
        );
        require(detCoef != 0, "PolyFit: singular matrix");

        fx.c3 =
            (det4(
                Matrix4x4({
                    a11: s.S0,
                    a12: s.S1,
                    a13: s.S2,
                    a14: s.T0,
                    a21: s.S1,
                    a22: s.S2,
                    a23: s.S3,
                    a24: s.T1,
                    a31: s.S2,
                    a32: s.S3,
                    a33: s.S4,
                    a34: s.T2,
                    a41: s.S3,
                    a42: s.S4,
                    a43: s.S5,
                    a44: s.T3
                })
            ) * FP) /
            detCoef;
        fx.c2 =
            (det4(
                Matrix4x4({
                    a11: s.S0,
                    a12: s.S1,
                    a13: s.T0,
                    a14: s.S3,
                    a21: s.S1,
                    a22: s.S2,
                    a23: s.T1,
                    a24: s.S4,
                    a31: s.S2,
                    a32: s.S3,
                    a33: s.T2,
                    a34: s.S5,
                    a41: s.S3,
                    a42: s.S4,
                    a43: s.T3,
                    a44: s.S6
                })
            ) * FP) /
            detCoef;
        fx.c1 =
            (det4(
                Matrix4x4({
                    a11: s.S0,
                    a12: s.T0,
                    a13: s.S2,
                    a14: s.S3,
                    a21: s.S1,
                    a22: s.T1,
                    a23: s.S3,
                    a24: s.S4,
                    a31: s.S2,
                    a32: s.T2,
                    a33: s.S4,
                    a34: s.S5,
                    a41: s.S3,
                    a42: s.T3,
                    a43: s.S5,
                    a44: s.S6
                })
            ) * FP) /
            detCoef;
        fx.c0 =
            (det4(
                Matrix4x4({
                    a11: s.T0,
                    a12: s.S1,
                    a13: s.S2,
                    a14: s.S3,
                    a21: s.T1,
                    a22: s.S2,
                    a23: s.S3,
                    a24: s.S4,
                    a31: s.T2,
                    a32: s.S3,
                    a33: s.S4,
                    a34: s.S5,
                    a41: s.T3,
                    a42: s.S4,
                    a43: s.S5,
                    a44: s.S6
                })
            ) * FP) /
            detCoef;
    }

    function evaluateLinear(
        Linear memory f,
        int256[] memory listOfX
    ) internal pure returns (int256[] memory listOfY) {
        listOfY = new int256[](listOfX.length);
        for (uint256 i = 0; i < listOfY.length; i++) {
            int256 x = listOfX[i];
            listOfY[i] = (f.c1 * x + f.c0) / FP;
        }
    }

    function evaluateQuadratic(
        Quadratic memory f,
        int256[] memory listOfX
    ) internal pure returns (int256[] memory listOfY) {
        listOfY = new int256[](listOfX.length);
        for (uint256 i = 0; i < listOfY.length; i++) {
            int256 x = listOfX[i];
            listOfY[i] = (f.c2 * x * x + f.c1 * x + f.c0) / FP;
        }
    }

    function evaluateCubic(
        Cubic memory f,
        int256[] memory listOfX
    ) internal pure returns (int256[] memory listOfY) {
        listOfY = new int256[](listOfX.length);
        for (uint256 i = 0; i < listOfY.length; i++) {
            int256 x = listOfX[i];
            listOfY[i] =
                (f.c3 * x * x * x + f.c2 * x * x + f.c1 * x + f.c0) /
                FP;
        }
    }
}
