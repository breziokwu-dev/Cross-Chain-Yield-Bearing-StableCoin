// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";

contract MockCCIPRouter is IRouterClient {
    uint256 public constant MOCK_FEE = 0.01 ether;

    bytes32 public lastMessageId;
    uint64 public lastDestinationChainSelector;
    bytes public lastReceiver;
    bytes public lastData;
    uint256 public lastTokenAmountCount;
    address public lastFeeToken;
    bytes public lastExtraArgs;

    bool public supported = true;

    function isChainSupported(
        uint64
    ) external view override returns (bool) {
        return supported;
    }

    function getFee(
        uint64,
        Client.EVM2AnyMessage memory
    ) external pure override returns (uint256) {
        return MOCK_FEE;
    }

    function ccipSend(
        uint64 destinationChainSelector,
        Client.EVM2AnyMessage calldata message
    ) external payable override returns (bytes32) {
        require(msg.value >= MOCK_FEE, "Insufficient fee");

        lastMessageId = keccak256(
            abi.encode(
                block.chainid,
                destinationChainSelector,
                message.receiver,
                message.data
            )
        );

        lastDestinationChainSelector = destinationChainSelector;

        lastReceiver = message.receiver;
        lastData = message.data;
        lastFeeToken = message.feeToken;
        lastExtraArgs = message.extraArgs;

        lastTokenAmountCount = message.tokenAmounts.length;

        return lastMessageId;
    }

    function setSupported(bool _supported) external {
        supported = _supported;
    }

    function deliverMessage(
        address receiver,
        Client.Any2EVMMessage memory message
    ) external {
        CCIPReceiver(receiver).ccipReceive(message);
    }
}