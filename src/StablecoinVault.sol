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

    mapping(address user => uint256 collateral) internal collateralBalance;
    mapping(address user => uint256 amount) internal xusdMinted;
    mapping(address user => uint256 shares) internal shareBalance;
    uint256 internal vaultCollateralBalance;
    uint256 internal vaultMintedUSDC;
    uint256 internal totalShares;

    error SV__MustBeMoreThanZero();
    error SV__TransferNotSuccessful();
    error SV__ZeroAddressMockUSDC();
    error SV__ZeroAddressXUSD();
    error SV__OnlyDeployer();
    error SV__NoCollateralDeposited();
    error SV__InsufficientCollateral();
    error SV__ZeroAddressStrategy();
    error SV__StrategyAlreadySet();
    error SV__InsufficientXUSDMinted();

    event Deposit(address sender, uint256 amount);
    event Withdraw(address sender, uint256 amount);
    event Minted(address sender, uint256 amount);
    event Burned(address sender, uint256 amount);

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

    function deposit(uint256 amount) external moreThanZero(amount) {
        uint256 shares;
        if (totalShares == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / totalAssets();
        }
        bool transferred = mockUSDC.transferFrom(msg.sender, address(this), amount);
        if (!transferred) {
            revert SV__TransferNotSuccessful();
        }
        collateralBalance[msg.sender] += amount;
        vaultCollateralBalance += amount;
        shareBalance[msg.sender] += shares;
        totalShares += shares;
        mockUSDC.approve(address(strategy), amount);
        strategy.deposit(amount);
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external moreThanZero(amount) {
        if (collateralBalance[msg.sender] == 0) {
            revert SV__NoCollateralDeposited();
        }
        if (collateralBalance[msg.sender] < amount) {
            revert SV__InsufficientCollateral();
        }
        if (xusdMinted[msg.sender] + amount > collateralBalance[msg.sender]) {
            revert SV__InsufficientCollateral();
        }
        strategy.withdraw(amount);
        bool transfered = mockUSDC.transfer(msg.sender, amount);
        if (!transfered) {
            revert SV__TransferNotSuccessful();
        }
        collateralBalance[msg.sender] -= amount;
        vaultCollateralBalance -= amount;

        emit Withdraw(msg.sender, amount);
    }

    function mintXUSD(uint256 amount) external moreThanZero(amount) {
        if (xusdMinted[msg.sender] + amount > collateralBalance[msg.sender]) {
            revert SV__InsufficientCollateral();
        }
        xusdMinted[msg.sender] += amount;
        vaultMintedUSDC += amount;
        xusd.mint(msg.sender, amount);
        emit Minted(msg.sender, amount);
    }

    function burnXUSD(uint256 amount) external moreThanZero(amount) {
        if (xusdMinted[msg.sender] < amount) {
            revert SV__InsufficientXUSDMinted();
        }
        xusd.burn(msg.sender, amount);
        xusdMinted[msg.sender] -= amount;
        vaultMintedUSDC -= amount;
        emit Burned(msg.sender, amount);
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

    function getShareBalance(address user) external view returns (uint256) {
        return shareBalance[user];
    }

    function getTotalShares() external view returns (uint256) {
        return totalShares;
    }

    function totalAssets() public view returns (uint256) {
        return strategy.totalValue();
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
