// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {Auth} from "../utils/Auth.sol";

contract FightBetting is Auth {
  //
  struct Fight {
    uint256 fighter1;
    uint256 fighter2;
    uint32 startTime;
    uint32 endTime;
  }

  struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  struct ResultData {
    address better;
    uint256 amount;
    uint256 reward;
  }

  //
  Fight public data;
  bool public enabled;
  address public bettingCreator;

  uint256 public totalBetters;
  uint256 public totalPrice1;
  uint256 public totalPrice2;
  uint256 public betterCount1;
  uint256 public betterCount2;
  mapping(uint256 => address) public betters;
  mapping(uint256 => bool) public betWitch;
  mapping(uint256 => uint256) public amounts;

  //
  event NewBetting(uint256 fighter1, uint256 fighter2, uint32 startTime, uint32 endTime);
  event Betted(address indexed from, uint256 fighter, uint256 amount);
  event Finished(uint256 winner, ResultData[] results);

  modifier isFinished() {
    require(!enabled, "FightBetting:NOT_FINISHED");
    _;
  }

  modifier canBet() {
    require(block.timestamp > data.startTime, "FightBetting:NOT_STARTED_YET");
    require(block.timestamp < data.endTime, "FightBetting:ALREADY_FINISHED");
    _;
  }

  constructor(address signer_) {
    _grantRole("SIGNER", signer_);
    enabled = false;
  }

  function createBetting(
    uint256 fighter1,
    uint256 fighter2,
    uint32 startTime,
    uint32 endTime,
    Sig calldata sig
  ) external isFinished {
    require(
      _isParamValid(fighter1, fighter2, startTime, endTime, sig),
      "FightBetting:INVALID_PARAM"
    );

    data = Fight(fighter1, fighter2, startTime, endTime);
    enabled = true;
    totalBetters = 0;
    totalPrice1 = 0;
    totalPrice2 = 0;
    betterCount1 = 0;
    betterCount2 = 0;
    bettingCreator = msg.sender;

    emit NewBetting(fighter1, fighter2, startTime, endTime);
  }

  function _isParamValid(
    uint256 fighter1,
    uint256 fighter2,
    uint32 startTime,
    uint32 endTime,
    Sig calldata sig
  ) private view returns (bool) {
    bytes32 messageHash = keccak256(
      abi.encodePacked(msg.sender, fighter1, fighter2, startTime, endTime)
    );
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );

    return hasRole("SIGNER", ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s));
  }

  function bettOne(bool witch) public payable canBet {
    uint256 fighter;

    betters[totalBetters] = msg.sender;
    betWitch[totalBetters] = witch;
    amounts[totalBetters] = msg.value;

    if (witch) {
      totalPrice1 += msg.value;
      betterCount1++;
      fighter = data.fighter1;
    } else {
      totalPrice2 += msg.value;
      betterCount2++;
      fighter = data.fighter2;
    }

    totalBetters++;
    emit Betted(msg.sender, fighter, msg.value);
  }

  function betState()
    public
    view
    returns (
      uint256 betters1,
      uint256 betAmount1,
      uint256 betters2,
      uint256 betAmount2
    )
  {
    betters1 = betterCount1;
    betAmount1 = totalPrice1;
    betters2 = betterCount2;
    betAmount2 = totalPrice2;
  }

  function finishBetting(bool result) public {
    require(block.timestamp > data.endTime, "FightBetting:TIME_YET");
    require(bettingCreator == msg.sender, "FightBetting:PERMISSION_ERROR");

    enabled = false;

    uint256 totalPrice = ((totalPrice1 + totalPrice2) * 19) / 20; // calculate 95%
    uint256 betPrice;
    uint256 winnerCount = 0;
    uint256 winner;
    ResultData[] memory resultData;

    if (result) {
      winner = data.fighter1;
      betPrice = totalPrice1;
      winnerCount = betterCount1;
    } else {
      winner = data.fighter2;
      betPrice = totalPrice2;
      winnerCount = betterCount2;
    }

    resultData = new ResultData[](winnerCount);

    uint256 j = 0;
    for (uint256 i = 0; i < totalBetters; i++) {
      if (betWitch[i] == result) {
        payable(betters[i]).transfer((totalPrice * amounts[i]) / betPrice);
        resultData[j] = ResultData(
          betters[i],
          amounts[i],
          ((totalPrice - betPrice) * amounts[i]) / betPrice
        );
      }
    }

    emit Finished(winner, resultData);
  }

  function withdraw() public onlyOwner {
    payable(msg.sender).transfer(address(this).balance - totalPrice1 - totalPrice2);
  }
}
