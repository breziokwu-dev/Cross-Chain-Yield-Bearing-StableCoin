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

    function setUp() public {
        mockUSDC = new MockUSDC();
        xusd = new XUSD();
        vault = new StablecoinVault(address(mockUSDC), address(xusd));
        strategy = new SimpleYieldStrategy(address(mockUSDC), address(vault));

        vault.setStrategy(address(strategy));
        xusd.setVault(address(vault));

        mockUSDC.mint(user, 1_000e6);
    }

    function _deposit(uint256 amount) internal {
        vm.startPrank(user);
        mockUSDC.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();
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

    function test_RedeemAfterYieldReturnsCurrentShareValue() public {
        _deposit(100e6);

        vm.prank(address(vault));
        strategy.simulateYield(50e6);

        uint256 shares = xusd.balanceOf(user);
        uint256 assetsBefore = vault.totalAssets();
        uint256 expectedAssets = vault.convertToAssets(shares);

        vm.prank(user);
        uint256 assetsReceived = vault.redeem(shares);

        assertEq(assetsReceived, expectedAssets);
        assertEq(xusd.balanceOf(user), 0);
        assertEq(vault.totalAssets(), assetsBefore - assetsReceived);
    }

    function test_RedeemAfterYieldBurnsShares() public {
        _deposit(100e6);

        vm.prank(address(vault));
        strategy.simulateYield(100e6);

        uint256 sharesBefore = xusd.balanceOf(user);
        uint256 redeemShares = 1e18;

        vm.prank(user);
        vault.redeem(redeemShares);

        assertEq(xusd.balanceOf(user), sharesBefore - redeemShares);
    }

    function test_RedeemCannotExceedUserShares() public {
        _deposit(100e6);

        uint256 shares = xusd.balanceOf(user);

        vm.prank(user);
        vm.expectRevert(StablecoinVault.SV__InsufficientShares.selector);
        vault.redeem(shares + 1);
    }
}
