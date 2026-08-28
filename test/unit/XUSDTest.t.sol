// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {XUSD} from "../../src/XUSD.sol";

contract XUSDTest is Test {
    XUSD xusd;

    address deployer = makeAddr("deployer");
    address user = makeAddr("user");
    address vault = makeAddr("vault");
    address attacker = makeAddr("attacker");
    address bridge = makeAddr("bridge");

    uint256 constant MINT_AMOUNT = 1000 ether;

    function setUp() public {
        vm.prank(deployer);
        xusd = new XUSD();
    }

    // ---------------------------------------------------------------
    // Initial State
    // ---------------------------------------------------------------

    function test_InitialState() public view {
        assertEq(xusd.deployer(), deployer);
        assertEq(xusd.vault(), address(0));
        assertEq(xusd.totalSupply(), 0);
        assertEq(xusd.balanceOf(user), 0);
        assertEq(xusd.decimals(), 18);
    }

    // ---------------------------------------------------------------
    // setVault()
    // ---------------------------------------------------------------

    function test_SetVault_DeployerCanSetVault() public {
        vm.prank(deployer);
        xusd.setVault(vault);

        assertEq(xusd.vault(), vault);
    }

    function test_SetVault_RevertsIfZeroAddress() public {
        vm.prank(deployer);

        vm.expectRevert(XUSD.XUSD__ZeroAddressVault.selector);
        xusd.setVault(address(0));
    }

    function test_SetVault_RevertsIfNotDeployer() public {
        vm.prank(attacker);

        vm.expectRevert(XUSD.XUSD__OnlyDeployer.selector);
        xusd.setVault(vault);
    }

    function test_SetVault_RevertsIfVaultAlreadySet() public {
        vm.startPrank(deployer);

        xusd.setVault(vault);

        vm.expectRevert(XUSD.XUSD__VaultAlreadySet.selector);
        xusd.setVault(address(123));

        vm.stopPrank();

        assertEq(xusd.vault(), vault);
    }

    // ---------------------------------------------------------------
    // mint()
    // ---------------------------------------------------------------

    function test_Mint_RevertsIfCallerIsNotVault() public {
        _setVault();

        vm.prank(attacker);

        vm.expectRevert(XUSD.XUSD__OnlyVaultOrBridge.selector);
        xusd.mint(user, MINT_AMOUNT);
    }

    function test_Mint_VaultCanMint() public {
        _setVault();

        vm.prank(vault);
        xusd.mint(user, MINT_AMOUNT);

        assertEq(xusd.balanceOf(user), MINT_AMOUNT);
        assertEq(xusd.totalSupply(), MINT_AMOUNT);
    }

    function test_Mint_UpdatesTotalSupplyAndBalance() public {
        _setVault();

        uint256 firstMint = 100 ether;
        uint256 secondMint = 250 ether;

        vm.startPrank(vault);

        xusd.mint(user, firstMint);
        xusd.mint(user, secondMint);

        vm.stopPrank();

        assertEq(xusd.balanceOf(user), firstMint + secondMint);
        assertEq(xusd.totalSupply(), firstMint + secondMint);
    }

    function test_Mint_ToDifferentUsers() public {
        _setVault();

        address userTwo = makeAddr("userTwo");

        vm.startPrank(vault);

        xusd.mint(user, 100 ether);
        xusd.mint(userTwo, 200 ether);

        vm.stopPrank();

        assertEq(xusd.balanceOf(user), 100 ether);
        assertEq(xusd.balanceOf(userTwo), 200 ether);
        assertEq(xusd.totalSupply(), 300 ether);
    }

    // ---------------------------------------------------------------
    // burn()
    // ---------------------------------------------------------------

    function test_Burn_RevertsIfCallerIsNotVault() public {
        _setVault();
        _mintToUser(MINT_AMOUNT);

        vm.prank(attacker);

        vm.expectRevert(XUSD.XUSD__OnlyVaultOrBridge.selector);
        xusd.burn(user, 100 ether);
    }

    function test_Burn_VaultCanBurn() public {
        _setVault();
        _mintToUser(MINT_AMOUNT);

        uint256 burnAmount = 400 ether;

        vm.prank(vault);
        xusd.burn(user, burnAmount);

        assertEq(xusd.balanceOf(user), MINT_AMOUNT - burnAmount);
        assertEq(xusd.totalSupply(), MINT_AMOUNT - burnAmount);
    }

    function test_Burn_AllTokens() public {
        _setVault();
        _mintToUser(MINT_AMOUNT);

        vm.prank(vault);
        xusd.burn(user, MINT_AMOUNT);

        assertEq(xusd.balanceOf(user), 0);
        assertEq(xusd.totalSupply(), 0);
    }

    function test_Burn_RevertsIfUserHasInsufficientBalance() public {
        _setVault();
        _mintToUser(100 ether);

        vm.prank(vault);

        vm.expectRevert();
        xusd.burn(user, 101 ether);
    }

    // ---------------------------------------------------------------
    // Standard ERC20 behavior
    // ---------------------------------------------------------------

    function test_Transfer_WorksNormally() public {
        _setVault();
        _mintToUser(MINT_AMOUNT);

        uint256 transferAmount = 300 ether;

        vm.prank(user);
        xusd.transfer(attacker, transferAmount);

        assertEq(xusd.balanceOf(user), MINT_AMOUNT - transferAmount);
        assertEq(xusd.balanceOf(attacker), transferAmount);
    }

    function test_ApproveAndTransferFrom_WorkNormally() public {
        _setVault();
        _mintToUser(MINT_AMOUNT);

        uint256 amount = 500 ether;

        vm.prank(user);
        xusd.approve(attacker, amount);

        assertEq(xusd.allowance(user, attacker), amount);

        vm.prank(attacker);
        xusd.transferFrom(user, attacker, amount);

        assertEq(xusd.balanceOf(user), MINT_AMOUNT - amount);
        assertEq(xusd.balanceOf(attacker), amount);
        assertEq(xusd.allowance(user, attacker), 0);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _setVault() internal {
        vm.prank(deployer);
        xusd.setVault(vault);
    }

    function _mintToUser(uint256 amount) internal {
        vm.prank(vault);
        xusd.mint(user, amount);
    }

    // ---------------------------------------------------------------
    // Bridge Authorization
    // ---------------------------------------------------------------

    function test_AuthorizeBridge_DeployerCanAuthorize() public {
        vm.prank(deployer);
        xusd.authorizeBridge(bridge);

        assertTrue(xusd.authorizedBridges(bridge));
    }

    function test_AuthorizeBridge_RevertsIfNotDeployer() public {
        vm.prank(attacker);

        vm.expectRevert(XUSD.XUSD__OnlyDeployer.selector);
        xusd.authorizeBridge(bridge);
    }

    function test_AuthorizeBridge_RevertsIfZeroAddress() public {
        vm.prank(deployer);

        vm.expectRevert(XUSD.XUSD__ZeroAddressBridge.selector);
        xusd.authorizeBridge(address(0));
    }

    function test_AuthorizedBridgeCanMint() public {
        vm.prank(deployer);
        xusd.authorizeBridge(bridge);

        vm.prank(bridge);
        xusd.mint(user, MINT_AMOUNT);

        assertEq(xusd.balanceOf(user), MINT_AMOUNT);
        assertEq(xusd.totalSupply(), MINT_AMOUNT);
    }

    function test_AuthorizedBridgeCanBurn() public {
        _setVault();
        _mintToUser(MINT_AMOUNT);

        vm.prank(deployer);
        xusd.authorizeBridge(bridge);

        vm.prank(bridge);
        xusd.burn(user, 400 ether);

        assertEq(xusd.balanceOf(user), 600 ether);
        assertEq(xusd.totalSupply(), 600 ether);
    }

    function test_RevokeBridge_PreventsMintAndBurn() public {
        _setVault();
        _mintToUser(MINT_AMOUNT);

        vm.startPrank(deployer);
        xusd.authorizeBridge(bridge);
        xusd.revokeBridge(bridge);
        vm.stopPrank();

        assertFalse(xusd.authorizedBridges(bridge));

        vm.startPrank(bridge);

        vm.expectRevert(XUSD.XUSD__OnlyVaultOrBridge.selector);
        xusd.mint(user, 100 ether);

        vm.expectRevert(XUSD.XUSD__OnlyVaultOrBridge.selector);
        xusd.burn(user, 100 ether);

        vm.stopPrank();
    }
}
