// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {StablecoinVault} from "../../src/StablecoinVault.sol";
import {MockUSDC} from "../../src/MockUSDC.sol";
import {XUSD} from "../../src/XUSD.sol";
import {SimpleYieldStrategy} from "../../src/SimpleYieldStrategy.sol";
import {StablecoinVaultHandler} from "./StablecoinVaultHandler.t.sol";

contract StablecoinVaultInvariantTest is StdInvariant, Test {
    MockUSDC mockUSDC;
    XUSD xusd;
    StablecoinVault vault;
    SimpleYieldStrategy strategy;
    StablecoinVaultHandler handler;

    address user = makeAddr("user");

    function setUp() public {
        mockUSDC = new MockUSDC();
        xusd = new XUSD();
        vault = new StablecoinVault(address(mockUSDC), address(xusd));
        strategy = new SimpleYieldStrategy(address(mockUSDC), address(vault));

        vault.setStrategy(address(strategy));
        xusd.setVault(address(vault));

        mockUSDC.mint(user, 1_000e6);

        handler = new StablecoinVaultHandler(vault, mockUSDC, xusd, strategy);

        targetContract(address(handler));
    }

    function invariant_SharesNeverExceedTotalShares() public view {
        assertLe(vault.getShareBalance(user), vault.getTotalShares());
    }

    function invariant_TotalSharesEqualSumOfUserShares() public view {
        uint256 totalUserShares;

        for (uint256 i = 0; i < handler.usersLength(); i++) {
            totalUserShares += vault.getShareBalance(handler.users(i));
        }

        assertEq(totalUserShares, vault.getTotalShares());
    }

    function invariant_DebtAccountingIsConsistent() public view {
        uint256 totalUserDebt;

        for (uint256 i = 0; i < handler.usersLength(); i++) {
            totalUserDebt += vault.getxusdMinted(handler.users(i));
        }

        assertEq(totalUserDebt, vault.getVaultMintedUSDC());
        assertEq(totalUserDebt, xusd.totalSupply());
    }

    function invariant_DebtNeverExceedsCollateralLimit() public view {
        for (uint256 i = 0; i < handler.usersLength(); i++) {
            address user = handler.users(i);

            uint256 collateralValue = vault.convertToAssets(vault.getShareBalance(user));

            uint256 debt = vault.getxusdMinted(user);

            uint256 maxDebt = (collateralValue * 100) / 150;

            assertLe(debt, maxDebt);
        }
    }

    function invariant_UserClaimValueNeverExceedsTotalAssets() public view {
        uint256 totalUserAssets;

        uint256 userCount = handler.usersLength();

        for (uint256 i = 0; i < userCount; i++) {
            address currentUser = handler.users(i);

            uint256 shares = vault.getShareBalance(currentUser);

            if (shares > 0) {
                totalUserAssets += vault.convertToAssets(shares);
            }
        }

        assertLe(totalUserAssets, vault.totalAssets());
    }

    function invariant_TotalAssetsMatchStrategyValue() public view {
        assertEq(vault.totalAssets(), strategy.totalValue());
    }
}
