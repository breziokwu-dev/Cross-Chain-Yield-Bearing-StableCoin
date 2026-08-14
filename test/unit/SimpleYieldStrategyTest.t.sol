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

    function test_Withdraw() public {
        mockUSDC.mint(vault, 100e6);

        vm.startPrank(vault);
        mockUSDC.approve(address(strategy), 100e6);
        strategy.deposit(100e6);

        strategy.withdraw(40e6);
        vm.stopPrank();

        assertEq(mockUSDC.balanceOf(address(strategy)), 60e6);
        assertEq(mockUSDC.balanceOf(vault), 40e6);
        assertEq(strategy.totalValue(), 60e6);
    }

    function test_Withdraw_RevertsIfZeroAmount() public {
        vm.prank(vault);

        vm.expectRevert(SimpleYieldStrategy.SYS__ZeroAmount.selector);
        strategy.withdraw(0);
    }

    function test_Withdraw_RevertsIfGreaterThanDepositedValue() public {
        mockUSDC.mint(vault, 100e6);

        vm.startPrank(vault);
        mockUSDC.approve(address(strategy), 100e6);
        strategy.deposit(100e6);

        vm.expectRevert(
            SimpleYieldStrategy.SYS__GreaterThanDepositedValue.selector
        );
        strategy.withdraw(101e6);

        vm.stopPrank();
    }

    function test_Withdraw_OnlyVaultCanWithdraw() public {
        vm.expectRevert(SimpleYieldStrategy.SYS__OnlyVault.selector);

        strategy.withdraw(10e6);
    }

    function test_Withdraw_RevertsIfNotLive() public {
        mockUSDC.mint(vault, 100e6);

        vm.startPrank(vault);
        mockUSDC.approve(address(strategy), 100e6);
        strategy.deposit(100e6);

        strategy.setLive(false);

        vm.expectRevert(SimpleYieldStrategy.SYS__NotLive.selector);
        strategy.withdraw(50e6);

        vm.stopPrank();
    }

    function test_SimulateYield_SuccessfulSimulation() public {
        mockUSDC.mint(vault, 100e6);

        vm.startPrank(vault);
        mockUSDC.approve(address(strategy), 100e6);
        strategy.deposit(100e6);

        strategy.simulateYield(20e6);
        vm.stopPrank();

        assertEq(strategy.totalValue(), 120e6);
    }

    function test_SimulateYield_RevertsIfZeroAmount() public {
        vm.prank(vault);

        vm.expectRevert(SimpleYieldStrategy.SYS__ZeroAmount.selector);
        strategy.simulateYield(0);
    }

    function test_SimulateYield_OnlyVaultCanSimulateYield() public {
        vm.expectRevert(SimpleYieldStrategy.SYS__OnlyVault.selector);

        strategy.simulateYield(10e6);
    }

    function test_SimulateYield_RevertsIfNotLive() public {
        mockUSDC.mint(vault, 100e6);

        vm.startPrank(vault);
        mockUSDC.approve(address(strategy), 100e6);
        strategy.deposit(100e6);

        strategy.setLive(false);

        vm.expectRevert(SimpleYieldStrategy.SYS__NotLive.selector);
        strategy.simulateYield(10e6);

        vm.stopPrank();
    }

    function test_SimulateYield_MultipleSimulationsAccumulate() public {
        mockUSDC.mint(vault, 100e6);

        vm.startPrank(vault);
        mockUSDC.approve(address(strategy), 100e6);
        strategy.deposit(100e6);

        strategy.simulateYield(10e6);
        strategy.simulateYield(15e6);
        vm.stopPrank();

        assertEq(strategy.totalValue(), 125e6);
    }

}