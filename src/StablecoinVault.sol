// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {MockUSDC} from "./MockUSDC.sol";
import {XUSD} from "./XUSD.sol";
import {SimpleYieldStrategy} from "./SimpleYieldStrategy.sol";
import {console2} from "forge-std/console2.sol";

contract StablecoinVault {
    MockUSDC internal mockUSDC;
    XUSD internal xusd;
    SimpleYieldStrategy internal strategy;
    address internal deployer;
    uint256 internal constant COLLATERALIZATION_RATIO = 150;
    uint256 internal constant LIQUIDATION_THRESHOLD = 110;
    uint256 internal constant LIQUIDATION_BONUS = 5;

    mapping(address user => uint256 collateral) internal collateralBalance;
    mapping(address user => uint256 amount) internal xusdMinted;
    mapping(address user => uint256 shares) internal shareBalance;
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
    error SV__PositionHealthy();
    error SV__InsufficientDebt();
    error SV__InsufficientLiquidationAmount();

    event Deposit(address sender, uint256 amount);
    event Withdraw(address sender, uint256 amount);
    event Minted(address sender, uint256 amount);
    event Burned(address sender, uint256 amount);
    event Liquidated(address indexed liquidator, address indexed user, uint256 debtRepaid, uint256 collateralSeized);

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
        shareBalance[msg.sender] += shares;
        totalShares += shares;
        mockUSDC.approve(address(strategy), amount);
        strategy.deposit(amount);
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external moreThanZero(amount) {
        uint256 collateralValue = convertToAssets(shareBalance[msg.sender]);

        console2.log("collateralBalance", collateralBalance[msg.sender]);
        console2.log("collateralValue", collateralValue);
        console2.log("xusdMinted", xusdMinted[msg.sender]);
        console2.log("withdrawAmount", amount);
        console2.log("availableCollateral", collateralValue - xusdMinted[msg.sender]);

        if (collateralBalance[msg.sender] == 0) {
            revert SV__NoCollateralDeposited();
        }
        if (collateralBalance[msg.sender] < amount) {
            revert SV__InsufficientCollateral();
        }
        if (xusdMinted[msg.sender] >= collateralValue) {
            revert SV__InsufficientCollateral();
        }
        uint256 requiredCollateral = (xusdMinted[msg.sender] * COLLATERALIZATION_RATIO + 99) / 100;
        if (collateralValue - amount < requiredCollateral) {
            revert SV__InsufficientCollateral();
        }
        uint256 sharesToBurn = (amount * totalShares) / totalAssets();
        strategy.withdraw(amount);
        bool transfered = mockUSDC.transfer(msg.sender, amount);
        if (!transfered) {
            revert SV__TransferNotSuccessful();
        }
        collateralBalance[msg.sender] -= amount;
        shareBalance[msg.sender] -= sharesToBurn;
        totalShares -= sharesToBurn;

        emit Withdraw(msg.sender, amount);
    }

    function mintXUSD(uint256 amount) external moreThanZero(amount) {
        uint256 collateralValue = convertToAssets(shareBalance[msg.sender]);

        uint256 maxMintable = (collateralValue * 100) / COLLATERALIZATION_RATIO;

        if (xusdMinted[msg.sender] >= maxMintable) {
            revert SV__InsufficientCollateral();
        }

        uint256 availableToMint = maxMintable - xusdMinted[msg.sender];

        if (amount > availableToMint) {
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

    function liquidate(address user, uint256 debtToRepay) external moreThanZero(debtToRepay) {
        if (!isLiquidatable(user)) {
            revert SV__PositionHealthy();
        }

        if (debtToRepay > xusdMinted[user]) {
            revert SV__InsufficientDebt();
        }

        uint256 collateralToSeize = (debtToRepay * (100 + LIQUIDATION_BONUS)) / 100;

        uint256 userShares = shareBalance[user];

        uint256 userCollateralValue = convertToAssets(userShares);

        uint256 sharesToSeize = (collateralToSeize * userShares) / userCollateralValue;

        if (sharesToSeize > userShares) {
            revert SV__InsufficientCollateral();
        }

        // Burn the liquidator's xUSD
        xusd.burn(msg.sender, debtToRepay);

        // Reduce the user's debt
        xusdMinted[user] -= debtToRepay;
        vaultMintedUSDC -= debtToRepay;

        // Withdraw the seized collateral from the strategy
        strategy.withdraw(collateralToSeize);

        // Transfer collateral to liquidator
        bool transferred = mockUSDC.transfer(msg.sender, collateralToSeize);

        if (!transferred) {
            revert SV__TransferNotSuccessful();
        }

        // Remove seized shares from the user's position
        shareBalance[user] -= sharesToSeize;
        totalShares -= sharesToSeize;

        collateralBalance[user] -= collateralToSeize;

        emit Liquidated(msg.sender, user, debtToRepay, collateralToSeize);
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

    function convertToAssets(uint256 shares) public view returns (uint256) {
        if (totalShares == 0) {
            return 0;
        }

        return (shares * totalAssets()) / totalShares;
    }

    function healthFactor(address user) public view returns (uint256) {
        uint256 collateralValue = convertToAssets(shareBalance[user]);
        uint256 debt = xusdMinted[user];

        if (debt == 0) {
            return type(uint256).max;
        }

        return (collateralValue * 100) / debt;
    }

    function isLiquidatable(address user) public view returns (bool) {
        uint256 debt = xusdMinted[user];

        if (debt == 0) {
            return false;
        }

        return healthFactor(user) < LIQUIDATION_THRESHOLD;
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

    function getVaultMintedUSDC() external view returns (uint256) {
        return vaultMintedUSDC;
    }

    function totalAssets() public view returns (uint256) {
        return strategy.totalValue();
    }

    function getxusdMinted(address user) external view returns (uint256) {
        return xusdMinted[user];
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
