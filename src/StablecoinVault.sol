// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {MockUSDC} from "./MockUSDC.sol";
import {XUSD} from "./XUSD.sol";
import {SimpleYieldStrategy} from "./SimpleYieldStrategy.sol";

contract StablecoinVault {
    MockUSDC internal mockUSDC;
    XUSD internal xusd;
    SimpleYieldStrategy internal strategy;
    address internal deployer;

    mapping(address sender => uint256 collateral) internal collateralBalance;
    uint256 internal vaultCollateralBalance;

    error SV__MustBeMoreThanZero();
    error SV__TransferNotSuccessful();
    error SV__ZeroAddressMockUSDC();
    error SV__ZeroAddressXUSD();
    error SV__ZeroAddressStrategy();
    error SV__OnlyDeployer();
    error SV__StrategyAlreadySet();

    event Deposit(address sender, uint256 amount);

    constructor(address _mockUSDC, address _xusd) {
        if (_mockUSDC == address(0)) {
            revert SV__ZeroAddressMockUSDC();
        }
        if (_xusd == address(0)) {
            revert SV__ZeroAddressXUSD();
        }
        mockUSDC = MockUSDC(_mockUSDC);
        xusd = XUSD(_xusd);
        deployer = msg.sender;
    }

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert SV__MustBeMoreThanZero();
        }
        _;
    }

    modifier onlyDeployer() {
        if (msg.sender != deployer) {
            revert SV__OnlyDeployer();
        }
        _;
    }

    function totalAssets() public view returns (uint256) {
        return strategy.totalValue();
    }

    function deposit(uint256 amount) external moreThanZero(amount) {
        bool transfered = mockUSDC.transferFrom(msg.sender, address(this), amount);
        if (!transfered) {
            revert SV__TransferNotSuccessful();
        }
        collateralBalance[msg.sender] += amount;
        vaultCollateralBalance += amount;
        mockUSDC.approve(address(strategy), amount);
        strategy.deposit(amount);
        emit Deposit(msg.sender, amount);
    }

    function setStrategy(address _strategy) external onlyDeployer {
        if (_strategy == address(0)) {
            revert SV__ZeroAddressStrategy();
        }
        if (address(strategy) != address(0)) {
            revert SV__StrategyAlreadySet();
        }
        strategy = SimpleYieldStrategy(_strategy);
    }

    function getCollateralBalance(address user) external view returns (uint256) {
        return collateralBalance[user];
    }

    function getMockUSDCAddress() external view returns (address) {
        return address(mockUSDC);
    }

    function getXUSDAddress() external view returns (address) {
        return address(xusd);
    }

    function getStrategyAddress() external view returns (address) {
        return address(strategy);
    }
}
