// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CrossChainBridge} from "../../src/CrossChainBridge.sol";
import {XUSD} from "../../src/XUSD.sol";
import {MockCCIPRouter} from "../../src/MockCCIPRouter.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";

contract CrossChainBridgeTest is Test {
    CrossChainBridge bridge;
    MockCCIPRouter router;
    XUSD xusd;

    address deployer = makeAddr("deployer");
    address remoteBridge = makeAddr("remoteBridge");
    address attacker = makeAddr("attacker");

    uint64 constant SOURCE_CHAIN_SELECTOR = 16015286601757825753;

    function setUp() public {
        vm.startPrank(deployer);

        xusd = new XUSD();

        router = new MockCCIPRouter();

        bridge = new CrossChainBridge(
            address(router),
            address(xusd)
        );

        xusd.authorizeBridge(address(bridge));

        vm.stopPrank();
    }

    // ---------------------------------------------------------------
    // Initial State
    // ---------------------------------------------------------------

    function test_InitialState() public view {
        assertEq(address(bridge.xusd()), address(xusd));
        assertEq(bridge.deployer(), deployer);
        assertEq(
            bridge.trustedRemote(SOURCE_CHAIN_SELECTOR),
            address(0)
        );
    }

    // ---------------------------------------------------------------
    // setTrustedRemote()
    // ---------------------------------------------------------------

    function test_SetTrustedRemote_DeployerCanSet() public {
        vm.prank(deployer);

        bridge.setTrustedRemote(
            SOURCE_CHAIN_SELECTOR,
            remoteBridge
        );

        assertEq(
            bridge.trustedRemote(SOURCE_CHAIN_SELECTOR),
            remoteBridge
        );
    }

    function test_SetTrustedRemote_RevertsIfNotDeployer() public {
        vm.prank(attacker);

        vm.expectRevert(
            CrossChainBridge.CrossChainBridge__OnlyDeployer.selector
        );

        bridge.setTrustedRemote(
            SOURCE_CHAIN_SELECTOR,
            remoteBridge
        );
    }

    function test_SetTrustedRemote_RevertsIfZeroAddress() public {
        vm.prank(deployer);

        vm.expectRevert(
            CrossChainBridge.CrossChainBridge__ZeroAddressRemote.selector
        );

        bridge.setTrustedRemote(
            SOURCE_CHAIN_SELECTOR,
            address(0)
        );
    }

    function test_SetTrustedRemote_RevertsIfAlreadySet() public {
        vm.startPrank(deployer);

        bridge.setTrustedRemote(
            SOURCE_CHAIN_SELECTOR,
            remoteBridge
        );

        vm.expectRevert(
            CrossChainBridge.CrossChainBridge__RemoteAlreadySet.selector
        );

        bridge.setTrustedRemote(
            SOURCE_CHAIN_SELECTOR,
            makeAddr("anotherBridge")
        );

        vm.stopPrank();
    }

    function test_SendXUSD_BurnsCorrectAmount() public {
        uint256 amount = 400 ether;

        vm.prank(address(bridge));
        xusd.mint(address(this), 1000 ether);

        vm.prank(deployer);
        bridge.setTrustedRemote(
            SOURCE_CHAIN_SELECTOR,
            makeAddr("destinationBridge")
        );

        uint256 supplyBefore = xusd.totalSupply();
        uint256 balanceBefore = xusd.balanceOf(address(this));

        bridge.sendXUSD{value: router.MOCK_FEE()}(
            SOURCE_CHAIN_SELECTOR,
            makeAddr("recipient"),
            amount
        );

        assertEq(
            xusd.balanceOf(address(this)),
            balanceBefore - amount
        );

        assertEq(
            xusd.totalSupply(),
            supplyBefore - amount
        );
    }

    function test_SendXUSD_EncodesCorrectMessage() public {
        uint256 amount = 400 ether;
        address recipient = makeAddr("recipient");
        address destinationBridge = makeAddr("destinationBridge");

        vm.prank(address(bridge));
        xusd.mint(address(this), 1000 ether);

        vm.prank(deployer);
        bridge.setTrustedRemote(
            SOURCE_CHAIN_SELECTOR,
            destinationBridge
        );

        bridge.sendXUSD{value: router.MOCK_FEE()}(
            SOURCE_CHAIN_SELECTOR,
            recipient,
            amount
        );

        assertEq(
            router.lastDestinationChainSelector(),
            SOURCE_CHAIN_SELECTOR
        );

        assertEq(
            abi.decode(router.lastReceiver(), (address)),
            destinationBridge
        );

        (address encodedRecipient, uint256 encodedAmount) =
            abi.decode(router.lastData(), (address, uint256));

        assertEq(encodedRecipient, recipient);
        assertEq(encodedAmount, amount);

        assertEq(router.lastTokenAmountCount(), 0);
        assertEq(router.lastFeeToken(), address(0));
    }

    function test_ReceiveXUSD_ValidMessageMints() public {
        address sourceBridge = makeAddr("sourceBridge");
        address recipient = makeAddr("recipient");
        uint256 amount = 400 ether;

        vm.prank(deployer);
        bridge.setTrustedRemote(
            SOURCE_CHAIN_SELECTOR,
            sourceBridge
        );

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256("message-1"),
            sourceChainSelector: SOURCE_CHAIN_SELECTOR,
            sender: abi.encode(sourceBridge),
            data: abi.encode(recipient, amount),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        router.deliverMessage(
            address(bridge),
            message
        );

        assertEq(xusd.balanceOf(recipient), amount);
        assertEq(xusd.totalSupply(), amount);
    }

    function test_ReceiveXUSD_RevertsForUntrustedSourceChain() public {
        uint64 untrustedChainSelector = 999999;
        address sourceBridge = makeAddr("sourceBridge");
        address recipient = makeAddr("recipient");

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256("untrusted-chain"),
            sourceChainSelector: untrustedChainSelector,
            sender: abi.encode(sourceBridge),
            data: abi.encode(recipient, 100 ether),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.expectRevert(
            CrossChainBridge.CrossChainBridge__UntrustedSourceChain.selector
        );

        router.deliverMessage(
            address(bridge),
            message
        );

        assertEq(xusd.balanceOf(recipient), 0);
        assertEq(xusd.totalSupply(), 0);
    }

    function test_ReceiveXUSD_RevertsForUntrustedSourceBridge() public {
        address trustedSourceBridge = makeAddr("trustedSourceBridge");
        address forgedSourceBridge = makeAddr("forgedSourceBridge");
        address recipient = makeAddr("recipient");

        vm.prank(deployer);
        bridge.setTrustedRemote(
            SOURCE_CHAIN_SELECTOR,
            trustedSourceBridge
        );

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256("forged-source"),
            sourceChainSelector: SOURCE_CHAIN_SELECTOR,
            sender: abi.encode(forgedSourceBridge),
            data: abi.encode(recipient, 100 ether),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.expectRevert(
            CrossChainBridge.CrossChainBridge__UntrustedSourceBridge.selector
        );

        router.deliverMessage(
            address(bridge),
            message
        );

        assertEq(xusd.balanceOf(recipient), 0);
        assertEq(xusd.totalSupply(), 0);
    }

    function test_ReceiveXUSD_RevertsIfMessageAlreadyProcessed() public {
        address sourceBridge = makeAddr("sourceBridge");
        address recipient = makeAddr("recipient");
        uint256 amount = 100 ether;

        vm.prank(deployer);
        bridge.setTrustedRemote(
            SOURCE_CHAIN_SELECTOR,
            sourceBridge
        );

        bytes32 messageId = keccak256("replay-message");

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: messageId,
            sourceChainSelector: SOURCE_CHAIN_SELECTOR,
            sender: abi.encode(sourceBridge),
            data: abi.encode(recipient, amount),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        // First delivery succeeds.
        router.deliverMessage(
            address(bridge),
            message
        );

        assertEq(xusd.balanceOf(recipient), amount);
        assertTrue(bridge.processedMessages(messageId));

        // Second delivery must fail.
        vm.expectRevert(
            CrossChainBridge.CrossChainBridge__MessageAlreadyProcessed.selector
        );

        router.deliverMessage(
            address(bridge),
            message
        );

        // Balance must not increase.
        assertEq(xusd.balanceOf(recipient), amount);
    }

    function test_ReceiveXUSD_FailedMessageIsNotMarkedProcessed() public {
        address sourceBridge = makeAddr("sourceBridge");
        address forgedBridge = makeAddr("forgedBridge");
        address recipient = makeAddr("recipient");

        vm.prank(deployer);
        bridge.setTrustedRemote(
            SOURCE_CHAIN_SELECTOR,
            sourceBridge
        );

        bytes32 messageId = keccak256("failed-message");

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: messageId,
            sourceChainSelector: SOURCE_CHAIN_SELECTOR,
            sender: abi.encode(forgedBridge),
            data: abi.encode(recipient, 100 ether),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.expectRevert(
            CrossChainBridge.CrossChainBridge__UntrustedSourceBridge.selector
        );

        router.deliverMessage(
            address(bridge),
            message
        );

        assertFalse(
            bridge.processedMessages(messageId)
        );
    }
}