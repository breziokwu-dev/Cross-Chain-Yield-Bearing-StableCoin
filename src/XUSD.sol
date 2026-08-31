// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract XUSD is ERC20 {
    address public vault;
    address public immutable deployer;

    mapping(address => bool) public authorizedBridges;

    error XUSD__OnlyDeployer();
    error XUSD__ZeroAddressVault();
    error XUSD__OnlyVaultOrBridge();
    error XUSD__VaultAlreadySet();
    error XUSD__ZeroAddressBridge();

    constructor() ERC20("XUSD", "xUSD") {
        deployer = msg.sender;
    }

    modifier onlyVaultOrBridge() {
        if (msg.sender != vault && !authorizedBridges[msg.sender]) {
            revert XUSD__OnlyVaultOrBridge();
        }
        _;
    }

    modifier onlyDeployer() {
        if (msg.sender != deployer) {
            revert XUSD__OnlyDeployer();
        }
        _;
    }

    function mint(address to, uint256 amount) external onlyVaultOrBridge {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyVaultOrBridge {
        _burn(from, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function setVault(address _vault) external onlyDeployer {
        if (_vault == address(0)) {
            revert XUSD__ZeroAddressVault();
        }

        if (vault != address(0)) {
            revert XUSD__VaultAlreadySet();
        }

        vault = _vault;
    }

    function authorizeBridge(address bridge) external onlyDeployer {
        if (bridge == address(0)) {
            revert XUSD__ZeroAddressBridge();
        }

        authorizedBridges[bridge] = true;
    }

    function revokeBridge(address bridge) external onlyDeployer {
        authorizedBridges[bridge] = false;
    }
}
