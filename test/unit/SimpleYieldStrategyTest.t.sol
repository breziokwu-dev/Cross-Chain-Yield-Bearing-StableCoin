// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockUSDC} from "../../src/MockUSDC.sol";
import {SimpleYieldStrategy} from "../../src/SimpleYieldStrategy.sol";

contract SimpleYieldStrategyTest is Test {
    MockUSDC mockUSDC;
    SimpleYieldStrategy strategy;

    address vault = makeAddr("vault");
    address user = makeAddr("user");

    function setUp() public {
        mockUSDC = new MockUSDC();
        strategy = new SimpleYieldStrategy(address(mockUSDC), vault);

        mockUSDC.mint(user, 1000e6);
    }

    function _deposit(uint256 amount) internal {
        mockUSDC.mint(vault, amount);
        vm.startPrank(vault);
        mockUSDC.approve(address(strategy), amount);
        strategy.deposit(amount);
        vm.stopPrank();
    }

    function test_StrategyIsDeployedProperly() public view {
        assertEq(address(strategy.getMockUSDCAddress()), address(mockUSDC));
        assertEq(strategy.getVaultAddress(), vault);
        assertEq(strategy.totalValue(), 0);
    }

    function test_Deposit() public {
        _deposit(100e6);

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
        mockUSDC.mint(vault, 100e6);
        vm.startPrank(vault);
        mockUSDC.approve(address(strategy), 100e6);
        strategy.setLive(false);

        vm.expectRevert(SimpleYieldStrategy.SYS__NotLive.selector);
        strategy.deposit(100e6);

        vm.stopPrank();
    }

    function test_Deposit_OnlyVaultCanDeposit() public {
        mockUSDC.mint(vault, 100e6);
        vm.startPrank(makeAddr("notVault"));
        mockUSDC.approve(address(strategy), 100e6);

        vm.expectRevert(SimpleYieldStrategy.SYS__OnlyVault.selector);
        strategy.deposit(100e6);

        vm.stopPrank();
    }

    function test_Deposit_InsufficientBalanceShouldRevert() public {
        mockUSDC.mint(vault, 50e6);

        vm.startPrank(vault);
        mockUSDC.approve(address(strategy), 100e6);

        vm.expectRevert();
        strategy.deposit(100e6);

        vm.stopPrank();
    }

    function test_SetLive_OnlyVaultCanSetLive() public {
        vm.expectRevert(SimpleYieldStrategy.SYS__OnlyVault.selector);
        strategy.setLive(false);
    }

    function test_Withdraw() public {
        _deposit(100e6);

        vm.prank(vault);
        strategy.withdraw(40e6);

        assertEq(mockUSDC.balanceOf(address(strategy)), 60e6);
        assertEq(mockUSDC.balanceOf(vault), 40e6);
        assertEq(strategy.totalValue(), 60e6);
    }

    function test_Withdraw_RevertsIfZeroAmount() public {
        vm.prank(vault);

        vm.expectRevert(SimpleYieldStrategy.SYS__ZeroAmount.selector);
        strategy.withdraw(0);
    }

    function test_Withdraw_RevertsIfGreaterThanTotalValue() public {
        _deposit(100e6);

        vm.prank(vault);
        vm.expectRevert(SimpleYieldStrategy.SYS__GreaterThanTotalValue.selector);
        strategy.withdraw(101e6);
    }

    function test_Withdraw_OnlyVaultCanWithdraw() public {
        vm.expectRevert(SimpleYieldStrategy.SYS__OnlyVault.selector);
        strategy.withdraw(10e6);
    }

    function test_Withdraw_RevertsIfNotLive() public {
        _deposit(100e6);

        vm.startPrank(vault);
        strategy.setLive(false);

        vm.expectRevert(SimpleYieldStrategy.SYS__NotLive.selector);
        strategy.withdraw(50e6);

        vm.stopPrank();
    }

    function test_Withdraw_MultipleWithdrawalsAccumulate() public {
        _deposit(100e6);

        vm.startPrank(vault);
        strategy.withdraw(30e6);
        strategy.withdraw(20e6);
        vm.stopPrank();

        assertEq(mockUSDC.balanceOf(address(strategy)), 50e6);
        assertEq(mockUSDC.balanceOf(vault), 50e6);
        assertEq(strategy.totalValue(), 50e6);
    }

    function test_Withdraw_ConsumesYieldBeforePrincipal() public {
        _deposit(100e6);

        vm.startPrank(vault);
        strategy.simulateYield(20e6);
        strategy.withdraw(10e6);
        vm.stopPrank();

        assertEq(mockUSDC.balanceOf(address(strategy)), 110e6);
        assertEq(strategy.totalValue(), 110e6);

        vm.prank(vault);
        strategy.withdraw(110e6);

        assertEq(mockUSDC.balanceOf(address(strategy)), 0);
        assertEq(strategy.totalValue(), 0);
    }

    function test_SimulateYield_SuccessfulSimulation() public {
        _deposit(100e6);

        vm.prank(vault);
        strategy.simulateYield(20e6);

        assertEq(mockUSDC.balanceOf(address(strategy)), 120e6);
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
        _deposit(100e6);

        vm.startPrank(vault);
        strategy.setLive(false);

        vm.expectRevert(SimpleYieldStrategy.SYS__NotLive.selector);
        strategy.simulateYield(10e6);

        vm.stopPrank();
    }

    function test_SimulateYield_MultipleSimulationsAccumulate() public {
        _deposit(100e6);

        vm.startPrank(vault);
        strategy.simulateYield(10e6);
        strategy.simulateYield(15e6);
        vm.stopPrank();

        assertEq(mockUSDC.balanceOf(address(strategy)), 125e6);
        assertEq(strategy.totalValue(), 125e6);
    }

    function test_SimulateLoss_ReducesTokenBalanceAndValue() public {
        _deposit(100e6);

        vm.prank(vault);
        strategy.simulateLoss(20e6);

        assertEq(mockUSDC.balanceOf(address(strategy)), 80e6);
        assertEq(strategy.totalValue(), 80e6);
    }

    function test_SimulateLoss_RevertsIfGreaterThanTotalValue() public {
        _deposit(100e6);

        vm.prank(vault);
        vm.expectRevert(SimpleYieldStrategy.SYS__GreaterThanTotalValue.selector);
        strategy.simulateLoss(101e6);
    }

    function test_SimulateLoss_ConsumesYieldBeforePrincipal() public {
        _deposit(100e6);

        vm.startPrank(vault);
        strategy.simulateYield(20e6);
        strategy.simulateLoss(10e6);
        vm.stopPrank();

        assertEq(mockUSDC.balanceOf(address(strategy)), 110e6);
        assertEq(strategy.totalValue(), 110e6);
    }
}
