// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StablecoinVault} from "../../src/StablecoinVault.sol";
import {MockUSDC} from "../../src/MockUSDC.sol";
import {XUSD} from "../../src/XUSD.sol";
import {SimpleYieldStrategy} from "../../src/SimpleYieldStrategy.sol";

contract StablecoinVaultEconomicAuditTest is Test {
    MockUSDC internal usdc;
    XUSD internal xusd;
    StablecoinVault internal vault;
    SimpleYieldStrategy internal strategy;

    address internal user = makeAddr("user");
    address internal user2 = makeAddr("user2");
    address internal liquidator = makeAddr("liquidator");

    function setUp() public {
        usdc = new MockUSDC();
        xusd = new XUSD();
        vault = new StablecoinVault(address(usdc), address(xusd));
        strategy = new SimpleYieldStrategy(address(usdc), address(vault));

        vault.setStrategy(address(strategy));
        xusd.setVault(address(vault));

        usdc.mint(user, 10_000e6);
        usdc.mint(user2, 10_000e6);
        usdc.mint(liquidator, 10_000e6);
    }

    function _deposit(address who, uint256 amount) internal {
        vm.startPrank(who);
        usdc.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();
    }

    function test_VaultDebtAccountingMatchesXUSDSupply() public {
        _deposit(user, 1_000e6);
        _deposit(user2, 500e6);

        vm.prank(user);
        vault.mintXUSD(600e6);

        vm.prank(user2);
        vault.mintXUSD(300e6);

        assertEq(vault.getVaultMintedUSDC(), xusd.totalSupply());

        vm.prank(user);
        vault.burnXUSD(100e6);

        assertEq(vault.getVaultMintedUSDC(), xusd.totalSupply());
    }

    function test_DonationDoesNotCreateSharesOrDebt() public {
        _deposit(user, 1_000e6);

        uint256 sharesBefore = vault.getTotalShares();
        uint256 supplyBefore = xusd.totalSupply();

        usdc.mint(address(this), 1_000e6);
        usdc.transfer(address(strategy), 1_000e6);

        assertEq(vault.getTotalShares(), sharesBefore);
        assertEq(xusd.totalSupply(), supplyBefore);
        assertEq(vault.totalAssets(), 2_000e6);
    }

    function test_SmallDepositAfterDonationCannotReceiveZeroShares() public {
        _deposit(user, 1_000e6);

        usdc.mint(address(this), 1_000e6);
        usdc.transfer(address(strategy), 1_000e6);

        assertEq(vault.totalAssets(), 2_000e6);
        assertEq(vault.totalAssets() / vault.getTotalShares(), 2e6);

        uint256 user2BalanceBefore = usdc.balanceOf(user2);
        vm.startPrank(user2);
        usdc.approve(address(vault), 1);
        vm.expectRevert(StablecoinVault.SV__InsufficientShares.selector);
        vault.deposit(1);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user2), user2BalanceBefore);
        assertEq(vault.getShareBalance(user2), 0);
    }

    function test_RepeatedYieldAndLossNeverChangesTotalShareCount() public {
        _deposit(user, 1_000e6);
        _deposit(user2, 1_000e6);

        uint256 sharesBefore = vault.getTotalShares();

        vm.startPrank(address(vault));
        strategy.simulateYield(500e6);
        strategy.simulateLoss(200e6);
        strategy.simulateYield(100e6);
        strategy.simulateLoss(50e6);
        vm.stopPrank();

        assertEq(vault.getTotalShares(), sharesBefore);
        assertEq(
            vault.convertToAssets(vault.getShareBalance(user))
                + vault.convertToAssets(vault.getShareBalance(user2)),
            vault.totalAssets()
        );
    }

    function test_PartialLiquidationKeepsRemainingDebtBackedByRemainingShares() public {
        _deposit(user, 1_000e6);

        vm.prank(user);
        vault.mintXUSD(666e6);

        vm.prank(address(vault));
        strategy.simulateLoss(400e6);

        uint256 debt = vault.getxusdMinted(user);
        assertTrue(vault.isLiquidatable(user));

        xusd.transfer(liquidator, 200e6);
        vm.prank(liquidator);
        vault.liquidate(user, 200e6);

        uint256 remainingDebt = vault.getxusdMinted(user);
        uint256 remainingCollateral = vault.convertToAssets(vault.getShareBalance(user));

        assertEq(remainingDebt, debt - 200e6);
        assertGe(remainingCollateral, remainingDebt);
        assertEq(vault.getVaultMintedUSDC(), xusd.totalSupply());
    }
}
