// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Safe ERC20 + ETH transfers used by Router02
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(
                bytes4(keccak256("approve(address,uint256)")),
                to, value
            ));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: APPROVE_FAILED");
    }

    function safeTransfer(address token, address to, uint value) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(
                bytes4(keccak256("transfer(address,uint256)")),
                to, value
            ));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: TRANSFER_FAILED");
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(
                bytes4(keccak256("transferFrom(address,address,uint256)")),
                from, to, value
            ));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: TRANSFER_FROM_FAILED");
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value: value}(new bytes(0));
        require(success, "TransferHelper: ETH_TRANSFER_FAILED");
    }
}