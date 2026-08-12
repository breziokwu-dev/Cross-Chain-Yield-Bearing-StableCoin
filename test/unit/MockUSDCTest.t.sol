// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {MockUSDC} from "../../src/MockUSDC.sol";

contract MockUSDCTest is Test {
    MockUSDC internal mockUSDC;
    address internal constant USER = address(0x1001);
    address internal constant USER2 = address(0x1002);

    function setUp() public {
        mockUSDC = new MockUSDC();
    }

    // Purpose: confirms the mock token starts with no supply, which is the expected initial state for a test-only collateral token.
    function test_InitialTotalSupplyIsZero() public view {
        assertEq(mockUSDC.totalSupply(), 0);
    }

    // Purpose: confirms the mock token uses 6 decimals to match USDC-style stablecoin behavior.
    function test_DecimalsAreSix() public view {
        assertEq(mockUSDC.decimals(), 6);
    }

    // Purpose: confirms mint() gives the recipient the expected token balance without affecting other balances.
    function test_MintIncreasesRecipientBalance() public {
        uint256 amount = 1_000e6;

        mockUSDC.mint(USER, amount);

        assertEq(mockUSDC.balanceOf(USER), amount);
    }

    // Purpose: confirms mint() increases totalSupply by exactly the amount minted.
    function test_MintIncreasesTotalSupply() public {
        uint256 amount = 1_000e6;

        mockUSDC.mint(USER, amount);

        assertEq(mockUSDC.totalSupply(), amount);
    }

    // Purpose: confirms a standard ERC20 transfer moves tokens from the sender to the recipient and updates balances correctly.
    function test_StandardTransferWorks() public {
        uint256 amount = 250e6;
        mockUSDC.mint(USER, amount);

        vm.prank(USER);
        bool success = mockUSDC.transfer(USER2, amount);

        assertTrue(success);
        assertEq(mockUSDC.balanceOf(USER), 0);
        assertEq(mockUSDC.balanceOf(USER2), amount);
    }

    // Purpose: confirms approve() followed by transferFrom() transfers tokens correctly using the allowance mechanism.
    function test_ApproveAndTransferFromWorks() public {
        uint256 amount = 300e6;
        mockUSDC.mint(USER, amount);

        vm.prank(USER);
        mockUSDC.approve(USER2, amount);

        vm.prank(USER2);
        bool success = mockUSDC.transferFrom(USER, USER2, amount);

        assertTrue(success);
        assertEq(mockUSDC.balanceOf(USER), 0);
        assertEq(mockUSDC.balanceOf(USER2), amount);
        assertEq(mockUSDC.allowance(USER, USER2), 0);
    }

    // Purpose: confirms transferFrom() reduces the allowance by the transferred amount, which is the standard ERC20 allowance behavior.
    function test_TransferFromDecreasesAllowance() public {
        uint256 amount = 400e6;
        mockUSDC.mint(USER, amount);

        vm.prank(USER);
        mockUSDC.approve(USER2, amount);

        vm.prank(USER2);
        mockUSDC.transferFrom(USER, USER2, 150e6);

        assertEq(mockUSDC.allowance(USER, USER2), 250e6);
    }
}
