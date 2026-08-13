// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {MockUSDC} from "./MockUSDC.sol";
import {XUSD} from "./XUSD.sol";

contract StablecoinVault {
    MockUSDC internal mockUSDC;
    XUSD internal xusd;

    mapping(address sender => uint256 collateral) internal collateralBalance;
    uint256 internal vaultCollateralBalance;

    error SV__MustBeMoreThanZero();
    error SV__TransferNotSuccessful();
    error SV__ZeroAddressMockUSDC();
    error SV__ZeroAddressXUSD();

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
    }

    modifier moreThanZero(uint256 amount) {
        if(amount == 0){
            revert SV__MustBeMoreThanZero();
        }
        _;        
    }

    function totalAssets() public view returns(uint256) {
        return vaultCollateralBalance;
    }

    function deposit(uint256 amount) external moreThanZero(amount) {
        bool transfered = mockUSDC.transferFrom(msg.sender, address(this), amount);
        if(!transfered){
            revert SV__TransferNotSuccessful();
        }
        collateralBalance[msg.sender] += amount;
        vaultCollateralBalance += amount;
        emit Deposit(msg.sender, amount);
    }
}