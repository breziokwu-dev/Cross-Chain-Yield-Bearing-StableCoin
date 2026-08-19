
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {StablecoinVault} from "../../src/StablecoinVault.sol";
import {MockUSDC} from "../../src/MockUSDC.sol";
import {XUSD} from "../../src/XUSD.sol";
import {SimpleYieldStrategy} from "../../src/SimpleYieldStrategy.sol";

contract StablecoinVaultHandler is Test {
    StablecoinVault public vault;
    MockUSDC public mockUSDC;
    XUSD public xusd;
    SimpleYieldStrategy public strategy;

    address[] public users;

    constructor(
        StablecoinVault _vault,
        MockUSDC _mockUSDC,
        XUSD _xusd,
        SimpleYieldStrategy _strategy
    ) {
        vault = _vault;
        mockUSDC = _mockUSDC;
        xusd = _xusd;
        strategy = _strategy;

        users.push(makeAddr("handlerUser1"));
        users.push(makeAddr("handlerUser2"));
        users.push(makeAddr("handlerUser3"));

        for (uint256 i = 0; i < users.length; i++) {
            mockUSDC.mint(users[i], 1_000e6);
        }
    }

    function deposit(uint256 userSeed, uint256 amount) external {
        address user = users[userSeed % users.length];

        amount = bound(amount, 1e6, 100e6);

        vm.startPrank(user);

        mockUSDC.approve(address(vault), amount);

        vault.deposit(amount);

        vm.stopPrank();
    }

    function mintXUSD(uint256 userSeed, uint256 amount) external {
        address user = users[userSeed % users.length];

        uint256 collateralValue = vault.convertToAssets(
            vault.getShareBalance(user)
        );

        uint256 maxMintable = (collateralValue * 100) / 150;
        uint256 currentDebt = vault.getxusdMinted(user);

        if (currentDebt >= maxMintable) {
            return;
        }

        uint256 available = maxMintable - currentDebt;

        amount = bound(amount, 1, available);

        vm.prank(user);
        vault.mintXUSD(amount);
    }

    function burnXUSD(uint256 userSeed, uint256 amount) external {
        address user = users[userSeed % users.length];

        uint256 debt = vault.getxusdMinted(user);

        if (debt == 0) {
            return;
        }

        amount = bound(amount, 1, debt);

        vm.prank(user);
        vault.burnXUSD(amount);
    }

    function withdraw(uint256 userSeed, uint256 amount) external {
        address user = users[userSeed % users.length];

        uint256 shares = vault.getShareBalance(user);

        if (shares == 0) {
            return;
        }

        uint256 collateralValue = vault.convertToAssets(shares);
        uint256 debt = vault.getxusdMinted(user);

        if (collateralValue <= debt) {
            return;
        }

        uint256 available = collateralValue - debt;

        amount = bound(amount, 1, available);

        vm.prank(user);
        vault.withdraw(amount);
    }


    function usersLength() external view returns (uint256) {
        return users.length;
    }



}

