// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockUSDC} from "../../src/MockUSDC.sol";
import {XUSD} from "../../src/XUSD.sol";
import {StablecoinVault} from "../../src/StablecoinVault.sol";
import {SimpleYieldStrategy} from "../../src/SimpleYieldStrategy.sol";

contract StablecoinVaultAccountingAuditTest is Test {
    MockUSDC mockUSDC;
    XUSD xusd;
    StablecoinVault vault;
    SimpleYieldStrategy strategy;

    address user = makeAddr("user");
    address liquidator = makeAddr("liquidator");

    function setUp() public {
        mockUSDC = new MockUSDC();
        xusd = new XUSD();
        vault = new StablecoinVault(address(mockUSDC), address(xusd));
        strategy = new SimpleYieldStrategy(address(mockUSDC), address(vault));

        vault.setStrategy(address(strategy));
        xusd.setVault(address(vault));

        mockUSDC.mint(user, 1_000e6);
        mockUSDC.mint(liquidator, 1_000e6);
    }

    function _deposit(uint256 amount) internal {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();
    }

    function test_WithdrawAfterYieldBurnsShares() public {
        _deposit(100e6);

        // Strategy yield is intentionally callable only by the vault. In the
        // audit test we impersonate the vault to exercise the strategy's mock.
        vm.prank(address(vault));
        strategy.simulateYield(100e6);

        uint256 sharesBefore = vault.getShareBalance(user);
        uint256 assetsBefore = vault.totalAssets();

        vm.prank(user);
        vault.withdraw(1);

        assertLt(vault.getShareBalance(user), sharesBefore);
        assertEq(vault.totalAssets(), assetsBefore - 1);
    }

    function test_DepositRevertsWhenRoundingWouldMintZeroShares() public {
        _deposit(100e6);

        vm.prank(address(vault));
        strategy.simulateYield(1_000_000_000e6);

        vm.startPrank(user);
        mockUSDC.approve(address(vault), 1);

        vm.expectRevert(StablecoinVault.SV__InsufficientShares.selector);
        vault.deposit(1);

        vm.stopPrank();
    }

    function test_LiquidationPreservesResidualYieldClaim() public {
        _deposit(100e6);

        vm.prank(address(vault));
        strategy.simulateYield(50e6);

        vm.prank(user);
        vault.mintXUSD(100e6);

        // Reduce collateral from 150 to 109. Debt is 100, so HF is 109 < 110.
        vm.prank(address(vault));
        strategy.simulateLoss(41e6);

        xusd.transfer(liquidator, 100e6);

        vm.prank(liquidator);
        vault.liquidate(user, 100e6);

        assertEq(vault.getxusdMinted(user), 0);
        assertGt(vault.getShareBalance(user), 0);
        assertEq(vault.totalAssets(), 4e6);
        assertEq(vault.getCollateralBalance(user), 4e6);

        // The remaining 4 USDC claim must still be redeemable.
        vm.prank(user);
        vault.withdraw(4e6);

        assertEq(vault.getShareBalance(user), 0);
        assertEq(vault.getCollateralBalance(user), 0);
        assertEq(vault.totalAssets(), 0);
    }

    function test_WithdrawalCannotExceedCurrentShareValue() public {
        _deposit(100e6);

        vm.prank(address(vault));
        strategy.simulateYield(50e6);

        vm.prank(user);
        vm.expectRevert(StablecoinVault.SV__InsufficientCollateral.selector);
        vault.withdraw(151e6);
    }
}
