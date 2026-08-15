// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockUSDC} from "../../src/MockUSDC.sol";
import {XUSD} from "../../src/XUSD.sol";
import {StablecoinVault} from "../../src/StablecoinVault.sol";
import {SimpleYieldStrategy} from "../../src/SimpleYieldStrategy.sol";

contract StablecoinVaultTest is Test {
    MockUSDC mockUSDC;
    XUSD xusd;
    StablecoinVault vault;
    SimpleYieldStrategy strategy;

    address user = makeAddr("user");

    function setUp() public {
        mockUSDC = new MockUSDC();
        xusd = new XUSD();

        vault = new StablecoinVault(address(mockUSDC), address(xusd));

        strategy = new SimpleYieldStrategy(address(mockUSDC), address(vault));

        vault.setStrategy(address(strategy));

        xusd.setVault(address(vault));

        mockUSDC.mint(user, 1000e6);
    }

    function test_AddressesAreCorrect() public view {
        assertEq(vault.getMockUSDCAddress(), address(mockUSDC));
        assertEq(vault.getXUSDAddress(), address(xusd));
    }

    function test_SetStrategy() public view {
        assertEq(vault.getStrategyAddress(), address(strategy));
    }

    function test_SetStrategy_RevertsIfZeroAddress() public {
        StablecoinVault newVault = new StablecoinVault(address(mockUSDC), address(xusd));

        vm.expectRevert(StablecoinVault.SV__ZeroAddressStrategy.selector);

        newVault.setStrategy(address(0));
    }

    function test_SetStrategy_RevertsIfAlreadySet() public {
        SimpleYieldStrategy anotherStrategy = new SimpleYieldStrategy(address(mockUSDC), address(vault));

        vm.expectRevert(StablecoinVault.SV__StrategyAlreadySet.selector);

        vault.setStrategy(address(anotherStrategy));
    }

    function test_SetStrategy_OnlyDeployer() public {
        address attacker = makeAddr("attacker");

        vm.prank(attacker);

        vm.expectRevert(StablecoinVault.SV__OnlyDeployer.selector);

        vault.setStrategy(address(strategy));
    }

    function test_IntiialAssetsAreZero() public view {
        assertEq(vault.totalAssets(), 0);
    }

    function test_Deposit() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vm.stopPrank();

        assertEq(vault.totalAssets(), 100e6);
        assertEq(strategy.totalValue(), 100e6);
        assertEq(vault.getCollateralBalance(user), 100e6);
        assertEq(mockUSDC.balanceOf(address(strategy)), 100e6);
        assertEq(mockUSDC.balanceOf(user), 900e6);
    }

    function test_Deposit_RevertsIfZeroAmount() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 0);

        vm.expectRevert(StablecoinVault.SV__MustBeMoreThanZero.selector);
        vault.deposit(0);

        vm.stopPrank();
    }

    function test_Deposit_RevertsIfInsufficientAllowance() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);

        vm.expectRevert();

        vault.deposit(200e6);

        vm.stopPrank();
    }

    function test_Deposit_UserCollateralUpdates() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);

        vault.deposit(100e6);
        vm.stopPrank();
        assertEq(vault.getCollateralBalance(user), 100e6);
    }

    function test_Deposit_MultipleDepositsAccumulate() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 300e6);

        vault.deposit(100e6);
        vault.deposit(200e6);

        vm.stopPrank();

        assertEq(vault.totalAssets(), 300e6);
        assertEq(vault.getCollateralBalance(user), 300e6);
        assertEq(mockUSDC.balanceOf(address(strategy)), 300e6);
        assertEq(strategy.totalValue(), 300e6);
    }

    function test_Deposit_MultipleDepositsAccumulateFromMultipleUsers() public {
        address user2 = makeAddr("user2");

        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vm.stopPrank();

        vm.startPrank(user2);
        mockUSDC.mint(user2, 500e6);
        mockUSDC.approve(address(vault), 200e6);
        vault.deposit(200e6);
        vm.stopPrank();

        assertEq(vault.totalAssets(), 300e6);
        assertEq(vault.getCollateralBalance(user), 100e6);
        assertEq(vault.getCollateralBalance(user2), 200e6);
    }

    function test_Deposit_EmitsDepositEvent() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);

        vm.expectEmit(true, true, false, true);
        emit StablecoinVault.Deposit(user, 100e6);

        vault.deposit(100e6);
        vm.stopPrank();
    }

    function test_Withdraw() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.withdraw(50e6);
        vm.stopPrank();

        assertEq(vault.totalAssets(), 50e6);
        assertEq(strategy.totalValue(), 50e6);
        assertEq(vault.getCollateralBalance(user), 50e6);
        assertEq(mockUSDC.balanceOf(address(strategy)), 50e6);
        assertEq(mockUSDC.balanceOf(user), 950e6);
    }

    function test_Withdraw_RevertsIfZeroAmount() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.expectRevert(StablecoinVault.SV__MustBeMoreThanZero.selector);
        vault.withdraw(0);

        vm.stopPrank();
    }

    function test_Withdraw_InsufficientCollateralReverts() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.expectRevert(StablecoinVault.SV__InsufficientCollateral.selector);
        vault.withdraw(200e6);

        vm.stopPrank();
    }

    function test_Withdraw_EmitsWithdrawEvent() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.expectEmit(true, true, false, true);
        emit StablecoinVault.Withdraw(user, 50e6);

        vault.withdraw(50e6);
        vm.stopPrank();
    }

    function test_Withdraw_MultipleWithdrawalsAccumulate() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 300e6);

        vault.deposit(300e6);
        vault.withdraw(100e6);
        vault.withdraw(50e6);

        vm.stopPrank();

        assertEq(vault.totalAssets(), 150e6);
        assertEq(vault.getCollateralBalance(user), 150e6);
        assertEq(mockUSDC.balanceOf(address(strategy)), 150e6);
        assertEq(strategy.totalValue(), 150e6);
    }

    function test_Withdraw_MultipleWithdrawalsAccumulateFromMultipleUsers() public {
        address user2 = makeAddr("user2");

        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.withdraw(50e6);
        vm.stopPrank();

        vm.startPrank(user2);
        mockUSDC.mint(user2, 500e6);
        mockUSDC.approve(address(vault), 200e6);
        vault.deposit(200e6);
        vault.withdraw(100e6);
        vm.stopPrank();

        assertEq(vault.totalAssets(), 150e6);
        assertEq(vault.getCollateralBalance(user), 50e6);
        assertEq(vault.getCollateralBalance(user2), 100e6);
    }

    function test_Withdraw_RevertsIfStrategyCannotWithdraw() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.expectRevert(StablecoinVault.SV__InsufficientCollateral.selector);

        vault.withdraw(101e6);

        vm.stopPrank();
    }

    function test_MintXUSD() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vault.mintXUSD(50e6);

        vm.stopPrank();

        assertEq(xusd.balanceOf(user), 50e6);
    }

    function test_MintXUSD_RevertsIfZeroAmount() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.expectRevert(StablecoinVault.SV__MustBeMoreThanZero.selector);
        vault.mintXUSD(0);

        vm.stopPrank();
    }

    function test_MintXUSD_RevertsIfInsufficientCollateral() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.expectRevert(StablecoinVault.SV__InsufficientCollateral.selector);
        vault.mintXUSD(101e6);

        vm.stopPrank();
    }

    function test_MintXUSD_EmitsMintedEvent() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.expectEmit(true, true, false, true);
        emit StablecoinVault.Minted(user, 50e6);

        vault.mintXUSD(50e6);
        vm.stopPrank();
    }

    function test_MintXUSD_RevertsIfNoCollateral() public {
        vm.startPrank(user);

        vm.expectRevert(StablecoinVault.SV__InsufficientCollateral.selector);

        vault.mintXUSD(50e6);

        vm.stopPrank();
    }

    function test_MintXUSD_MultipleMintsAccumulate() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vault.mintXUSD(50e6);
        vault.mintXUSD(30e6);

        vm.stopPrank();

        assertEq(xusd.balanceOf(user), 80e6);
    }

    function test_MintXUSD_MultipleMintsAccumulateFromMultipleUsers() public {
        address user2 = makeAddr("user2");

        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vault.mintXUSD(50e6);
        vm.stopPrank();

        vm.startPrank(user2);
        mockUSDC.mint(user2, 500e6);
        mockUSDC.approve(address(vault), 200e6);
        vault.deposit(200e6);

        vault.mintXUSD(100e6);
        vm.stopPrank();

        assertEq(xusd.balanceOf(user), 50e6);
        assertEq(xusd.balanceOf(user2), 100e6);
    }

    function test_MintXUSD_RevertsIfExceedingCollateralAfterMultipleMints() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vault.mintXUSD(50e6);

        vm.expectRevert(StablecoinVault.SV__InsufficientCollateral.selector);

        vault.mintXUSD(60e6);

        vm.stopPrank();
    }

    function test_MintXUSD_AllowsMintExactCollateral() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vault.mintXUSD(100e6);

        vm.stopPrank();

        assertEq(xusd.balanceOf(user), 100e6);
    }

    function test_BurnXUSD() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vault.mintXUSD(50e6);
        vault.burnXUSD(20e6);

        vm.stopPrank();

        assertEq(xusd.balanceOf(user), 30e6);
    }

    function test_BurnXUSD_BurnAllMintedXUSD() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(50e6);
        vault.burnXUSD(50e6);
        vm.stopPrank();
        assertEq(xusd.balanceOf(user), 0);
    }

    function test_BurnXUSD_CannotBurnMoreThanMinted() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(50e6);

        vm.expectRevert(StablecoinVault.SV__InsufficientXUSDMinted.selector);

        vault.burnXUSD(60e6);

        vm.stopPrank();
    }

    function test_BurnXUSD_EmitsBurnedEvent() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(50e6);

        vm.expectEmit(true, true, false, true);
        emit StablecoinVault.Burned(user, 20e6);

        vault.burnXUSD(20e6);
        vm.stopPrank();
    }

    function test_BurnXUSD_RevertsIfZeroAmount() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(50e6);

        vm.expectRevert(StablecoinVault.SV__MustBeMoreThanZero.selector);
        vault.burnXUSD(0);

        vm.stopPrank();
    }

    function test_BurnXUSD_MultipleBurnsAccumulate() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(50e6);

        vault.burnXUSD(20e6);
        vault.burnXUSD(10e6);

        vm.stopPrank();

        assertEq(xusd.balanceOf(user), 20e6);
    }

    function test_BurnXUSD_MultipleBurnsAccumulateFromMultipleUsers() public {
        address user2 = makeAddr("user2");

        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vault.mintXUSD(50e6);
        vault.burnXUSD(20e6);
        vm.stopPrank();

        vm.startPrank(user2);
        mockUSDC.mint(user2, 500e6);
        mockUSDC.approve(address(vault), 200e6);
        vault.deposit(200e6);

        vault.mintXUSD(100e6);
        vault.burnXUSD(30e6);
        vm.stopPrank();

        assertEq(xusd.balanceOf(user), 30e6);
        assertEq(xusd.balanceOf(user2), 70e6);
    }

    function test_BurnXUSD_RevertsIfExceedingMintedAfterMultipleBurns() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vault.mintXUSD(50e6);
        vault.burnXUSD(20e6);

        vm.expectRevert(StablecoinVault.SV__InsufficientXUSDMinted.selector);

        vault.burnXUSD(40e6);

        vm.stopPrank();
    }

    function test_Withdraw_CanOnlyWithdrawAvailableCollateral() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vault.mintXUSD(80e6);

        vm.expectRevert(StablecoinVault.SV__InsufficientCollateral.selector);

        vault.withdraw(30e6);

        vm.stopPrank();
    }

    function test_Withdraw_CanWithdrawAfterBurningXUSD() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vault.mintXUSD(80e6);
        vault.burnXUSD(30e6);

        vault.withdraw(30e6);

        vm.stopPrank();

        assertEq(vault.totalAssets(), 70e6);
        assertEq(strategy.totalValue(), 70e6);
        assertEq(vault.getCollateralBalance(user), 70e6);
        assertEq(mockUSDC.balanceOf(address(strategy)), 70e6);
        assertEq(mockUSDC.balanceOf(user), 930e6);
    }

    function test_Withdraw_CanWithdrawAllAfterBurningXUSD() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vault.mintXUSD(80e6);
        vault.burnXUSD(80e6);

        vault.withdraw(100e6);

        vm.stopPrank();

        assertEq(vault.totalAssets(), 0);
        assertEq(strategy.totalValue(), 0);
        assertEq(vault.getCollateralBalance(user), 0);
        assertEq(mockUSDC.balanceOf(address(strategy)), 0);
        assertEq(mockUSDC.balanceOf(user), 1000e6);
    }

    function test_Withdraw_CannotWithdrawMoreThanCollateralAfterBurningXUSD() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vault.mintXUSD(80e6);
        vault.burnXUSD(30e6);

        vm.expectRevert(StablecoinVault.SV__InsufficientCollateral.selector);

        vault.withdraw(80e6);

        vm.stopPrank();
    }

    function test_getTotalAssets() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vm.stopPrank();

        vm.prank(address(vault));
        strategy.simulateYield(20e6);
        assertEq(vault.totalAssets(), 120e6);
    }

    function test_FirstDepositGetsOneToOneShares() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.stopPrank();

        assertEq(vault.getShareBalance(user), 100e6);
        assertEq(vault.getTotalShares(), 100e6);
    }

    function test_SecondDepositWithoutYield() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vm.stopPrank();
        address user2 = makeAddr("user2");
        mockUSDC.mint(user2, 100e6);
        vm.startPrank(user2);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vm.stopPrank();
        assertEq(vault.getShareBalance(user), 100e6);
        assertEq(vault.getShareBalance(user2), 100e6);
        assertEq(vault.getTotalShares(), 200e6);
    }

    function test_SecondDepositWithYield() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vm.stopPrank();

        vm.startPrank(address(vault));
        strategy.simulateYield(20e6);
        vm.stopPrank();

        address user2 = makeAddr("user2");
        mockUSDC.mint(user2, 100e6);
        vm.startPrank(user2);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vm.stopPrank();

        assertEq(vault.getShareBalance(user), 100e6);
        assertEq(vault.getShareBalance(user2), 83_333_333);
        assertEq(vault.totalAssets(), 220e6);
        assertEq(vault.getTotalShares(), 183_333_333);
    }

    function test_Deposit_FailedTransferDoesNotCreateShares() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 50e6);

        vm.expectRevert();

        vault.deposit(100e6);

        vm.stopPrank();

        assertEq(vault.getShareBalance(user), 0);
        assertEq(vault.getTotalShares(), 0);
    } 
}
