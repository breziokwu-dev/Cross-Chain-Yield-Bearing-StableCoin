// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockUSDC} from "../../src/MockUSDC.sol";
import {XUSD} from "../../src/XUSD.sol";
import {StablecoinVault} from "../../src/StablecoinVault.sol";

contract StablecoinVaultTest is Test {
    MockUSDC mockUSDC;
    XUSD xusd;
    StablecoinVault vault;

    address user = makeAddr("user");

    function setUp() public {
        mockUSDC = new MockUSDC();
        xusd = new XUSD();

        vault = new StablecoinVault(
            address(mockUSDC),
            address(xusd)
        );

        xusd.setVault(address(vault));

        mockUSDC.mint(user, 1000e6);
    }

    function test_AddressesAreCorrect() public view {
        assertEq(vault.getMockUSDCAddress(), address(mockUSDC));
        assertEq(vault.getXUSDAddress(), address(xusd));
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
        assertEq(mockUSDC.balanceOf(address(vault)), 100e6);
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
        assertEq(mockUSDC.balanceOf(address(vault)), 300e6);
    }
}