// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "./helper/RegressionTestHelper.sol";

contract RelayGasMeasurementTest is Test {
    function setUp() public {}

    uint256[] points;

    function test_det() public pure {
        assertEq(
            RegressionTestHelper.det4(
                RegressionTestHelper.Matrix4x4({
                    a11: 1,
                    a12: 0,
                    a13: 0,
                    a14: 0,
                    a21: 0,
                    a22: 1,
                    a23: 0,
                    a24: 0,
                    a31: 0,
                    a32: 0,
                    a33: 1,
                    a34: 0,
                    a41: 0,
                    a42: 0,
                    a43: 0,
                    a44: 1
                })
            ),
            int256(1)
        );
        assertEq(
            RegressionTestHelper.det4(
                RegressionTestHelper.Matrix4x4({
                    a11: 1,
                    a12: 1,
                    a13: 1,
                    a14: 1,
                    a21: 1,
                    a22: 1,
                    a23: 1,
                    a24: 1,
                    a31: 1,
                    a32: 1,
                    a33: 1,
                    a34: 1,
                    a41: 1,
                    a42: 1,
                    a43: 1,
                    a44: 1
                })
            ),
            int256(0)
        );
        assertEq(
            RegressionTestHelper.det4(
                RegressionTestHelper.Matrix4x4({
                    a11: 232,
                    a12: -23,
                    a13: -7775,
                    a14: 911,
                    a21: 923,
                    a22: 3032,
                    a23: 0,
                    a24: -1,
                    a31: 1,
                    a32: 3492,
                    a33: -4728,
                    a34: -1653,
                    a41: 5891,
                    a42: -8052,
                    a43: -9570,
                    a44: 100
                })
            ),
            int256(447638294209192)
        );
    }

    function testCoeffCalculation() public {
        RegressionTestHelper.Linear memory fx;
        RegressionTestHelper.Quadratic memory gx;
        RegressionTestHelper.Cubic memory hx;

        // case1 ---------------------------------------------------------------------------

        points.push((0 << 128) + 98787);
        points.push((1 << 128) + 99893);
        points.push((2 << 128) + 100975);
        points.push((3 << 128) + 102033);
        points.push((4 << 128) + 103139);
        points.push((5 << 128) + 104221);
        points.push((6 << 128) + 105303);
        points.push((7 << 128) + 106386);
        points.push((8 << 128) + 107444);
        points.push((9 << 128) + 108551);
        points.push((10 << 128) + 109633);
        points.push((11 << 128) + 110716);
        points.push((12 << 128) + 111799);
        points.push((13 << 128) + 112882);
        points.push((14 << 128) + 113953);
        points.push((15 << 128) + 115048);
        points.push((16 << 128) + 116119);
        points.push((17 << 128) + 117215);
        points.push((18 << 128) + 118286);
        points.push((19 << 128) + 119382);
        points.push((20 << 128) + 120441);
        points.push((21 << 128) + 121537);
        points.push((22 << 128) + 122621);
        points.push((23 << 128) + 123705);
        points.push((24 << 128) + 124789);
        points.push((25 << 128) + 125873);
        points.push((26 << 128) + 126933);
        points.push((27 << 128) + 128041);
        points.push((28 << 128) + 129102);
        points.push((29 << 128) + 130222);
        points.push((30 << 128) + 131295);
        points.push((31 << 128) + 132380);
        points.push((32 << 128) + 133452);
        points.push((33 << 128) + 134525);
        points.push((34 << 128) + 135634);
        points.push((35 << 128) + 136719);
        points.push((36 << 128) + 137780);
        points.push((37 << 128) + 138878);
        points.push((38 << 128) + 139963);
        points.push((39 << 128) + 141061);
        points.push((40 << 128) + 142158);
        points.push((41 << 128) + 143244);
        points.push((42 << 128) + 144294);
        points.push((43 << 128) + 145416);
        points.push((44 << 128) + 146490);
        points.push((45 << 128) + 147564);
        points.push((46 << 128) + 148638);
        points.push((47 << 128) + 149748);
        points.push((48 << 128) + 150822);
        points.push((49 << 128) + 151909);

        // Results from np.polyfit
        //
        // --- Optimal Linear ---
        // a (slope): 1083.747370948379
        // b (y-intercept): 98788.16941176468
        // ------------------------------

        // --- Optimal Quadratic ---
        // a (x^2 term): 0.04896227721860076
        // b (x term):   1081.348219364669
        // c (constant): 98807.36262443438
        // ------------------------------

        // --- Optimal Cubic ---
        // a (x^3 term): 0.000940915846927263
        // b (x^2 term): -0.020195037530464532
        // c (x term):   1082.6900594539666
        // d (constant): 98802.16199436528
        // ------------------------------

        fx = RegressionTestHelper.linear(points);
        assertEq(fx.c1, 1083747370948379351740);
        assertEq(fx.c0, 98788169411764705882352);

        gx = RegressionTestHelper.quadratic(points);
        assertEq(gx.c2, 48962277218579739);
        assertEq(gx.c1, 1081348219364668944500);
        assertEq(gx.c0, 98807362624434389140271);

        hx = RegressionTestHelper.cubic(points);
        assertEq(hx.c3, 940915846930440);
        assertEq(hx.c2, -20195037530807647);
        assertEq(hx.c1, 1082690059453976445903);
        assertEq(hx.c0, 98802161994365235208742);

        // case2 ---------------------------------------------------------------------------

        points[0] = (0 << 128) + 38079;
        points[1] = (1 << 128) + 38977;
        points[2] = (2 << 128) + 39881;
        points[3] = (3 << 128) + 40789;
        points[4] = (4 << 128) + 41705;
        points[5] = (5 << 128) + 42630;
        points[6] = (6 << 128) + 43565;
        points[7] = (7 << 128) + 44444;
        points[8] = (8 << 128) + 45473;
        points[9] = (9 << 128) + 46448;
        points[10] = (10 << 128) + 47440;
        points[11] = (11 << 128) + 48451;
        points[12] = (12 << 128) + 49482;
        points[13] = (13 << 128) + 50535;
        points[14] = (14 << 128) + 51526;
        points[15] = (15 << 128) + 52625;
        points[16] = (16 << 128) + 53849;
        points[17] = (17 << 128) + 55013;
        points[18] = (18 << 128) + 56208;
        points[19] = (19 << 128) + 57439;
        points[20] = (20 << 128) + 58708;
        points[21] = (21 << 128) + 60016;
        points[22] = (22 << 128) + 61368;
        points[23] = (23 << 128) + 62763;
        points[24] = (24 << 128) + 64206;
        points[25] = (25 << 128) + 65700;
        points[26] = (26 << 128) + 67245;
        points[27] = (27 << 128) + 68847;
        points[28] = (28 << 128) + 70508;
        points[29] = (29 << 128) + 72229;
        points[30] = (30 << 128) + 73826;
        points[31] = (31 << 128) + 75671;
        points[32] = (32 << 128) + 77794;
        points[33] = (33 << 128) + 79792;
        points[34] = (34 << 128) + 81868;
        points[35] = (35 << 128) + 84022;
        points[36] = (36 << 128) + 86261;
        points[37] = (37 << 128) + 88588;
        points[38] = (38 << 128) + 91004;
        points[39] = (39 << 128) + 93515;
        points[40] = (40 << 128) + 96123;
        points[41] = (41 << 128) + 98832;
        points[42] = (42 << 128) + 101647;
        points[43] = (43 << 128) + 104571;
        points[44] = (44 << 128) + 107608;
        points[45] = (45 << 128) + 110760;
        points[46] = (46 << 128) + 113633;
        points[47] = (47 << 128) + 117014;
        points[48] = (48 << 128) + 120956;
        points[49] = (49 << 128) + 124617;

        // Results from np.polyfit
        //
        // --- Optimal Linear ---
        // a (slope): 1661.8547418967582
        // b (y-intercept): 29769.57882352938
        // ------------------------------

        // --- Optimal Quadratic ---
        // a (x^2 term): 27.07018653615293
        // b (x term):   335.41560162526537
        // c (constant): 40381.09194570137
        // ------------------------------

        // --- Optimal Cubic ---
        // a (x^3 term): 0.4482223701944078
        // b (x^2 term): -5.874157673136074
        // c (x term):   974.6255237595111
        // d (constant): 37903.67726116282
        // ------------------------------

        fx = RegressionTestHelper.linear(points);
        assertEq(fx.c1, 1661854741896758703481);
        assertEq(fx.c0, 29769578823529411764705);

        gx = RegressionTestHelper.quadratic(points);
        assertEq(gx.c2, 27070186536152922707);
        assertEq(gx.c1, 335415601625265490811);
        assertEq(gx.c0, 40381091945701357466063);

        hx = RegressionTestHelper.cubic(points);
        assertEq(hx.c3, 448222370194410716);
        assertEq(hx.c2, -5874157673136264974);
        assertEq(hx.c1, 974625523759514613985);
        assertEq(hx.c0, 37903677261162810552377);
    }
}
