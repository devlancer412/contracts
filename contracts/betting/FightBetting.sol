// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {Auth} from "../utils/Auth.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract FightBetting is Auth {
  enum BettingLiveState {
    Alive,
    Finished
  }

  enum Winner {
    Fighter1,
    Fighter2
  }
  //
  struct BettingData {
    uint256 fighter1; // First Fighter's token id
    uint256 fighter2; // Second Fighter's token id
    uint256 minAmount; // Minimum value of amount
    uint256 maxAmount; // Maximum value of amount
    uint32 startTime; // Start time of betting
    uint32 endTime; // End time of betting
    address creator; // Creator of betting
    address token; // Payable token address
  }

  struct BettingState {
    uint256 bettorCount1; // Count of bettor who bet first Fighter
    uint256 bettorCount2; // Count of bettor who bet second Fighter
    uint256 totalPrice1; // Total price of first Fighter bettors
    uint256 totalPrice2; // Total price of second Fighter bettors
    uint256 firstBettorId; // First bettor of betting
    BettingLiveState liveState; // Set true after finish betting
    Winner witch; // Winner true => fighter1 | false => fighter2
  }

  struct BettorData {
    address bettor; // Address of bettor
    bool witch; // What betted
    uint256 bettingId; // Id of betting witch bettor betted
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

  struct RewardPoolData {
    address to;
    uint32 currencyId;
    uint256 amount;
  }

  //
  uint256 private availableBettings;

  BettingData[] public bettings;
  BettingState[] public bettingStates;
  BettorData[] public bettors;
  RewardPoolData[] public rewards;

  address[] private currencyTokens;
  uint256[] private currencyAmounts;

  // Events
  event NewBetting(
    uint256 fighter1,
    uint256 fighter2,
    uint32 startTime,
    uint32 endTime,
    string tokenName
  );
  event Betted(address indexed from, uint256 fighter, uint256 amount);
  event Finished(uint256 winner, ResultData[] results);

  modifier canBet(uint256 bettingId, uint256 value) {
    require(bettingId < bettings.length, "FightBetting:NOT_CREATED");
    require(block.timestamp > bettings[bettingId].startTime, "FightBetting:NOT_STARTED_YET");
    require(block.timestamp < bettings[bettingId].endTime, "FightBetting:ALREADY_FINISHED");
    require(value >= bettings[bettingId].minAmount, "FightBetting:TOO_SMALL_AMOUNT");
    require(value <= bettings[bettingId].maxAmount, "FightBetting:TOO_MUCH_AMOUNT");
    require(
      IERC20(bettings[bettingId].token).balanceOf(msg.sender) >= value,
      "FightBetting:NOT_ENOUGH"
    );

    bool betted = false;
    if (bettingStates[bettingId].bettorCount1 + bettingStates[bettingId].bettorCount1 != 0) {
      for (uint256 i = bettingStates[bettingId].firstBettorId; i < bettors.length; i++) {
        if (bettors[i].bettor == msg.sender) {
          betted = true;
        }
      }
    }

    require(!betted, "FightBetting:ALREADY_BET");
    _;
  }

  constructor() {}

  function createBetting(
    uint256 fighter1,
    uint256 fighter2,
    uint32 startTime,
    uint32 endTime,
    uint256 minAmount,
    uint256 maxAmount,
    address tokenAddr,
    Sig calldata sig
  ) external {
    require(
      _isCreateParamValid(
        fighter1,
        fighter2,
        startTime,
        endTime,
        minAmount,
        maxAmount,
        tokenAddr,
        sig
      ),
      "FightBetting:INVALID_PARAM"
    );

    bettings.push(
      BettingData(
        fighter1,
        fighter2,
        minAmount,
        maxAmount,
        startTime,
        endTime,
        msg.sender,
        tokenAddr
      )
    );

    bettingStates.push(BettingState(0, 0, 0, 0, 0, BettingLiveState.Alive, Winner.Fighter1));

    availableBettings++;
    emit NewBetting(fighter1, fighter2, startTime, endTime, IERC20Metadata(tokenAddr).symbol());
  }

  function _isCreateParamValid(
    uint256 fighter1,
    uint256 fighter2,
    uint32 startTime,
    uint32 endTime,
    uint256 minAmount,
    uint256 maxAmount,
    address token,
    Sig calldata sig
  ) private view returns (bool) {
    bytes32 messageHash = keccak256(
      abi.encodePacked(
        msg.sender,
        fighter1,
        fighter2,
        startTime,
        endTime,
        minAmount,
        maxAmount,
        token
      )
    );
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );

    return hasRole("SIGNER", ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s));
  }

  function bettOne(
    uint256 bettingId,
    bool witch,
    uint256 value
  ) public canBet(bettingId, value) {
    IERC20(bettings[bettingId].token).transferFrom(msg.sender, address(this), value);
    uint256 fighter;

    bettors.push(BettorData(msg.sender, witch, bettingId, value));

    if (witch) {
      bettingStates[bettingId].totalPrice1 += value;
      bettingStates[bettingId].bettorCount1++;
      fighter = bettings[bettingId].fighter1;
    } else {
      bettingStates[bettingId].totalPrice2 += value;
      bettingStates[bettingId].bettorCount2++;
      fighter = bettings[bettingId].fighter2;
    }

    if (bettingStates[bettingId].totalPrice1 + bettingStates[bettingId].totalPrice2 == 1) {
      bettingStates[bettingId].firstBettorId = bettors.length;
    }

    emit Betted(msg.sender, fighter, value);
  }

  function finishBetting(
    uint256 bettingId,
    bool result,
    Sig calldata sig
  ) public {
    require(_isFinishParamValid(bettingId, result, sig), "FightBetting:INVALID_PARAM");
    require(block.timestamp > bettings[bettingId].endTime, "FightBetting:TIME_YET");
    require(bettings[bettingId].creator == msg.sender, "FightBetting:PERMISSION_ERROR");

    bettingStates[bettingId].liveState = BettingLiveState.Finished;
    bettingStates[bettingId].witch = Winner.Fighter1;
    availableBettings--;

    uint256 totalPrice = ((bettingStates[bettingId].totalPrice1 +
      bettingStates[bettingId].totalPrice2) * 19) / 20; // calculate 95%
    uint256 tokenAmount = getCurrency(bettings[bettingId].token) + totalPrice / 19; // remained 5% to contract
    setCurrency(bettings[bettingId].token, tokenAmount);

    uint256 betPrice;
    uint256 winnerCount = 0;
    uint256 winner;
    uint256 totalBettorCount = bettingStates[bettingId].bettorCount1 +
      bettingStates[bettingId].bettorCount2;
    ResultData[] memory resultData;

    if (result) {
      winner = bettings[bettingId].fighter1;
      betPrice = bettingStates[bettingId].totalPrice1;
      winnerCount = bettingStates[bettingId].bettorCount1;
    } else {
      winner = bettings[bettingId].fighter2;
      betPrice = bettingStates[bettingId].totalPrice2;
      winnerCount = bettingStates[bettingId].bettorCount2;
    }

    resultData = new ResultData[](winnerCount);

    uint256 j = 0;
    for (
      uint256 i = bettingStates[bettingId].firstBettorId;
      i < bettors.length && j < totalBettorCount;
      i++
    ) {
      if (bettors[i].bettingId == bettingId && bettors[i].witch == result) {
        addReward(
          bettors[i].bettor,
          bettings[bettingId].token,
          (totalPrice * bettors[i].amount) / betPrice
        );
        resultData[j] = ResultData(
          bettors[i].bettor,
          bettors[i].amount,
          int256(((totalPrice - betPrice) * bettors[i].amount) / betPrice)
        );

        j++;
      }
    }

    emit Finished(winner, resultData);
  }

  function _isFinishParamValid(
    uint256 bettingId,
    bool result,
    Sig calldata sig
  ) private view returns (bool) {
    bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, bettingId, result));
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );

    return hasRole("SIGNER", ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s));
  }

  function getBettingState(uint256 bettingId) public view returns (BettingState memory betting) {
    require(
      bettingStates[bettingId].liveState == BettingLiveState.Alive,
      "FighterBetting:ALREADY_FINISHED"
    );
    betting = bettingStates[bettingId];
  }

  function getBettingData(uint256 bettingId) public view returns (BettingData memory betting) {
    require(
      bettingStates[bettingId].liveState == BettingLiveState.Alive,
      "FighterBetting:ALREADY_FINISHED"
    );
    betting = bettings[bettingId];
  }

  function bettingResult(uint256 bettingId) public view returns (ResultData[] memory) {
    require(
      bettingStates[bettingId].liveState == BettingLiveState.Finished,
      "FighterBetting:NOT_FINISHED"
    );
    uint256 totalBettorCount = bettingStates[bettingId].bettorCount1 +
      bettingStates[bettingId].bettorCount2;
    uint256 totalReward = ((bettingStates[bettingId].totalPrice1 +
      bettingStates[bettingId].totalPrice2) * 19) / 20;
    uint256 betPrice = bettingStates[bettingId].witch == Winner.Fighter1
      ? bettingStates[bettingId].totalPrice1
      : bettingStates[bettingId].totalPrice2;
    ResultData[] memory results = new ResultData[](totalBettorCount);

    uint256 j = 0;
    for (
      uint256 i = bettingStates[bettingId].firstBettorId;
      i < bettors.length && j < totalBettorCount;
      i++
    ) {
      if (bettors[i].bettingId == bettingId) {
        results[j] = ResultData(bettors[i].bettor, bettors[i].amount, 0);
        if (bettors[i].witch == (bettingStates[bettingId].witch == Winner.Fighter1)) {
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
    for (uint256 i = bettings.length - 1; i >= 0 && j < availableBettings; i++) {
      if (bettingStates[i].liveState == BettingLiveState.Alive) {
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
      if (bettingStates[i].liveState == BettingLiveState.Alive) {
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
      if (bettingStates[i].liveState == BettingLiveState.Alive) {
        results[j] = bettings[i];
        j++;
      }
    }

    return results;
  }

  function getCurrency(address token) private returns (uint256) {
    int32 currency = -1;
    for (uint32 i = 0; i < currencyTokens.length; i++) {
      if (currencyTokens[i] == token) {
        currency = int32(i);
        break;
      }
    }

    if (currency > 0) {
      return currencyAmounts[uint32(currency)];
    }

    currencyTokens.push(token);
    currencyAmounts.push(0);
    return 0;
  }

  function setCurrency(address token, uint256 value) private {
    int32 currency = -1;
    for (uint32 i = 0; i < currencyTokens.length; i++) {
      if (currencyTokens[i] == token) {
        currency = int32(i);
        break;
      }
    }

    if (currency > 0) {
      currencyAmounts[uint32(currency)] = value;
    } else {
      currencyTokens.push(token);
      currencyAmounts.push(value);
    }
  }

  function withdraw() public onlyOwner {
    uint256 amount;
    for (uint256 i = 0; i < currencyTokens.length; i++) {
      amount = currencyAmounts[i];
      currencyAmounts[i] = 0;
      IERC20(currencyTokens[i]).transfer(msg.sender, amount);
    }
  }

  function addReward(
    address to,
    address token,
    uint256 amount
  ) private {
    int32 currency = -1;
    for (uint32 i = 0; i < currencyTokens.length; i++) {
      if (currencyTokens[i] == token) {
        currency = int32(i);
        break;
      }
    }

    if (currency < 0) {
      currency = int32(uint32(currencyTokens.length));
      currencyTokens.push(token);
      currencyAmounts.push(0);
    }

    for (uint256 i = 0; i < rewards.length; i++) {
      if (rewards[i].to == to && rewards[i].currencyId == uint32(currency)) {
        rewards[i].amount += amount;
        return;
      }
    }

    rewards.push(RewardPoolData(to, uint32(currency), amount));
  }

  function withdrawReward() public {
    uint256 amount;
    for (uint256 i = 0; i < rewards.length; i++) {
      if (rewards[i].to == msg.sender) {
        amount = rewards[i].amount;
        rewards[i].amount = 0;
        IERC20(currencyTokens[rewards[i].currencyId]).transfer(rewards[i].to, amount);
      }
    }
  }
}
