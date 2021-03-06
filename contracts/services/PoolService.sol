// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.6.10;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

import "../core/ILendingProvider.sol";
import "../lib/AddressStorage.sol";
import "../lib/SafeERC20.sol";
import "../lib/ERC20.sol";
import "../lib/EthAddressLib.sol";
import "../lib/WadRayMath.sol";
import "../repositories/ReserveRepository.sol";
import "../repositories/UserBalanceRepository.sol";
import "../core/IPriceRepository.sol";
import "../services/ProviderService.sol";
import "../services/RiskService.sol";
import "../token/VToken.sol";

/**
 * @title PoolService
 * @notice Core service
 * @author Mikhail Lazarev, github.com/MikaelLazarev
 */

contract PoolService is Ownable {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;
  using WadRayMath for uint256;

  AddressRepository private addressRepository;
  ProviderService internal providerService;
  ProviderRepository internal providerRepository;
  ReserveRepository private reserveRepository;
  UserBalanceRepository private userBalanceRepository;
  IPriceRepository private priceRepository;
  RiskService private riskService;

  /**
   * @dev emitted during a redeem action.
   * @param _reserve the address of the reserve
   * @param _user the address of the user
   * @param _amount the amount to be deposited
   * @param _timestamp the timestamp of the action
   **/
  event RedeemUnderlying(
    address indexed _reserve,
    address indexed _user,
    uint256 _amount,
    uint256 _timestamp
  );

  constructor(address _addressRepository) public {
    addressRepository = AddressRepository(_addressRepository);
    providerService = ProviderService(addressRepository.getProviderService());
    providerRepository = ProviderRepository(
      addressRepository.getProviderRepository()
    );

    reserveRepository = ReserveRepository(
      addressRepository.getReserveRepository()
    );

    userBalanceRepository = UserBalanceRepository(
      addressRepository.getUserBalanceRepository()
    );

    priceRepository = IPriceRepository(addressRepository.getPriceRepository());
    riskService = RiskService(addressRepository.getRiskService());
  }

  modifier activeReserveOnly(address _reserve) {
    require(
      reserveRepository.isReserveActive(_reserve),
      "Pool: Reserve is not active"
    );
    _;
  }

  /**
   * @dev functions affected by this modifier can only be invoked if the provided _amount input parameter
   * is not zero.
   * @param _amount the amount provided
   **/
  modifier onlyAmountGreaterThanZero(uint256 _amount) {
    requireAmountGreaterThanZeroInternal(_amount);
    _;
  }

  function deposit(address _reserve, uint256 _amount)
    external
    payable
    activeReserveOnly(_reserve)
    onlyAmountGreaterThanZero(_amount)
  {
    address providerAddress = providerService
      .getProviderWithHighestLiquidityRate(_reserve);

    ILendingProvider provider = ILendingProvider(providerAddress);

    // Transfer tokens to Pool contract and provide allowance
    transferToReserve(_reserve, msg.sender, providerAddress, _amount);

    // Approve for provider
    provider.deposit(_reserve, _amount);
    reserveRepository.addLiquidity(_reserve, _amount);
    userBalanceRepository.increaseUserDeposit(_reserve, msg.sender, _amount);

    VToken token = VToken(reserveRepository.getVTokenContract(_reserve));
    token.mintOnDeposit(msg.sender, _amount);
  }

  // Add Secutiry modifirie for Vitamin tokens only
  function redeemUnderlying(
    address _reserve,
    address payable _user,
    uint256 _amount
  ) external activeReserveOnly(_reserve) onlyAmountGreaterThanZero(_amount) {
    _transferValueToUser(_reserve, _user, _amount);

    userBalanceRepository.decreaseUserDeposit(_reserve, _user, _amount);

    emit RedeemUnderlying(_reserve, _user, _amount, uint40(block.timestamp));
  }

  function borrow(address _reserve, uint256 _amount)
    external
    activeReserveOnly(_reserve)
    onlyAmountGreaterThanZero(_amount)
  {
    require(
      _amount <= providerService.getTotalAvaibleLiquidity(_reserve),
      "PoolService: Not enough liquidity available"
    );

    uint256 reservePrice = priceRepository.getReservePriceInETH(_reserve);
    uint256 maxAmount = riskService.getMaxAllowedLoanETH(msg.sender).div(
      reservePrice
    );

    require(_amount < maxAmount, "Poolservice: you have not enough collateral");

    _transferValueToUser(_reserve, msg.sender, _amount);
    userBalanceRepository.increaseUserBorrow(_reserve, msg.sender, _amount);

    // emit Borrow(_reserve, _user, _amount, uint40(block.timestamp));
  }

  function repay(address _reserve, uint256 _amount) external payable {}

  function _transferValueToUser(
    address _reserve,
    address payable _user,
    uint256 _amount
  ) internal {
    require(
      providerService.getTotalAvaibleLiquidity(_reserve) > _amount,
      "Pool: There is not enough liquidity available to redeem"
    );

    // ToDo: Add check that msg.sender has enough tokens!

    uint256 _amountLeft = _amount;
    while (_amountLeft > 0) {
      (address providerAddress, uint256 avaibleLiquidity) = providerService
        .getProviderWithLowestLiquidityRate(_reserve);

      // Calculate max sum we could take from this provider
      uint256 sumToRedeem = _amountLeft < avaibleLiquidity
        ? _amountLeft
        : avaibleLiquidity;
      ILendingProvider provider = ILendingProvider(providerAddress);

      // Redeem this sum
      provider.redeemUnderlying(_reserve, _user, sumToRedeem);

      // ToDo: substract tokens(!)
      _amountLeft = _amountLeft.sub(sumToRedeem);
    }

    uint256 updatedTotalLiquidity = reserveRepository
      .getTotalLiquidity(_reserve)
      .sub(_amount);
    uint256 updatedAvailableLiquidity = reserveRepository
      .getAvailableLiquidity(_reserve)
      .sub(_amount);

    reserveRepository.setTotalLiquidity(_reserve, updatedTotalLiquidity);
    reserveRepository.setAvailableLiquidity(
      _reserve,
      updatedAvailableLiquidity
    );
  }

  /**
   * @notice internal function to save on code size for the onlyAmountGreaterThanZero modifier
   **/
  function requireAmountGreaterThanZeroInternal(uint256 _amount) internal pure {
    require(_amount > 0, "Pool: Amount must be greater than 0");
  }

  /**
   * @dev transfers an amount from a user to the destination reserve
   * @param _reserve the address of the reserve where the amount is being transferred
   * @param _user the address of the user from where the transfer is happening
   * @param _amount the amount being transferred
   **/
  function transferToReserve(
    address _reserve,
    address payable _user,
    address _to,
    uint256 _amount
  ) internal {
//    if (_reserve != EthAddressLib.ethAddress()) {
//      require(
//        msg.value == 0,
//        "Pool: User is sending ETH along with the ERC20 transfer."
//      );

      ERC20(_reserve).safeTransferFrom(_user, _to, _amount);
//    } else {
//      require(
//        msg.value >= _amount,
//        "Pool: The amount and the value sent to deposit do not match"
//      );
//
//      if (msg.value > _amount) {
//        //send back excess ETH
//        uint256 excessAmount = msg.value.sub(_amount);
//        //solium-disable-next-line
//        (bool result, ) = _user.call.value(excessAmount).gas(50000)("");
//        require(result, "Pool: Transfer of ETH failed");
//      }
//    }
  }

  function getReserveInfo(address _reserve)
    external
    view
    returns (
      string memory symbol,
      uint256 totalLiquidity,
      uint256 availableLiquidity,
      uint256 loanToValue,
      uint256 liquidationThreshold,
      uint256 liquidationBonus,
      uint256 borrowRate,
      uint256 lendingRate,
      address vTokenContract,
      bool isActive
    )
  {
    symbol = reserveRepository.getReserveSymbol(_reserve);
    totalLiquidity = reserveRepository.getTotalLiquidity(_reserve);
    availableLiquidity = reserveRepository.getAvailableLiquidity(_reserve);
    loanToValue = reserveRepository.getLoanToValue(_reserve);
    liquidationThreshold = reserveRepository.getLiquidationThreshold(_reserve);
    liquidationBonus = reserveRepository.getLiquidationBonus(_reserve);
    vTokenContract = address(reserveRepository.getVTokenContract(_reserve));
    (lendingRate, borrowRate) = providerService.getBestRates(_reserve);
    isActive = reserveRepository.isActive(_reserve);
  }
}
