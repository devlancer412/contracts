// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {Auth} from "../utils/Auth.sol";
import "hardhat/console.sol";

contract FightBetting is Auth {
  //
  struct BettingData {
    uint256 fighter1; // First Fighter's token id
    uint256 fighter2; // Second Fighter's token id
    uint32 startTime; // Start time of betting
    uint32 endTime; // End time of betting
    uint256 minAmount; // Minimum value of amount
    uint256 maxAmount; // Maximum value of amount
    address creator; // Creator of betting
    uint256 bettorCount1; // Count of bettor who bet first Fighter
    uint256 bettorCount2; // Count of bettor who bet second Fighter
    uint256 totalPrice1; // Total price of first Fighter bettors
    uint256 totalPrice2; // Total price of second Fighter bettors
    uint256 firstBettorId; // First bettor of betting
    bool isFinished; // Set true after finish betting
    bool witch; // Winner true => fighter1 | false => fighter2
  }

  struct BettorData {
    address bettor; // Address of bettor
    uint256 bettingId; // Id of betting witch bettor betted
    bool witch; // What betted
    uint256 amount; // Deposit amount
  }

  struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  struct ResultData {
    address bettor;
    uint256 amount;
    int256 reward;
  }

  //
  uint256 private bettingIndex;
  uint256 private bettorIndex;
  uint256 private availableBettings;

  mapping(uint256 => BettingData) public bettings;
  mapping(uint256 => BettorData) public bettors;
  //
  event NewBetting(uint256 fighter1, uint256 fighter2, uint32 startTime, uint32 endTime);
  event Betted(address indexed from, uint256 fighter, uint256 amount);
  event Finished(uint256 winner, ResultData[] results);

  modifier canBet(uint256 bettingId) {
    require(bettingId < bettingIndex, "FightBetting:NOT_CREATED");
    require(block.timestamp > bettings[bettingId].startTime, "FightBetting:NOT_STARTED_YET");
    require(block.timestamp < bettings[bettingId].endTime, "FightBetting:ALREADY_FINISHED");
    require(msg.value >= bettings[bettingId].minAmount, "FightBetting:TOO_SMALL_AMOUNT");
    require(msg.value <= bettings[bettingId].maxAmount, "FightBetting:TOO_MUCH_AMOUNT");
    _;
  }

  constructor() {
    bettingIndex = 0;
    bettorIndex = 0;
    availableBettings = 0;
  }

  function createBetting(
    uint256 fighter1,
    uint256 fighter2,
    uint32 startTime,
    uint32 endTime,
    uint256 minAmount,
    uint256 maxAmount,
    Sig calldata sig
  ) external {
    require(
      _isParamValid(fighter1, fighter2, startTime, endTime, minAmount, maxAmount, sig),
      "FightBetting:INVALID_PARAM"
    );

    bettings[bettingIndex] = BettingData(
      fighter1,
      fighter2,
      startTime,
      endTime,
      minAmount,
      maxAmount,
      msg.sender,
      0,
      0,
      0,
      0,
      0,
      false,
      false
    );

    bettingIndex++;
    availableBettings++;
    emit NewBetting(fighter1, fighter2, startTime, endTime);
  }

  function _isParamValid(
    uint256 fighter1,
    uint256 fighter2,
    uint32 startTime,
    uint32 endTime,
    uint256 minAmount,
    uint256 maxAmount,
    Sig calldata sig
  ) private view returns (bool) {
    bytes32 messageHash = keccak256(
      abi.encodePacked(msg.sender, fighter1, fighter2, startTime, endTime, minAmount, maxAmount)
    );
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );

    return hasRole("SIGNER", ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s));
  }

  function bettOne(uint256 bettingId, bool witch) public payable canBet(bettingId) {
    uint256 fighter;

    bettors[bettorIndex] = BettorData(msg.sender, bettingId, witch, msg.value);

    if (witch) {
      bettings[bettingId].totalPrice1 += msg.value;
      bettings[bettingId].bettorCount1++;
      fighter = bettings[bettingId].fighter1;
    } else {
      bettings[bettingId].totalPrice2 += msg.value;
      bettings[bettingId].bettorCount2++;
      fighter = bettings[bettingId].fighter2;
    }

    if (bettings[bettingId].totalPrice1 + bettings[bettingId].totalPrice2 == 1) {
      bettings[bettingId].firstBettorId = bettorIndex;
    }

    bettorIndex++;

    emit Betted(msg.sender, fighter, msg.value);
  }

  function finishBetting(uint256 bettingId, bool result) public {
    require(block.timestamp > bettings[bettingId].endTime, "FightBetting:TIME_YET");
    require(bettings[bettingId].creator == msg.sender, "FightBetting:PERMISSION_ERROR");

    bettings[bettingId].isFinished = true;
    bettings[bettingId].witch = result;

    uint256 totalPrice = ((bettings[bettingId].totalPrice1 + bettings[bettingId].totalPrice2) *
      19) / 20; // calculate 95%
    uint256 betPrice;
    uint256 winnerCount = 0;
    uint256 winner;
    uint256 totalBettorCount = bettings[bettingId].bettorCount1 + bettings[bettingId].bettorCount2;
    ResultData[] memory resultData;

    if (result) {
      winner = bettings[bettingId].fighter1;
      betPrice = bettings[bettingId].totalPrice1;
      winnerCount = bettings[bettingId].bettorCount1;
    } else {
      winner = bettings[bettingId].fighter2;
      betPrice = bettings[bettingId].totalPrice2;
      winnerCount = bettings[bettingId].bettorCount2;
    }

    resultData = new ResultData[](winnerCount);

    uint256 j = 0;
    for (
      uint256 i = bettings[bettingId].firstBettorId;
      i < bettorIndex && j < totalBettorCount;
      i++
    ) {
      if (bettors[i].bettingId == bettingId && bettors[i].witch == result) {
        payable(bettors[i].bettor).transfer((totalPrice * bettors[i].amount) / betPrice);
        resultData[j] = ResultData(
          bettors[i].bettor,
          bettors[i].amount,
          int256(((totalPrice - betPrice) * bettors[i].amount) / betPrice)
        );

        j++;
      }
    }

    availableBettings--;

    emit Finished(winner, resultData);
  }

  function bettingState(uint256 bettingId) public view returns (BettingData memory betting) {
    require(!bettings[bettingId].isFinished, "FighterBetting:ALREADY_FINISHED");
    betting = bettings[bettingId];
  }

  function bettingResult(uint256 bettingId) public view returns (ResultData[] memory) {
    require(bettings[bettingId].isFinished, "FighterBetting:NOT_FINISHED");
    uint256 totalBettorCount = bettings[bettingId].bettorCount1 + bettings[bettingId].bettorCount2;
    uint256 totalReward = ((bettings[bettingId].totalPrice1 + bettings[bettingId].totalPrice2) *
      19) / 20;
    uint256 betPrice = bettings[bettingId].witch
      ? bettings[bettingId].totalPrice1
      : bettings[bettingId].totalPrice2;
    ResultData[] memory results = new ResultData[](totalBettorCount);

    uint256 j = 0;
    for (
      uint256 i = bettings[bettingId].firstBettorId;
      i < bettorIndex && j < totalBettorCount;
      i++
    ) {
      if (bettors[i].bettingId == bettingId) {
        results[j] = ResultData(bettors[i].bettor, bettors[i].amount, 0);
        if (bettors[i].witch == bettings[bettingId].witch) {
          results[j].reward = int256(((totalReward - betPrice) * bettors[i].amount) / betPrice);
        } else {
          results[j].reward = -1 * int256(bettors[i].amount);
        }
        j++;
      }
    }
    return results;
  }

  function getAvailableBettings() public view returns (BettingData[] memory) {
    BettingData[] memory results = new BettingData[](availableBettings);

    uint256 j = 0;
    for (uint256 i = bettingIndex - 1; i >= 0 && j < availableBettings; i++) {
      if (!bettings[i].isFinished) {
        results[j] = bettings[i];
        j++;
      }
    }

    return results;
  }

  function getPrevFinishedBets(uint256 from, uint256 number)
    public
    view
    returns (BettingData[] memory)
  {
    BettingData[] memory results = new BettingData[](number);

    uint256 j = 0;
    for (uint256 i = from; i >= 0 && j < number; i--) {
      if (!bettings[i].isFinished) {
        results[j] = bettings[i];
        j++;
      }
    }

    return results;
  }

  function getNextFinishedBets(uint256 from, uint256 number)
    public
    view
    returns (BettingData[] memory)
  {
    BettingData[] memory results = new BettingData[](number);

    uint256 j = 0;
    for (uint256 i = from; i >= 0 && j < number; i++) {
      if (!bettings[i].isFinished) {
        results[j] = bettings[i];
        j++;
      }
    }

    return results;
  }

  function withdraw() public onlyOwner {
    uint256 liveValue = 0;
    uint256 j = 0;

    for (uint256 i = bettingIndex; j < availableBettings && i >= 0; i--) {
      if (!bettings[i].isFinished) {
        liveValue += bettings[i].totalPrice1;
        liveValue += bettings[i].totalPrice2;
        j++;
      }
    }

    payable(msg.sender).transfer(address(this).balance - liveValue);
  }
}
