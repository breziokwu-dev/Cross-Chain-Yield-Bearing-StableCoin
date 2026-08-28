// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CrossChainBridge} from "../../src/CrossChainBridge.sol";
import {XUSD} from "../../src/XUSD.sol";
import {MockCCIPRouter} from "../../src/MockCCIPRouter.sol";

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
}