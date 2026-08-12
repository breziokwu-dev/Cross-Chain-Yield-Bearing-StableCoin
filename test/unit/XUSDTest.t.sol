// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {XUSD} from "../../src/XUSD.sol";

contract XUSDTest is Test {
    address internal constant VAULT = address(0xBEEF);
    XUSD internal xusd;

    function setUp() public {
        xusd = new XUSD(VAULT);
    }

    function test_VaultAddressIsSet() public view {
        assertEq(xusd.vault(), VAULT);
    }

    function test_OnlyVaultCanMint() public {
        vm.prank(VAULT);
        xusd.mint(address(0x123), 1 ether);

        assertEq(xusd.balanceOf(address(0x123)), 1 ether);
    }

    function test_UnauthorizedMint() public {
        vm.expectRevert(XUSD.XUSD__OnlyVault.selector);
        vm.prank(address(0x123));
        xusd.mint(address(0x456), 1 ether);
    }

    function test_OnlyVaultCanBurn() public {
        vm.prank(VAULT);
        xusd.mint(address(0x123), 1 ether);

        vm.prank(VAULT);
        xusd.burn(address(0x123), 1 ether);

        assertEq(xusd.balanceOf(address(0x123)), 0);
    }

    function test_UnauthorizedBurn() public {
        vm.expectRevert(XUSD.XUSD__OnlyVault.selector);
        vm.prank(address(0x123));
        xusd.burn(address(0x456), 1 ether);
    }

    function test_DecimalsAreEighteen() public view {
        assertEq(xusd.decimals(), 18);
    }

    function test_ZeroAddressVaultReverts() public {
        vm.expectRevert(XUSD.XUSD__ZeroAddressVault.selector);
        new XUSD(address(0));
    }

    function test_MintIncreasesTotalSupply() public {
        uint256 amount = 1 ether;

        vm.prank(VAULT);
        xusd.mint(address(0x123), amount);

        assertEq(xusd.totalSupply(), amount);
    }

    function test_BurnDecreasesTotalSupply() public {
        uint256 amount = 1 ether;

        vm.prank(VAULT);
        xusd.mint(address(0x123), amount);

        vm.prank(VAULT);
        xusd.burn(address(0x123), amount);

        assertEq(xusd.totalSupply(), 0);
    }

    function test_TransferWorks() public {
        uint256 amount = 1 ether;

        vm.prank(VAULT);
        xusd.mint(address(0x123), amount);

        vm.prank(address(0x123));
        bool success = xusd.transfer(address(0x456), amount);

        assertTrue(success);
        assertEq(xusd.balanceOf(address(0x123)), 0);
        assertEq(xusd.balanceOf(address(0x456)), amount);
    }

    function test_ApproveAndTransferFromWorks() public {
        uint256 amount = 1 ether;

        vm.prank(VAULT);
        xusd.mint(address(0x123), amount);

        vm.prank(address(0x123));
        xusd.approve(address(0x456), amount);

        vm.prank(address(0x456));
        bool success = xusd.transferFrom(address(0x123), address(0x789), amount);

        assertTrue(success);
        assertEq(xusd.balanceOf(address(0x123)), 0);
        assertEq(xusd.balanceOf(address(0x789)), amount);
        assertEq(xusd.allowance(address(0x123), address(0x456)), 0);
    }

    function test_TransferFromDecreasesAllowance() public {
        uint256 amount = 1 ether;

        vm.prank(VAULT);
        xusd.mint(address(0x123), amount);

        vm.prank(address(0x123));
        xusd.approve(address(0x456), amount);

        vm.prank(address(0x456));
        xusd.transferFrom(address(0x123), address(0x789), 0.5 ether);

        assertEq(xusd.allowance(address(0x123), address(0x456)), 0.5 ether);
    }
}