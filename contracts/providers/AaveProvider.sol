// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.6.10;

// Import interface for ERC20 standard
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "../libraries/CoreLibrary.sol";

import "./AbstractProvider.sol";
import "./aave-protocol/IAaveLendingPool.sol";
import "./aave-protocol/ILendingPoolCore.sol";

contract AaveProvider is AbstractProvider("Aave") {
    address private lendingPoolAddress;
    // address private lendingPoolCoreAddress;

    event Deposit(address _reserve, uint256 _amount);

    constructor(address _lendingPoolAddress)
        public
    {
        lendingPoolAddress = _lendingPoolAddress;
        // lendingPoolCoreAddress = _lendingPoolCoreAddress;
    }

    // Deposit money to provider pool
    function deposit(address _reserve, uint256 _amount)
        external
        override
        payable
    {
        return getLendingPool().deposit(_reserve, _amount, 0);
    }

    function withdraw(address _reserve, uint256 _amount) external override {}

    function getReserves() external override returns (address[] memory) {
        return getLendingPool().getReserves();
    }

    function getLendingPool() internal view returns (IAaveLendingPool) {
        return IAaveLendingPool(lendingPoolAddress);
    }

    // function getLendingPoolCore() internal view returns (ILendingPoolCore) {
    //     return ILendingPoolCore(lendingPoolCoreAddress);
    // }

    function getReserveData(address _reserveAddress)
        external
        override
        view
        returns (
            uint256 totalLiquidity,
            uint256 availableLiquidity,
            uint256 totalBorrowsVariable,
            uint256 liquidityRate,
            uint256 variableBorrowRate,
            uint256 utilizationRate,
            uint256 liquidityIndex,
            uint256 variableBorrowIndex,
            address aTokenAddress,
            uint40 lastUpdateTimestamp
        )
    {
        // (
        //     totalLiquidity,
        //     availableLiquidity,
        //     ,
        //     totalBorrowsVariable,
        //     liquidityRate,
        //     variableBorrowRate,
        //     ,
        //     ,
        //     utilizationRate,
        //     liquidityIndex,
        //     variableBorrowIndex,
        //     aTokenAddress,
        //     lastUpdateTimestamp
        // ) = getLendingPool().getReserveData(_reserveAddress);
    }

    function getReserveLiquidityRate(address _reserveAddress)
        external
        override
        view
        returns (uint256 liquidityRate)
    {
        (, , , , liquidityRate, , , , , , , , ) = getLendingPool()
            .getReserveData(_reserveAddress);
    }

    function getReserveBorrowRate(address _reserveAddress)
        external
        override
        view
        returns (uint256 variableBorrowRate)
    {
        (, , , , , variableBorrowRate, , , , , , , ) = getLendingPool()
            .getReserveData(_reserveAddress);
    }
}
