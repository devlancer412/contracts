// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {Auth} from "../utils/Auth.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract FightBetting is Auth {
  enum BettingLiveState {
    Alive,
    Finished
  }

  enum Side {
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
    uint256 totalAmount1; // Total price of first Fighter bettors
    uint256 totalAmount2; // Total price of second Fighter bettors
    uint256 firstBettorId; // First bettor of betting
    BettingLiveState liveState; // Set true after finish betting
    Side witch; // Winner true => fighter1 | false => fighter2
  }

  struct BettorData {
    address bettor; // Address of bettor
    Side witch; // What betted
    uint256 bettingId; // Id of betting witch bettor betted
    uint256 amount; // Deposit amount
    bool withdrawed; // Is withdrawed?
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
  uint256 private availableBettings;

  BettingData[] public bettings;
  BettingState[] public bettingStates;
  BettorData[] public bettors;
  mapping(uint256 => mapping(address => bool)) private betted;

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
  event Finished(uint256 bettingId, uint256 winner);
  event WinnerWithdrawed(uint256 bettingId, address indexed to, uint256 amount);

  modifier canBet(uint256 bettingId, uint256 value) {
    require(bettingId < bettings.length, "FightBetting:NOT_CREATED");
    require(block.timestamp > bettings[bettingId].startTime, "FightBetting:NOT_STARTED_YET");
    require(block.timestamp < bettings[bettingId].endTime, "FightBetting:ALREADY_FINISHED");
    require(value >= bettings[bettingId].minAmount, "FightBetting:TOO_SMALL_AMOUNT");
    require(value <= bettings[bettingId].maxAmount, "FightBetting:TOO_MUCH_AMOUNT");
    require(!betted[bettingId][msg.sender], "FightBetting:ALREADY_BET");

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

    bettingStates.push(BettingState(0, 0, 0, 0, 0, BettingLiveState.Alive, Side.Fighter1));

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

    bettors.push(
      BettorData(msg.sender, witch ? Side.Fighter1 : Side.Fighter2, bettingId, value, false)
    );
    betted[bettingId][msg.sender] = true;

    if (witch) {
      bettingStates[bettingId].totalAmount1 += value;
      bettingStates[bettingId].bettorCount1++;
      fighter = bettings[bettingId].fighter1;
    } else {
      bettingStates[bettingId].totalAmount2 += value;
      bettingStates[bettingId].bettorCount2++;
      fighter = bettings[bettingId].fighter2;
    }

    if (bettingStates[bettingId].totalAmount1 + bettingStates[bettingId].totalAmount2 == 1) {
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
    availableBettings--;
    uint256 winner;

    if (result) {
      winner = bettings[bettingId].fighter1;
      bettingStates[bettingId].witch = Side.Fighter1;
    } else {
      winner = bettings[bettingId].fighter2;
      bettingStates[bettingId].witch = Side.Fighter2;
    }

    emit Finished(bettingId, winner);
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
    uint256 totalReward = ((bettingStates[bettingId].totalAmount1 +
      bettingStates[bettingId].totalAmount2) * 19) / 20;
    uint256 betPrice = bettingStates[bettingId].witch == Side.Fighter1
      ? bettingStates[bettingId].totalAmount1
      : bettingStates[bettingId].totalAmount2;
    ResultData[] memory results = new ResultData[](totalBettorCount);

    uint256 j = 0;
    for (
      uint256 i = bettingStates[bettingId].firstBettorId;
      i < bettors.length && j < totalBettorCount;
      i++
    ) {
      if (bettors[i].bettingId == bettingId) {
        results[j] = ResultData(bettors[i].bettor, bettors[i].amount, 0);
        if (bettors[i].witch == bettingStates[bettingId].witch) {
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

  function currencyOf(address token) private returns (uint256) {
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

  function withdrawReward(uint256 bettingId) public {
    require(
      bettingStates[bettingId].liveState == BettingLiveState.Finished,
      "FightBetting:NOT_FINISHED"
    );
    require(betted[bettingId][msg.sender], "FightBetting:DID'T_BET");

    for (
      uint256 bettorId = bettingStates[bettingId].firstBettorId;
      bettorId < bettors.length;
      bettorId++
    ) {
      if (bettors[bettorId].bettor == msg.sender) {
        require(
          bettors[bettorId].witch == bettingStates[bettingId].witch,
          "FightBetting:DIDN'T_WINNER"
        );
        require(!bettors[bettorId].withdrawed, "FightBetting:ALREADY_WITHDRAWED");
        bettors[bettorId].withdrawed = true;
        // calculate withdraw amount
        uint256 totalAmount = ((bettingStates[bettingId].totalAmount1 +
          bettingStates[bettingId].totalAmount2) * 19) / 20;

        uint256 winnerAmount = bettingStates[bettingId].witch == Side.Fighter1
          ? bettingStates[bettingId].totalAmount1
          : bettingStates[bettingId].totalAmount1;

        uint256 rewardAmount = (totalAmount * bettors[bettorId].amount) / winnerAmount;
        IERC20(bettings[bettingId].token).transfer(msg.sender, rewardAmount);

        emit WinnerWithdrawed(bettingId, msg.sender, totalAmount);
        return;
      }
    }
  }
}
