// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {XUSD} from "./XUSD.sol";

contract CrossChainBridge is CCIPReceiver {
    XUSD public immutable xusd;
    address public immutable deployer;

    mapping(uint64 => address) public trustedRemote;
    mapping(bytes32 => bool) public processedMessages;

    error CrossChainBridge__OnlyDeployer();
    error CrossChainBridge__ZeroAddressRemote();
    error CrossChainBridge__ZeroAddressXUSD();
    error CrossChainBridge__RemoteAlreadySet();
    error CrossChainBridge__ZeroAmount();
    error CrossChainBridge__ZeroAddressRecipient();
    error CrossChainBridge__UnsupportedDestinationChain();
    error CrossChainBridge__InsufficientFee();
    error CrossChainBridge__RefundFailed();
    error CrossChainBridge__UntrustedSourceChain();
    error CrossChainBridge__UntrustedSourceBridge();
    error CrossChainBridge__MessageAlreadyProcessed();

    constructor(address router, address _xusd) CCIPReceiver(router) {
        if (_xusd == address(0)) {
            revert CrossChainBridge__ZeroAddressXUSD();
        }

        xusd = XUSD(_xusd);
        deployer = msg.sender;
    }

    modifier onlyDeployer() {
        if (msg.sender != deployer) {
            revert CrossChainBridge__OnlyDeployer();
        }
        _;
    }

    function setTrustedRemote(uint64 sourceChainSelector, address remoteBridge) external onlyDeployer {
        if (remoteBridge == address(0)) {
            revert CrossChainBridge__ZeroAddressRemote();
        }

        if (trustedRemote[sourceChainSelector] != address(0)) {
            revert CrossChainBridge__RemoteAlreadySet();
        }

        trustedRemote[sourceChainSelector] = remoteBridge;
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        if (processedMessages[message.messageId]) {
            revert CrossChainBridge__MessageAlreadyProcessed();
        }

        address trustedBridge = trustedRemote[message.sourceChainSelector];

        if (trustedBridge == address(0)) {
            revert CrossChainBridge__UntrustedSourceChain();
        }

        address sourceBridge = abi.decode(message.sender, (address));

        if (sourceBridge != trustedBridge) {
            revert CrossChainBridge__UntrustedSourceBridge();
        }

        (address recipient, uint256 amount) = abi.decode(message.data, (address, uint256));

        processedMessages[message.messageId] = true;

        xusd.mint(recipient, amount);
    }

    function sendXUSD(uint64 destinationChainSelector, address recipient, uint256 amount)
        external
        payable
        returns (bytes32 messageId)
    {
        if (amount == 0) {
            revert CrossChainBridge__ZeroAmount();
        }

        if (recipient == address(0)) {
            revert CrossChainBridge__ZeroAddressRecipient();
        }

        if (trustedRemote[destinationChainSelector] == address(0)) {
            revert CrossChainBridge__UnsupportedDestinationChain();
        }

        if (!IRouterClient(i_ccipRouter).isChainSupported(destinationChainSelector)) {
            revert CrossChainBridge__UnsupportedDestinationChain();
        }

        // Burn xUSD on the source chain before sending the CCIP message.
        xusd.burn(msg.sender, amount);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(trustedRemote[destinationChainSelector]),
            data: abi.encode(recipient, amount),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            feeToken: address(0),
            extraArgs: ""
        });

        uint256 fee = IRouterClient(i_ccipRouter).getFee(destinationChainSelector, message);

        if (msg.value < fee) {
            revert CrossChainBridge__InsufficientFee();
        }

        messageId = IRouterClient(i_ccipRouter).ccipSend{value: fee}(destinationChainSelector, message);

        if (msg.value > fee) {
            (bool success,) = payable(msg.sender).call{value: msg.value - fee}("");

            if (!success) {
                revert CrossChainBridge__RefundFailed();
            }
        }
    }
}
