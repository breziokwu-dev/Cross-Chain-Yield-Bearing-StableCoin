// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {MockUSDC} from "./MockUSDC.sol";
import {XUSD} from "./XUSD.sol";
import {SimpleYieldStrategy} from "./SimpleYieldStrategy.sol";

/// @notice Single-chain v1 vault for mock USDC-backed, yield-bearing xUSD.
/// @dev USDC uses 6 decimals while xUSD uses 18. Share pricing normalizes
///      USDC amounts to 18 decimals before applying the 1e18 exchange rate.
contract StablecoinVault {
    MockUSDC internal immutable mockUSDC;
    XUSD internal immutable xusd;
    SimpleYieldStrategy internal strategy;
    address internal immutable deployer;

    uint256 internal constant RATE_SCALE = 1e18;
    uint256 internal constant ASSET_SCALE = 1e12; // 6-decimal USDC -> 18 decimals

    error SV__MustBeMoreThanZero();
    error SV__TransferNotSuccessful();
    error SV__ZeroAddressMockUSDC();
    error SV__ZeroAddressXUSD();
    error SV__OnlyDeployer();
    error SV__ZeroAddressStrategy();
    error SV__StrategyAlreadySet();
    error SV__InsufficientShares();
    error SV__InsufficientAssets();

    event Deposit(address indexed sender, uint256 assets, uint256 shares);
    event Redeem(address indexed sender, uint256 assets, uint256 shares);

    constructor(address _mockUSDC, address _xusd) {
        if (_mockUSDC == address(0)) revert SV__ZeroAddressMockUSDC();
        if (_xusd == address(0)) revert SV__ZeroAddressXUSD();

        mockUSDC = MockUSDC(_mockUSDC);
        xusd = XUSD(_xusd);
        deployer = msg.sender;
    }

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) revert SV__MustBeMoreThanZero();
        _;
    }

    modifier onlyDeployer() {
        if (msg.sender != deployer) revert SV__OnlyDeployer();
        _;
    }

    /// @notice Deposits USDC and mints xUSD shares at the pre-deposit rate.
    function deposit(uint256 assets) external moreThanZero(assets) returns (uint256 shares) {
        uint256 assetsBefore = totalAssets();
        uint256 supply = xusd.totalSupply();

        // The first deposit starts at 1 xUSD per 1 USDC of economic value.
        shares = supply == 0 ? assets * ASSET_SCALE : (assets * supply) / assetsBefore;
        if (shares == 0) revert SV__InsufficientShares();

        bool transferred = mockUSDC.transferFrom(msg.sender, address(this), assets);
        if (!transferred) revert SV__TransferNotSuccessful();

        mockUSDC.approve(address(strategy), assets);
        strategy.deposit(assets);

        xusd.mint(msg.sender, shares);

        emit Deposit(msg.sender, assets, shares);
    }

    /// @notice Burns xUSD shares and returns their proportional USDC value.
    /// @dev Redemption rounds the returned asset amount down.
    function redeem(uint256 shares) external moreThanZero(shares) returns (uint256 assets) {
        uint256 supply = xusd.totalSupply();
        if (shares > supply || shares > xusd.balanceOf(msg.sender)) {
            revert SV__InsufficientShares();
        }

        uint256 assetsBefore = totalAssets();
        assets = (shares * assetsBefore) / supply;
        if (assets == 0) revert SV__InsufficientAssets();

        xusd.burn(msg.sender, shares);
        strategy.withdraw(assets);

        bool transferred = mockUSDC.transfer(msg.sender, assets);
        if (!transferred) revert SV__TransferNotSuccessful();

        emit Redeem(msg.sender, assets, shares);
    }

    function setStrategy(address _strategy) external onlyDeployer {
        if (_strategy == address(0)) revert SV__ZeroAddressStrategy();
        if (address(strategy) != address(0)) revert SV__StrategyAlreadySet();
        strategy = SimpleYieldStrategy(_strategy);
    }

    /// @notice Current exchange rate, scaled by 1e18.
    /// @dev Both sides are expressed in 18-decimal economic units.
    function exchangeRate() public view returns (uint256) {
        uint256 supply = xusd.totalSupply();
        if (supply == 0) return RATE_SCALE;
        return (totalAssets() * ASSET_SCALE * RATE_SCALE) / supply;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = xusd.totalSupply();
        if (supply == 0) return 0;
        return (shares * totalAssets()) / supply;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = xusd.totalSupply();
        uint256 assets_ = totalAssets();
        if (supply == 0) return assets * ASSET_SCALE;
        if (assets_ == 0) return 0;
        return (assets * supply) / assets_;
    }

    /// @notice Authoritative v1 definition: vault-held collateral + strategy value.
    /// @dev Returned in the collateral asset's native 6-decimal units.
    function totalAssets() public view returns (uint256) {
        return mockUSDC.balanceOf(address(this)) + strategy.totalValue();
    }

    function getTotalShares() external view returns (uint256) {
        return xusd.totalSupply();
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
