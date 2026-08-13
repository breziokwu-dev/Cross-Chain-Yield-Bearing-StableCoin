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
    }
}