// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./helper/MockTarget.sol";
import "./helper/TestableErrorHandler.sol";
import "../src/interfaces/IErrorHandler.sol";

contract ErrorHandlerTest is Test {
    TestableErrorHandler impl;
    address target;

    address owner;
    address stranger;
    uint256 constant _CALLBACK_GAS_LIMIT = 1_000_000;

    function setUp() public {
        owner = address(this);
        stranger = makeAddr("stranger");

        impl = new TestableErrorHandler();
        impl.initialize(owner);
        target = address(new MockTarget());
    }

    /* ========== Initial State and Basics ========== */

    function testBasics() public {
        assertEq(impl.stringToFsig("Err1()"), MockTarget.Err1.selector);
        assertEq(impl.stringToFsig("Err2()"), MockTarget.Err2.selector);
        assertEq(
            impl.stringToFsig("ErrWithParams(uint256,string)"),
            MockTarget.ErrWithParams.selector
        );

        bytes4 sel;

        // before
        sel = impl.stringToFsig("Err1()");
        vm.expectRevert(
            abi.encodeWithSelector(
                IErrorHandler.ErrorNotRegistered.selector,
                target,
                sel,
                ""
            )
        );
        impl.getRegisteredError(target, sel);

        sel = impl.stringToFsig("Err2()");
        vm.expectRevert(
            abi.encodeWithSelector(
                IErrorHandler.ErrorNotRegistered.selector,
                target,
                sel,
                ""
            )
        );
        impl.getRegisteredError(target, sel);

        sel = impl.stringToFsig("ErrWithParams(uint256,string)");
        vm.expectRevert(
            abi.encodeWithSelector(
                IErrorHandler.ErrorNotRegistered.selector,
                target,
                sel,
                ""
            )
        );
        impl.getRegisteredError(target, sel);

        // register
        impl.registerError(target, "Err1()");
        impl.registerError(target, "Err2()");
        impl.registerError(target, "ErrWithParams(uint256,string)");

        // after
        assertEq(
            impl.getRegisteredError(target, impl.stringToFsig("Err1()")),
            "Err1()"
        );
        assertEq(
            impl.getRegisteredError(target, impl.stringToFsig("Err2()")),
            "Err2()"
        );
        assertEq(
            impl.getRegisteredError(
                target,
                impl.stringToFsig("ErrWithParams(uint256,string)")
            ),
            "ErrWithParams(uint256,string)"
        );
    }

    /* ========== Access Control Tests ========== */

    function test_Revert_When_NotOwner() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                stranger
            )
        );
        impl.registerError(target, "Some random error");

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                stranger
            )
        );
        impl.unregisterError(target, "Some random error");
    }

    /* ========== Registration and Unregistration Logic ========== */

    function test_RegisterAndUnregister_Flow() public {
        assertFalse(impl.isErrorRegistered(target, "Err1()"));
        assertFalse(impl.isErrorRegistered(target, "Err2()"));
        assertFalse(
            impl.isErrorRegistered(target, "ErrWithParams(uint256,string)")
        );

        // Register Err1()
        impl.registerError(target, "Err1()");
        assertTrue(impl.isErrorRegistered(target, "Err1()"));
        assertTrue(impl.isErrorRegistered(target, "Err1()"));
        assertFalse(impl.isErrorRegistered(target, "Err2()"));
        assertFalse(
            impl.isErrorRegistered(target, "ErrWithParams(uint256,string)")
        );

        // Register Err2()
        impl.registerError(target, "Err2()");
        assertTrue(impl.isErrorRegistered(target, "Err2()"));
        assertTrue(impl.isErrorRegistered(target, "Err1()"));
        assertTrue(impl.isErrorRegistered(target, "Err2()"));
        assertFalse(
            impl.isErrorRegistered(target, "ErrWithParams(uint256,string)")
        );

        // Register ErrWithParams(uint256,string)
        impl.registerError(target, "ErrWithParams(uint256,string)");
        assertTrue(
            impl.isErrorRegistered(target, "ErrWithParams(uint256,string)")
        );
        assertTrue(impl.isErrorRegistered(target, "Err1()"));
        assertTrue(impl.isErrorRegistered(target, "Err2()"));
        assertTrue(
            impl.isErrorRegistered(target, "ErrWithParams(uint256,string)")
        );

        // Unregister Err1()
        vm.expectEmit();
        emit IErrorHandler.ErrorUnregistered(
            target,
            MockTarget.Err1.selector,
            "Err1()"
        );
        impl.unregisterError(target, "Err1()");
        assertFalse(impl.isErrorRegistered(target, "Err1()"));
        assertFalse(impl.isErrorRegistered(target, "Err1()"));
        assertTrue(impl.isErrorRegistered(target, "Err2()"));
        assertTrue(
            impl.isErrorRegistered(target, "ErrWithParams(uint256,string)")
        );

        // Unregister Err2()
        impl.unregisterError(target, "Err2()");
        assertFalse(impl.isErrorRegistered(target, "Err2()"));
        assertFalse(impl.isErrorRegistered(target, "Err1()"));
        assertFalse(impl.isErrorRegistered(target, "Err2()"));
        assertTrue(
            impl.isErrorRegistered(target, "ErrWithParams(uint256,string)")
        );

        // Unregister ErrWithParams(uint256,string)
        impl.unregisterError(target, "ErrWithParams(uint256,string)");
        assertFalse(
            impl.isErrorRegistered(target, "ErrWithParams(uint256,string)")
        );
        assertFalse(impl.isErrorRegistered(target, "Err1()"));
        assertFalse(impl.isErrorRegistered(target, "Err2()"));
        assertFalse(
            impl.isErrorRegistered(target, "ErrWithParams(uint256,string)")
        );
    }

    function test_Revert_RegisterError_WhenAlreadyRegistered() public {
        impl.registerError(target, "Err1()");
        vm.expectRevert(
            abi.encodeWithSelector(
                IErrorHandler.ErrorAlreadyRegistered.selector,
                target,
                MockTarget.Err1.selector,
                "Err1()"
            )
        );
        impl.registerError(target, "Err1()");
    }

    function test_Revert_UnregisterError_WhenNotRegistered() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IErrorHandler.ErrorNotRegistered.selector,
                target,
                MockTarget.Err1.selector,
                "Err1()"
            )
        );
        impl.unregisterError(target, "Err1()");
    }

    /* ========== Handling Logic ========== */

    function test_CallHandling_Success() public {
        bytes memory callData = abi.encodeWithSelector(
            MockTarget.succeed.selector
        );
        vm.expectEmit();
        emit IErrorHandler.DeliverySuccess(target);
        (bool ok, bytes memory data) = impl.call(
            target,
            _CALLBACK_GAS_LIMIT,
            callData
        );
        assertTrue(ok);
        (uint256 val, string memory message) = abi.decode(
            data,
            (uint256, string)
        );
        assertEq(val, 999);
        assertEq(message, "success");
    }

    function test_Handle_CustomError_NoParams() public {
        bytes memory callData = abi.encodeWithSelector(
            MockTarget.failWithErr1.selector
        );
        bytes memory expectedRevertData = abi.encodeWithSelector(
            MockTarget.Err1.selector
        );

        // --- Unregistered ---
        vm.expectEmit();
        emit IErrorHandler.DeliveryError(target, expectedRevertData);
        (bool ok, bytes memory data) = impl.call(
            target,
            _CALLBACK_GAS_LIMIT,
            callData
        );
        assertFalse(ok);
        assertEq(data, expectedRevertData);

        // --- Registered ---
        impl.registerError(target, "Err1()");
        vm.expectRevert(impl.stringToFsig("Err1()"));
        impl.call(target, _CALLBACK_GAS_LIMIT, callData);
    }

    function test_Handle_CustomError_WithParams() public {
        bytes memory callData = abi.encodeWithSelector(
            MockTarget.failWithParams.selector,
            404,
            "Not Found"
        );
        bytes memory expectedRevertData = abi.encodeWithSelector(
            impl.stringToFsig("ErrWithParams(uint256,string)"),
            404,
            "Not Found"
        );

        // --- Unregistered ---
        vm.expectEmit();
        emit IErrorHandler.DeliveryError(target, expectedRevertData);
        (bool ok, bytes memory data) = impl.call(
            target,
            _CALLBACK_GAS_LIMIT,
            callData
        );
        assertFalse(ok);
        assertEq(data, expectedRevertData);

        // --- Registered ---
        impl.registerError(target, "ErrWithParams(uint256,string)");
        vm.expectRevert(expectedRevertData);
        impl.call(target, _CALLBACK_GAS_LIMIT, callData);
    }

    function test_Handle_StringRequire() public {
        bytes memory callData = abi.encodeWithSelector(
            MockTarget.failWithRequireReason.selector
        );
        bytes memory expectedRevertData = abi.encodeWithSignature(
            "Error(string)",
            "Reverted via require"
        );

        // --- Unregistered ---
        vm.expectEmit();
        emit IErrorHandler.DeliveryError(target, expectedRevertData);
        (bool ok, bytes memory data) = impl.call(
            target,
            _CALLBACK_GAS_LIMIT,
            callData
        );
        assertFalse(ok);
        assertEq(data, expectedRevertData);

        // --- Registered ---
        impl.registerError(target, "Error(string)");
        vm.expectRevert(expectedRevertData);
        impl.call(target, _CALLBACK_GAS_LIMIT, callData);
    }

    function test_Handle_StringRevert() public {
        bytes memory callData = abi.encodeWithSelector(
            MockTarget.failWithRevertReason.selector
        );
        bytes memory expectedRevertData = abi.encodeWithSignature(
            "Error(string)",
            "Reverted via revert"
        );

        // --- Unregistered ---
        vm.expectEmit();
        emit IErrorHandler.DeliveryError(target, expectedRevertData);
        (bool ok, bytes memory data) = impl.call(
            target,
            _CALLBACK_GAS_LIMIT,
            callData
        );
        assertFalse(ok);
        assertEq(data, expectedRevertData);

        // --- Registered ---
        impl.registerError(target, "Error(string)");
        vm.expectRevert(expectedRevertData);
        impl.call(target, _CALLBACK_GAS_LIMIT, callData);
    }

    function test_Handle_LowLevelRevert() public {
        bytes4 randomSelector = impl.stringToFsig("some random thing");
        bytes memory customRevertData = abi.encodeWithSelector(randomSelector);
        bytes memory callData = abi.encodeWithSelector(
            MockTarget.failWithLowLevelRevert.selector,
            customRevertData
        );

        // --- Unregistered ---
        vm.expectEmit();
        emit IErrorHandler.DeliveryError(target, customRevertData);
        (bool ok, bytes memory data) = impl.call(
            target,
            _CALLBACK_GAS_LIMIT,
            callData
        );
        assertFalse(ok);
        assertEq(data, customRevertData);

        // --- Registered ---
        impl.registerError(target, "some random thing");
        vm.expectRevert(customRevertData);
        impl.call(target, _CALLBACK_GAS_LIMIT, callData);
    }

    function test_Handle_Panic_Assert() public {
        bytes memory callData = abi.encodeWithSelector(
            MockTarget.failWithAssert.selector
        );
        // Assert (Panic 0x01)
        bytes memory expectedPanicData = abi.encodeWithSignature(
            "Panic(uint256)",
            0x01
        );

        // --- Unregistered ---
        vm.expectEmit();
        emit IErrorHandler.DeliveryError(target, expectedPanicData);
        (bool ok, bytes memory data) = impl.call(
            target,
            _CALLBACK_GAS_LIMIT,
            callData
        );
        assertFalse(ok);
        assertEq(data, expectedPanicData);

        // --- Registered ---
        impl.registerError(target, "Panic(uint256)");
        vm.expectRevert(expectedPanicData);
        impl.call(target, _CALLBACK_GAS_LIMIT, callData);
    }

    function test_Handle_Panic_Arithmetic() public {
        bytes memory callData = abi.encodeWithSelector(
            MockTarget.failWithArithmetic.selector
        );
        // Arithmetic (Panic 0x11)
        bytes memory expectedPanicData = abi.encodeWithSignature(
            "Panic(uint256)",
            0x11
        );

        // --- Unregistered ---
        vm.expectEmit();
        emit IErrorHandler.DeliveryError(target, expectedPanicData);
        (bool ok, bytes memory data) = impl.call(
            target,
            _CALLBACK_GAS_LIMIT,
            callData
        );
        assertFalse(ok);
        assertEq(data, expectedPanicData);

        // --- Registered ---
        impl.registerError(target, "Panic(uint256)");
        vm.expectRevert(expectedPanicData);
        impl.call(target, _CALLBACK_GAS_LIMIT, callData);
    }

    function test_Handle_Panic_DivisionByZero() public {
        bytes memory callData = abi.encodeWithSelector(
            MockTarget.failWithDivisionByZero.selector,
            123
        );
        // Division by zero (Panic 0x12)
        bytes memory expectedPanicData = abi.encodeWithSignature(
            "Panic(uint256)",
            0x12
        );

        // --- Unregistered ---
        vm.expectEmit();
        emit IErrorHandler.DeliveryError(target, expectedPanicData);
        (bool ok, bytes memory data) = impl.call(
            target,
            _CALLBACK_GAS_LIMIT,
            callData
        );
        assertFalse(ok);
        assertEq(data, expectedPanicData);

        // --- Registered ---
        impl.registerError(target, "Panic(uint256)");
        vm.expectRevert(expectedPanicData);
        impl.call(target, _CALLBACK_GAS_LIMIT, callData);
    }

    function test_Handle_Panic_IndexOutOfBounds() public {
        bytes memory callData = abi.encodeWithSelector(
            MockTarget.failWithIndexOutOfBounds.selector
        );
        // Index out of bounds (Panic 0x32)
        bytes memory expectedPanicData = abi.encodeWithSignature(
            "Panic(uint256)",
            0x32
        );

        // --- Unregistered ---
        vm.expectEmit();
        emit IErrorHandler.DeliveryError(target, expectedPanicData);
        (bool ok, bytes memory data) = impl.call(
            target,
            _CALLBACK_GAS_LIMIT,
            callData
        );
        assertFalse(ok);
        assertEq(data, expectedPanicData);

        // --- Registered ---
        impl.registerError(target, "Panic(uint256)");
        vm.expectRevert(expectedPanicData);
        impl.call(target, _CALLBACK_GAS_LIMIT, callData);
    }

    // Note: Empty reverts (revert data length < 4) cannot be registered to re-throw
    // because they lack a selector. The ErrorHandler will always log them as DeliveryError.
    function test_Handle_EmptyReverts_AlwaysLogs() public {
        // Test require without reason
        bytes memory callData = abi.encodeWithSelector(
            MockTarget.failWithRequireNoReason.selector
        );
        vm.expectEmit();
        emit IErrorHandler.DeliveryError(target, "");
        (bool ok, bytes memory data) = impl.call(
            target,
            _CALLBACK_GAS_LIMIT,
            callData
        );
        assertFalse(ok);
        assertEq(data, hex"");

        // Test empty revert()
        callData = abi.encodeWithSelector(
            MockTarget.failWithEmptyRevert.selector
        );
        vm.expectEmit();
        emit IErrorHandler.DeliveryError(target, "");
        (ok, data) = impl.call(target, _CALLBACK_GAS_LIMIT, callData);
        assertFalse(ok);
        assertEq(data, hex"");

        // Test failed transfer
        callData = abi.encodeWithSelector(MockTarget.failWithTransfer.selector);
        vm.expectEmit();
        emit IErrorHandler.DeliveryError(target, "");
        (ok, data) = impl.call(target, _CALLBACK_GAS_LIMIT, callData);
        assertFalse(ok);
        assertEq(data, hex"");

        // Test failed failWithCallUnknown
        callData = abi.encodeWithSelector(
            MockTarget.failWithCallUnknown.selector
        );
        vm.expectEmit();
        emit IErrorHandler.DeliveryError(target, "");
        (ok, data) = impl.call(target, _CALLBACK_GAS_LIMIT, callData);
        assertFalse(ok);
        assertEq(data, hex"");

        // Test failed because not enough callbackGasLimit
        callData = abi.encodeWithSelector(MockTarget.succeed.selector);
        vm.expectEmit();
        emit IErrorHandler.DeliveryError(target, "");
        (ok, data) = impl.call(
            target,
            // set callbackGasLimit = 10
            10,
            callData
        );
        assertFalse(ok);
        assertEq(data, hex"");
    }
}
