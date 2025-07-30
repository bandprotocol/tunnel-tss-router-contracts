// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface UnknownContract {
    function unknownFunction() external;
}

contract MockTarget {
    error Err1();
    error Err2();
    error ErrWithParams(uint256 errCode, string errMessage);

    function succeed()
        external
        pure
        returns (uint256 val, string memory message)
    {
        val = 999;
        message = "success";
    }

    function failWithErr1() external pure {
        revert Err1();
    }

    function failWithErr2() external pure {
        revert Err2();
    }

    function failWithParams(
        uint256 errCode,
        string memory errMessage
    ) external pure {
        revert ErrWithParams(errCode, errMessage);
    }

    function failWithRequireReason() external pure {
        require(false, "Reverted via require");
    }

    function failWithRevertReason() external pure {
        revert("Reverted via revert");
    }

    function failWithLowLevelRevert(bytes memory data) external pure {
        assembly {
            revert(add(data, 32), mload(data))
        }
    }

    function failWithAssert() external pure {
        assert(false);
    }

    function failWithArithmetic() external pure {
        uint256 i = 0;
        i--; // Arithmetic underflow
    }

    function failWithIndexOutOfBounds() external pure {
        bytes1[] memory arr = new bytes1[](1);
        arr[1] = 0x01; // Index out of bounds
    }

    function failWithDivisionByZero(uint256 x) external pure {
        x / (x - x);
    }

    function failWithTransfer() external {
        // transfer more than its own balance
        payable(msg.sender).transfer(address(this).balance + 1);
    }

    function failWithRequireNoReason() external pure {
        require(false);
    }

    function failWithEmptyRevert() external pure {
        revert();
    }

    function failWithCallUnknown() external {
        UnknownContract(address(this)).unknownFunction();
    }
}
