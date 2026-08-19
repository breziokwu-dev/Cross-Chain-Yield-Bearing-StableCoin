// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
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
    address user2 = makeAddr("user2");

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

        vault.mintXUSD(30e6);
        vault.mintXUSD(20e6);

        vm.stopPrank();

        assertEq(xusd.balanceOf(user), 50e6);
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

        vault.mintXUSD(66_666_666);

        vm.stopPrank();

        assertEq(xusd.balanceOf(user), 66_666_666);
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

        vault.mintXUSD(60e6);

        vm.expectRevert(StablecoinVault.SV__InsufficientCollateral.selector);

        vault.withdraw(50e6);

        vm.stopPrank();
    }

    function test_Withdraw_CanWithdrawAfterBurningXUSD() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vault.mintXUSD(60e6);
        vault.burnXUSD(30e6);

        vault.withdraw(40e6);

        vm.stopPrank();

        assertEq(vault.totalAssets(), 60e6);
        assertEq(strategy.totalValue(), 60e6);
        assertEq(vault.getCollateralBalance(user), 60e6);
        assertEq(mockUSDC.balanceOf(address(strategy)), 60e6);
        assertEq(mockUSDC.balanceOf(user), 940e6);
    }

    function test_Withdraw_CanWithdrawAllAfterBurningXUSD() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vault.mintXUSD(60e6);
        vault.burnXUSD(60e6);

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

        vault.mintXUSD(60e6);
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

    function test_ConvertSharesToAssets() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.stopPrank();

        assertEq(vault.convertToAssets(100e6), 100e6);
    }

    function test_ConvertSharesToAssetsAfterYield() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.stopPrank();

        vm.prank(address(vault));
        strategy.simulateYield(20e6);

        assertEq(vault.convertToAssets(100e6), 120e6);
    }

    function test_WithdrawBurnsShares() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vault.withdraw(40e6);

        vm.stopPrank();

        assertEq(vault.getShareBalance(user), 60e6);
        assertEq(vault.getTotalShares(), 60e6);
    }

    function test_WithdrawAfterYieldBurnsCorrectShares() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.stopPrank();

        vm.prank(address(vault));
        strategy.simulateYield(20e6);

        vm.prank(user);
        vault.withdraw(60e6);

        assertEq(vault.getShareBalance(user), 50e6);
        assertEq(vault.getTotalShares(), 50e6);
    }

    function test_MintXUSD_AccountsForYield() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.stopPrank();

        vm.prank(address(vault));
        strategy.simulateYield(20e6);

        vm.prank(user);
        vault.mintXUSD(80e6);

        assertEq(vault.getxusdMinted(user), 80e6);
        assertEq(xusd.balanceOf(user), 80e6);
    }

    function test_MintXUSD_RevertsAccountsForYield() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.stopPrank();

        vm.prank(address(vault));
        strategy.simulateYield(20e6);

        vm.prank(user);
        vm.expectRevert(StablecoinVault.SV__InsufficientCollateral.selector);
        vault.mintXUSD(81e6);
    }

    function test_WithdrawAfterYieldWithXUSDDebt() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.stopPrank();

        vm.prank(address(vault));
        strategy.simulateYield(20e6);

        vm.prank(user);
        vault.mintXUSD(60e6);

        vm.prank(user);
        vault.withdraw(60e6);
    }

    function test_WithdrawAfterYieldCannotExceedAvailableCollateral() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.stopPrank();

        vm.prank(address(vault));
        strategy.simulateYield(20e6);

        vm.prank(user);
        vault.mintXUSD(60e6);

        vm.startPrank(user);

        vm.expectRevert(StablecoinVault.SV__InsufficientCollateral.selector);
        vault.withdraw(61e6);

        vm.stopPrank();
    }

    function test_HealthFactor() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.stopPrank();

        assertEq(vault.healthFactor(user), 166);
    }

    function test_HealthFactorImprovesWithYield() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.stopPrank();

        vm.prank(address(vault));
        strategy.simulateYield(20e6);

        assertEq(vault.healthFactor(user), 200);
    }

    function test_HealthFactorWithNoDebt() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.stopPrank();

        assertEq(vault.healthFactor(user), type(uint256).max);
    }

    function test_IsLiquidatableReturnsFalseForHealthyPosition() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.stopPrank();

        assertEq(vault.isLiquidatable(user), false);
    }

    function test_SimulateLoss_SuccessfulSimulation() public {
        mockUSDC.mint(address(vault), 100e6);

        vm.startPrank(address(vault));
        mockUSDC.approve(address(strategy), 100e6);
        strategy.deposit(100e6);

        strategy.simulateLoss(20e6);
        vm.stopPrank();

        assertEq(strategy.totalValue(), 80e6);
    }

    function test_TotalAssetsDecreaseAfterLoss() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.stopPrank();

        vm.prank(address(vault));
        strategy.simulateLoss(40e6);

        assertEq(vault.totalAssets(), 60e6);
    }

    function test_HealthFactorFallsAfterLoss() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.stopPrank();

        vm.prank(address(vault));
        strategy.simulateLoss(40e6);

        assertEq(vault.healthFactor(user), 100);
        assertTrue(vault.isLiquidatable(user));
    }

    function test_PositionBecomesLiquidatableAfterLoss() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.stopPrank();

        vm.prank(address(vault));
        strategy.simulateLoss(40e6);

        assertTrue(vault.isLiquidatable(user));
        assertEq(vault.healthFactor(user), 100);
    }

    function test_Liquidate() public {
        // User deposits collateral and mints xUSD
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);
        vm.stopPrank();

        // Make the user's position unhealthy
        vm.prank(address(vault));
        strategy.simulateLoss(40e6);

        assertTrue(vault.isLiquidatable(user));
        assertEq(vault.getxusdMinted(user), 60e6);

        // Give liquidator enough USDC to mint xUSD
        mockUSDC.mint(user2, 30e6);

        vm.startPrank(user2);
        mockUSDC.approve(address(vault), 30e6);
        vault.deposit(30e6);
        vault.mintXUSD(20e6);
        vm.stopPrank();

        assertEq(xusd.balanceOf(user2), 20e6);

        uint256 liquidatorBalanceBefore = xusd.balanceOf(user2);
        uint256 liquidatorUSDCBefore = mockUSDC.balanceOf(user2);
        uint256 userSharesBefore = vault.getShareBalance(user);

        // Liquidate 20 xUSD
        vm.prank(user2);
        vault.liquidate(user, 20e6);

        // Liquidator's xUSD was burned
        assertEq(xusd.balanceOf(user2), liquidatorBalanceBefore - 20e6);

        // User's debt decreased from 60 → 40
        assertEq(vault.getxusdMinted(user), 40e6);

        // Liquidator receives 20 + 5% bonus = 21 USDC
        assertEq(mockUSDC.balanceOf(user2), liquidatorUSDCBefore + 21e6);

        // User lost collateral shares
        assertLt(vault.getShareBalance(user), userSharesBefore);
    }

    function test_LiquidateRevertsIfPositionHealthy() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);
        vm.stopPrank();

        mockUSDC.mint(user2, 30e6);

        vm.startPrank(user2);
        mockUSDC.approve(address(vault), 30e6);
        vault.deposit(30e6);
        vault.mintXUSD(20e6);
        vm.stopPrank();

        vm.prank(user2);
        vm.expectRevert(StablecoinVault.SV__PositionHealthy.selector);
        vault.liquidate(user, 20e6);
    }

    function test_LiquidateRevertsIfLiquidationAmountExceedsDebt() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.stopPrank();

        // Make the position unhealthy
        vm.prank(address(vault));
        strategy.simulateLoss(40e6);

        assertTrue(vault.isLiquidatable(user));

        vm.prank(user2);
        vm.expectRevert(StablecoinVault.SV__InsufficientDebt.selector);
        vault.liquidate(user, 61e6);
    }

    function test_ZeroLiquidationAmount() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.stopPrank();

        vm.prank(user2);
        vm.expectRevert(StablecoinVault.SV__MustBeMoreThanZero.selector);
        vault.liquidate(user, 0);
    }

    function test_LiquidateRevertsIfNoDebt() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.stopPrank();

        vm.prank(user2);
        vm.expectRevert(StablecoinVault.SV__PositionHealthy.selector);
        vault.liquidate(user, 20e6);
    }

    function test_LiquidateEmitsEvent() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.stopPrank();

        vm.prank(address(vault));
        strategy.simulateLoss(40e6);

        mockUSDC.mint(user2, 30e6);

        vm.startPrank(user2);
        mockUSDC.approve(address(vault), 30e6);
        vault.deposit(30e6);
        vault.mintXUSD(20e6);
        vm.stopPrank();

        vm.expectEmit(true, true, false, true);
        emit StablecoinVault.Liquidated(user2, user, 20e6, 21e6);

        vm.prank(user2);
        vault.liquidate(user, 20e6);
    }

    function test_LiquidatePartialDebt() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.stopPrank();

        vm.prank(address(vault));
        strategy.simulateLoss(40e6);

        mockUSDC.mint(user2, 30e6);

        vm.startPrank(user2);
        mockUSDC.approve(address(vault), 30e6);
        vault.deposit(30e6);
        vault.mintXUSD(20e6);
        vm.stopPrank();

        uint256 debtBefore = vault.getxusdMinted(user);

        vm.prank(user2);
        vault.liquidate(user, 20e6);

        assertEq(debtBefore, 60e6);
        assertEq(vault.getxusdMinted(user), 40e6);
    }

    function test_LiquidateFullDebt() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.stopPrank();

        // Make the position unhealthy:
        // 100 collateral -> 63 collateral
        vm.prank(address(vault));
        strategy.simulateLoss(37e6);

        assertTrue(vault.isLiquidatable(user));

        // Give liquidator enough USDC to mint 60 xUSD
        mockUSDC.mint(user2, 100e6);

        vm.startPrank(user2);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);
        vm.stopPrank();

        uint256 liquidatorUSDCBefore = mockUSDC.balanceOf(user2);

        console2.log("totalAssets", vault.totalAssets());
        console2.log("totalShares", vault.getTotalShares());
        console2.log("userShares", vault.getShareBalance(user));
        console2.log("userAssets", vault.convertToAssets(vault.getShareBalance(user)));

        vm.prank(user2);
        vault.liquidate(user, 60e6);

        // User's entire debt was repaid
        assertEq(vault.getxusdMinted(user), 0);

        // 60 xUSD debt + 5% bonus = 63 USDC
        assertEq(mockUSDC.balanceOf(user2), liquidatorUSDCBefore + 63e6);

        // User's collateral shares should be completely removed
        assertEq(vault.getShareBalance(user), 0);
    }

    function test_LiquidatePartialDebt2() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.stopPrank();

        // Collateral falls from 100 -> 63 USDC.
        vm.prank(address(vault));
        strategy.simulateLoss(37e6);

        assertTrue(vault.isLiquidatable(user));

        // Liquidator deposits enough collateral to mint 20 xUSD.
        mockUSDC.mint(user2, 100e6);

        vm.startPrank(user2);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(20e6);

        uint256 liquidatorUSDCBefore = mockUSDC.balanceOf(user2);

        vault.liquidate(user, 20e6);

        vm.stopPrank();

        // User's debt should decrease from 60 -> 40 xUSD.
        assertEq(vault.getxusdMinted(user), 40e6);

        // 20 xUSD repaid + 5% liquidation bonus = 21 USDC.
        assertEq(mockUSDC.balanceOf(user2), liquidatorUSDCBefore + 21e6);

        // User should still have collateral/shares remaining.
        assertGt(vault.getShareBalance(user), 0);

        // User should still have a debt position.
        assertGt(vault.getxusdMinted(user), 0);
    }

    function test_LiquidateRevertsIfPositionHealthy2() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.stopPrank();

        vm.startPrank(user2);

        mockUSDC.mint(user2, 100e6);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.expectRevert(StablecoinVault.SV__PositionHealthy.selector);
        vault.liquidate(user, 10e6);

        vm.stopPrank();
    }

    function test_LiquidateRevertsIfDebtToRepayExceedsUserDebt() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.stopPrank();

        // Make the position liquidatable.
        vm.prank(address(vault));
        strategy.simulateLoss(50e6);

        assertTrue(vault.isLiquidatable(user));

        vm.startPrank(user2);

        mockUSDC.mint(user2, 100e6);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.expectRevert(StablecoinVault.SV__InsufficientDebt.selector);
        vault.liquidate(user, 61e6);

        vm.stopPrank();
    }

    function test_LiquidateRevertsIfDebtToRepayIsZero() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.stopPrank();

        vm.prank(address(vault));
        strategy.simulateLoss(50e6);

        assertTrue(vault.isLiquidatable(user));

        vm.startPrank(user2);

        mockUSDC.mint(user2, 100e6);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.expectRevert(StablecoinVault.SV__MustBeMoreThanZero.selector);
        vault.liquidate(user, 0);

        vm.stopPrank();
    }

    function test_LiquidateRevertsIfCollateralIsInsufficient() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.stopPrank();

        // Reduce collateral from 100 → 60.
        vm.prank(address(vault));
        strategy.simulateLoss(40e6);

        assertTrue(vault.isLiquidatable(user));

        vm.startPrank(user2);

        mockUSDC.mint(user2, 100e6);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        // 60 xUSD + 5% liquidation bonus = 63 USDC.
        // User only has 60 USDC of collateral remaining.
        vm.expectRevert(StablecoinVault.SV__InsufficientCollateral.selector);
        vault.liquidate(user, 60e6);

        vm.stopPrank();
    }

    function test_WithdrawRevertsIfAmountExceedsAvailableCollateral() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        vm.expectRevert(StablecoinVault.SV__InsufficientCollateral.selector);
        vault.withdraw(50e6);

        vm.stopPrank();
    }

    function test_WithdrawReducesCollateralAndShares() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.mintXUSD(60e6);

        uint256 balanceBefore = mockUSDC.balanceOf(user);
        uint256 sharesBefore = vault.getShareBalance(user);

        vault.withdraw(40e6);

        assertEq(mockUSDC.balanceOf(user), balanceBefore + 40e6);
        assertEq(vault.getCollateralBalance(user), 60e6);
        assertLt(vault.getShareBalance(user), sharesBefore);
        assertEq(vault.getxusdMinted(user), 60e6);

        vm.stopPrank();
    }

    function test_WithdrawFullCollateralWithNoDebt() public {
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        uint256 balanceBefore = mockUSDC.balanceOf(user);

        vault.withdraw(100e6);

        assertEq(mockUSDC.balanceOf(user), balanceBefore + 100e6);
        assertEq(vault.getCollateralBalance(user), 0);
        assertEq(vault.getShareBalance(user), 0);
        assertEq(vault.getxusdMinted(user), 0);

        vm.stopPrank();
    }

    function test_WithdrawPreservesShareAccounting() public {
        // User deposits first.
        vm.startPrank(user);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.stopPrank();

        // User2 deposits and creates a non-1:1 share price.
        mockUSDC.mint(user2, 100e6);

        vm.startPrank(user2);

        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.stopPrank();

        uint256 userSharesBefore = vault.getShareBalance(user);
        uint256 totalSharesBefore = vault.getTotalShares();
        uint256 totalAssetsBefore = vault.totalAssets();

        uint256 withdrawAmount = 25e6;

        vm.prank(user);
        vault.withdraw(withdrawAmount);

        uint256 userSharesAfter = vault.getShareBalance(user);
        uint256 totalSharesAfter = vault.getTotalShares();
        uint256 totalAssetsAfter = vault.totalAssets();

        // User's shares must decrease.
        assertLt(userSharesAfter, userSharesBefore);

        // Total shares must decrease by the same amount.
        assertEq(
            totalSharesBefore - totalSharesAfter,
            userSharesBefore - userSharesAfter
        );

        // Assets must decrease by the withdrawal amount.
        assertEq(totalAssetsBefore - totalAssetsAfter, withdrawAmount);

        // User should still have collateral remaining.
        assertGt(vault.getCollateralBalance(user), 0);
    }




}
