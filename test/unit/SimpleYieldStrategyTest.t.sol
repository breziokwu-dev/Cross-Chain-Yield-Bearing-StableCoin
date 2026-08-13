// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockUSDC} from "../../src/MockUSDC.sol";
import {SimpleYieldStrategy} from "../../src/SimpleYieldStrategy.sol";

contract SimpleYieldStrategyTest is Test {
    MockUSDC mockUSDC;
    SimpleYieldStrategy strategy;

    address vault = makeAddr("vault");

    function setUp() public {
        mockUSDC = new MockUSDC();
        strategy = new SimpleYieldStrategy(address(mockUSDC),vault);
    }
    
    function test_StrategyIsDeployedProperly() public view {
        assertEq(address(strategy.getMockUSDCAddress()), address(mockUSDC));
        assertEq(strategy.getVaultAddress(), vault);
        assertEq(strategy.totalValue(), 0);
    }

    function test_Deposit() public {
        uint256 depositAmount = 100e6;

        mockUSDC.mint(vault, depositAmount);
        vm.startPrank(vault);
        mockUSDC.approve(address(strategy), depositAmount);
        strategy.deposit(depositAmount);
        vm.stopPrank();

        assertEq(mockUSDC.balanceOf(address(strategy)), 100e6);
        assertEq(strategy.totalValue(), 100e6);
    }

    function test_Deposit_RevertsIfZeroAmount() public {
        vm.startPrank(vault);
        mockUSDC.approve(address(strategy), 0);

        vm.expectRevert(SimpleYieldStrategy.SYS__ZeroAmount.selector);
        strategy.deposit(0);

        vm.stopPrank();
    }

    function test_Deposit_RevertsIfNotLive() public {
        uint256 depositAmount = 100e6;

        mockUSDC.mint(vault, depositAmount);
        vm.startPrank(vault);
        mockUSDC.approve(address(strategy), depositAmount);

        strategy.setLive(false);

        vm.expectRevert(SimpleYieldStrategy.SYS__NotLive.selector);
        strategy.deposit(depositAmount);

        vm.stopPrank();
    }

    function test_Deposit_OnlyVaultCanDeposit() public {
        uint256 depositAmount = 100e6;

        mockUSDC.mint(vault, depositAmount);
        vm.startPrank(makeAddr("notVault"));
        mockUSDC.approve(address(strategy), depositAmount);

        vm.expectRevert(SimpleYieldStrategy.SYS__OnlyVault.selector);
        strategy.deposit(depositAmount);

        vm.stopPrank();
    }

    function test_Deposit_InsufficientBalanceShouldRevert() public {
        uint256 depositAmount = 100e6;

        mockUSDC.mint(vault, 50e6);

        vm.startPrank(vault);
        mockUSDC.approve(address(strategy), depositAmount);

        vm.expectRevert();
        strategy.deposit(depositAmount);

        vm.stopPrank();
    }

    function test_SetLive_OnlyVaultCanSetLive() public {
        vm.expectRevert(SimpleYieldStrategy.SYS__OnlyVault.selector);
        strategy.setLive(false);      
    }
}