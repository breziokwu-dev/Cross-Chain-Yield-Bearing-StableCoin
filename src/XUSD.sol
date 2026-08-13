// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract XUSD is ERC20 {
    address public vault;
    address public immutable deployer;
    
    error XUSD__OnlyDeployer();
    error XUSD__ZeroAddressVault();
    error XUSD__OnlyVault();
    error XUSD__VaultAlreadySet();

    constructor() ERC20("XUSD", "xUSD") {
        deployer = msg.sender;
    }

    modifier onlyVault() {
        if (msg.sender != vault) {
            revert XUSD__OnlyVault();
        }
        _;
    }

    modifier onlyDeployer() {
        if (msg.sender != deployer) {
            revert XUSD__OnlyDeployer();
        }
        _;
    }

    function mint(address to, uint256 amount) external onlyVault {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyVault {
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
}