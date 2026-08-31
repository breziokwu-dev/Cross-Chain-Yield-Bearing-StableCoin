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

    // ---------------------------------------------------------------
    // Yield / share accounting
    // ---------------------------------------------------------------

    function test_Yield_IncreasesTotalAssetsAndShareValue() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vm.stopPrank();

        uint256 userShares = vault.getShareBalance(user);
        assertEq(userShares, 100e6);
        assertEq(vault.convertToAssets(userShares), 100e6);

        vm.prank(address(vault));
        strategy.simulateYield(20e6);

        assertEq(vault.totalAssets(), 120e6);
        assertEq(strategy.totalValue(), 120e6);
        assertEq(vault.convertToAssets(userShares), 120e6);
        assertEq(vault.getShareBalance(user), userShares);
    }

    function test_Yield_IsSharedProportionallyBetweenUsers() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vm.stopPrank();

        vm.prank(address(vault));
        strategy.simulateYield(20e6);

        vm.startPrank(user2);
        mockUSDC.mint(user2, 1000e6);
        mockUSDC.approve(address(vault), 60e6);
        vault.deposit(60e6);
        vm.stopPrank();

        uint256 userShares = vault.getShareBalance(user);
        uint256 user2Shares = vault.getShareBalance(user2);

        assertEq(vault.getTotalShares(), userShares + user2Shares);
        assertEq(vault.totalAssets(), 180e6);
        assertEq(vault.convertToAssets(userShares), 120e6);
        assertEq(vault.convertToAssets(user2Shares), 60e6);
    }

    function test_Yield_DoesNotChangeUserDebt() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 150e6);
        vault.deposit(150e6);
        vault.mintXUSD(100e6);
        vm.stopPrank();

        uint256 debtBefore = vault.getxusdMinted(user);
        uint256 healthBefore = vault.healthFactor(user);

        vm.prank(address(vault));
        strategy.simulateYield(30e6);

        assertEq(vault.getxusdMinted(user), debtBefore);
        assertGt(vault.healthFactor(user), healthBefore);
        assertEq(vault.totalAssets(), 180e6);
    }

    // ---------------------------------------------------------------
    // Minting
    // ---------------------------------------------------------------

    function test_MintXUSD() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 150e6);
        vault.deposit(150e6);
        vault.mintXUSD(100e6);
        vm.stopPrank();

        assertEq(xusd.balanceOf(user), 100e6);
        assertEq(vault.getxusdMinted(user), 100e6);
        assertEq(vault.getVaultMintedUSDC(), 100e6);
    }

    function test_MintXUSD_RevertsIfZeroAmount() public {
        vm.expectRevert(StablecoinVault.SV__MustBeMoreThanZero.selector);
        vm.prank(user);
        vault.mintXUSD(0);
    }

    function test_MintXUSD_RevertsIfInsufficientCollateral() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 100e6);
        vault.deposit(100e6);

        vm.expectRevert(StablecoinVault.SV__InsufficientCollateral.selector);
        vault.mintXUSD(100e6);

        vm.stopPrank();
    }

    function test_MintXUSD_EmitsMintedEvent() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 150e6);
        vault.deposit(150e6);

        vm.expectEmit(true, true, false, true);
        emit StablecoinVault.Minted(user, 100e6);

        vault.mintXUSD(100e6);
        vm.stopPrank();
    }

    function test_MintXUSD_AtExactMaximum() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 150e6);
        vault.deposit(150e6);
        vault.mintXUSD(100e6);
        vm.stopPrank();

        assertEq(xusd.balanceOf(user), 100e6);
        assertEq(vault.getxusdMinted(user), 100e6);
    }

    function test_MintXUSD_AdditionalMintWithinLimit() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 150e6);
        vault.deposit(150e6);
        vault.mintXUSD(50e6);
        vault.mintXUSD(50e6);
        vm.stopPrank();

        assertEq(xusd.balanceOf(user), 100e6);
        assertEq(vault.getxusdMinted(user), 100e6);
    }

    function test_BurnXUSD() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 150e6);
        vault.deposit(150e6);
        vault.mintXUSD(100e6);
        vault.burnXUSD(40e6);
        vm.stopPrank();

        assertEq(xusd.balanceOf(user), 60e6);
        assertEq(vault.getxusdMinted(user), 60e6);
        assertEq(vault.getVaultMintedUSDC(), 60e6);
    }

    function test_BurnXUSD_RevertsIfInsufficientMinted() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 150e6);
        vault.deposit(150e6);
        vault.mintXUSD(50e6);

        vm.expectRevert(StablecoinVault.SV__InsufficientXUSDMinted.selector);
        vault.burnXUSD(60e6);

        vm.stopPrank();
    }

    // ---------------------------------------------------------------
    // Health factor / liquidation
    // ---------------------------------------------------------------

    function test_HealthFactor() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 150e6);
        vault.deposit(150e6);
        vault.mintXUSD(100e6);
        vm.stopPrank();

        assertEq(vault.healthFactor(user), 150);
        assertFalse(vault.isLiquidatable(user));
    }

    function test_HealthFactor_ImprovesWithYield() public {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), 150e6);
        vault.deposit(150e6);
        vault.mintXUSD(100e6);
        vm.stopPrank();

        vm.prank(address(vault));
        strategy.simulateYield(50e6);

        assertEq(vault.healthFactor(user), 200);
        assertFalse(vault.isLiquidatable(user));
    }
}
