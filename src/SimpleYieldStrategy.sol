// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockUSDC} from "./MockUSDC.sol";

contract SimpleYieldStrategy {
    MockUSDC internal immutable mockUSDC;
    address internal immutable vault;

    uint256 internal depositedValue;
    uint256 internal accruedYield;

    error SYS__ZeroAddressMockUSDC();
    error SYS__ZeroAmount();
    error SYS__NotLive();
    error SYS__OnlyVault();
    error SYS__ZeroAddressVault();
    error SYS__TransferNotSuccessful();
    error SYS__GreaterThanDepositedValue();
    error SYS__GreaterThanTotalValue();
    error SYS__WithdrawNotSuccessful();

    bool internal live;

    event Deposit(uint256 amount, uint256 depositedValue);
    event Withdraw(uint256 amount, uint256 totalValue);
    event YieldSimulated(uint256 amount, uint256 accruedYield);
    event LossSimulated(uint256 amount, uint256 remainingValue);

    constructor(address _mockUSDC, address _vault) {
        if (_mockUSDC == address(0)) {
            revert SYS__ZeroAddressMockUSDC();
        }
        if (_vault == address(0)) {
            revert SYS__ZeroAddressVault();
        }
        mockUSDC = MockUSDC(_mockUSDC);
        vault = _vault;
        live = true;
    }

    modifier onlyVault() {
        if (msg.sender != vault) {
            revert SYS__OnlyVault();
        }
        _;
    }

    function totalValue() public view returns (uint256) {
        return depositedValue + accruedYield;
    }

    function deposit(uint256 amount) external onlyVault {
        if (amount == 0) {
            revert SYS__ZeroAmount();
        }
        if (!live) {
            revert SYS__NotLive();
        }
        bool transferred = mockUSDC.transferFrom(vault, address(this), amount);
        if (!transferred) {
            revert SYS__TransferNotSuccessful();
        }
        depositedValue += amount;
        emit Deposit(amount, depositedValue);
    }

    function withdraw(uint256 amount) external onlyVault {
        if (amount == 0) {
            revert SYS__ZeroAmount();
        }
        if (amount > totalValue()) {
            revert SYS__GreaterThanTotalValue();
        }
        if (!live) {
            revert SYS__NotLive();
        }

        bool withdrawn = mockUSDC.transfer(vault, amount);
        if (!withdrawn) {
            revert SYS__WithdrawNotSuccessful();
        }

        // Withdrawals consume accrued yield first, then deposited principal.
        // This keeps the accounting value equal to the strategy's token balance.
        if (amount <= accruedYield) {
            accruedYield -= amount;
        } else {
            depositedValue -= amount - accruedYield;
            accruedYield = 0;
        }

        emit Withdraw(amount, totalValue());
    }

    function simulateYield(uint256 amount) external onlyVault {
        if (amount == 0) {
            revert SYS__ZeroAmount();
        }
        if (!live) {
            revert SYS__NotLive();
        }

        // The mock yield is represented by actual mock USDC so totalValue()
        // remains consistent with the strategy's ERC20 balance.
        mockUSDC.mint(address(this), amount);
        accruedYield += amount;
        emit YieldSimulated(amount, accruedYield);
    }

    function simulateLoss(uint256 amount) external onlyVault {
        if (amount == 0) {
            revert SYS__ZeroAmount();
        }
        if (amount > totalValue()) {
            revert SYS__GreaterThanTotalValue();
        }
        if (!live) {
            revert SYS__NotLive();
        }

        mockUSDC.burn(address(this), amount);

        if (amount <= accruedYield) {
            accruedYield -= amount;
        } else {
            depositedValue -= amount - accruedYield;
            accruedYield = 0;
        }

        emit LossSimulated(amount, totalValue());
    }

    function getMockUSDCAddress() external view returns (address) {
        return address(mockUSDC);
    }

    function getVaultAddress() external view returns (address) {
        return vault;
    }

    function setLive(bool _live) external onlyVault {
        live = _live;
    }
}
