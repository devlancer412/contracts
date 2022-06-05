// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {Auth} from "../utils/Auth.sol";
import {IFightBetting} from "./IFightBetting.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IJackPot {
  function mintTo(uint256 amount, address to) external;
}

contract FightBetting is Auth, IFightBetting {
  //
  uint256 public availableBettings;
  address public jackpotAddr;

  Betting[] public bettings;
  BettingState[] public bettingStates;
  SeedData[] private seedData;
  mapping(uint256 => Bettor[]) public bettors;
  uint8[] public luckyWinnerStates;
  mapping(uint256 => mapping(address => bool)) private betted;

  mapping(address => uint256) private tokenAmounts;

  uint256 public minBetNumForJackPot;
  mapping(address => uint256) public betNumber;
  mapping(address => bool) public allowedTokens;

  modifier canBet(uint256 bettingId, uint256 value) {
    require(bettingId < bettings.length, "FightBetting:NOT_CREATED");
    require(block.timestamp >= bettings[bettingId].startTime, "FightBetting:NOT_STARTED_YET");
    require(block.timestamp < bettings[bettingId].endTime, "FightBetting:ALREADY_FINISHED");
    require(value >= bettings[bettingId].minAmount, "FightBetting:TOO_SMALL_AMOUNT");
    require(value <= bettings[bettingId].maxAmount, "FightBetting:TOO_MUCH_AMOUNT");
    require(betted[bettingId][msg.sender] != true, "FightBetting:ALREADY_BET");

    _;
  }

  constructor(address jackpot) {
    jackpotAddr = jackpot;
    minBetNumForJackPot = 1000;
  }

  function createBetting(
    uint256 fighter1,
    uint256 fighter2,
    uint32 startTime,
    uint32 endTime,
    uint256 minAmount,
    uint256 maxAmount,
    address tokenAddr,
    bytes32 hashedServerSeed,
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
        hashedServerSeed,
        sig
      ),
      "FightBetting:INVALID_PARAM"
    );
    require(allowedTokens[tokenAddr], "FightBetting:INVALID_TOKEN");
    require(startTime < endTime, "FightBetting:INVALID_PARAM");
    require(endTime > block.timestamp, "FightBetting:INVALID_PARAM");

    bettings.push(
      Betting(fighter1, fighter2, minAmount, maxAmount, startTime, endTime, msg.sender, tokenAddr)
    );

    bettingStates.push(BettingState(0, 0, 0, 0, BettingLiveState.Alive, Side.Fighter1));
    luckyWinnerStates.push(0);

    seedData.push(SeedData(hashedServerSeed, bytes32(0), bytes32(0)));

    availableBettings++;
    emit NewBetting(fighter1, fighter2, startTime, endTime, tokenAddr);
  }

  function _isCreateParamValid(
    uint256 fighter1,
    uint256 fighter2,
    uint32 startTime,
    uint32 endTime,
    uint256 minAmount,
    uint256 maxAmount,
    address token,
    bytes32 hashedServerSeed,
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
        token,
        hashedServerSeed
      )
    );
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );

    return hasRole("SIGNER", ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s));
  }

  function bettOne(
    uint256 bettingId,
    Side side,
    uint256 value
  ) public canBet(bettingId, value) {
    uint256 fighter;

    bettors[bettingId].push(Bettor(msg.sender, value, side, false));
    betted[bettingId][msg.sender] = true;
    betNumber[msg.sender]++;
    seedData[bettingId].clientSeed = keccak256(
      abi.encodePacked(seedData[bettingId].clientSeed, msg.sender, side == Side.Fighter1)
    );

    if (side == Side.Fighter1) {
      bettingStates[bettingId].totalAmount1 += value;
      bettingStates[bettingId].bettorCount1++;
      fighter = bettings[bettingId].fighter1;
    } else {
      bettingStates[bettingId].totalAmount2 += value;
      bettingStates[bettingId].bettorCount2++;
      fighter = bettings[bettingId].fighter2;
    }

    IERC20(bettings[bettingId].token).transferFrom(msg.sender, address(this), value);

    emit Betted(msg.sender, fighter, value);
  }

  function finishBetting(
    uint256 bettingId,
    bytes32 serverSeed,
    Side result,
    Sig calldata sig
  ) public {
    require(_isFinishParamValid(bettingId, serverSeed, result, sig), "FightBetting:INVALID_PARAM");
    require(block.timestamp > bettings[bettingId].endTime, "FightBetting:TIME_YET");
    require(bettings[bettingId].creator == msg.sender, "FightBetting:PERMISSION_ERROR");
    require(
      keccak256(abi.encodePacked(bool(result == Side.Fighter1), serverSeed)) ==
        seedData[bettingId].hashedServerSeed,
      "FightBtting:INVALID_SEED"
    );

    bettingStates[bettingId].liveState = BettingLiveState.Finished;
    bettingStates[bettingId].side = result;
    seedData[bettingId].serverSeed = serverSeed;
    availableBettings--;
    uint256 winner;

    uint256 fee = (bettingStates[bettingId].totalAmount1 + bettingStates[bettingId].totalAmount2) /
      20;

    tokenAmounts[bettings[bettingId].token] += fee;

    if (bettingStates[bettingId].side == Side.Fighter1) {
      winner = bettings[bettingId].fighter1;
    } else {
      winner = bettings[bettingId].fighter2;
    }

    IERC20(bettings[bettingId].token).transfer(jackpotAddr, fee);

    emit Finished(bettingId, winner);
  }

  function _isFinishParamValid(
    uint256 bettingId,
    bytes32 serverSeed,
    Side result,
    Sig calldata sig
  ) private view returns (bool) {
    bytes32 messageHash = keccak256(
      abi.encodePacked(msg.sender, bettingId, serverSeed, bool(result == Side.Fighter1))
    );
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );

    return hasRole("SIGNER", ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s));
  }

  function getBettingState(uint256 bettingId) public view returns (BettingState memory betting) {
    betting = bettingStates[bettingId];
  }

  function getBettingData(uint256 bettingId) public view returns (Betting memory betting) {
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
      bettingStates[bettingId].totalAmount2) * 88) / 100;
    uint256 betPrice = bettingStates[bettingId].side == Side.Fighter1
      ? bettingStates[bettingId].totalAmount1
      : bettingStates[bettingId].totalAmount2;
    ResultData[] memory results = new ResultData[](totalBettorCount);

    uint256 j = 0;
    for (uint256 i = 0; i < bettors[bettingId].length && j < totalBettorCount; i++) {
      results[j] = ResultData(bettors[bettingId][i].bettor, bettors[bettingId][i].amount, 0);
      if (bettors[bettingId][i].side == bettingStates[bettingId].side) {
        results[j].reward = int256(
          ((totalReward - betPrice) * bettors[bettingId][i].amount) / betPrice
        );
      } else {
        results[j].reward = -1 * int256(bettors[bettingId][i].amount);
      }
      j++;
    }
    return results;
  }

  function getAvailableBettings() public view returns (Betting[] memory) {
    Betting[] memory results = new Betting[](availableBettings);

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
    returns (Betting[] memory)
  {
    Betting[] memory results = new Betting[](number);

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
    returns (Betting[] memory)
  {
    Betting[] memory results = new Betting[](number);

    uint256 j = 0;
    for (uint256 i = from; i >= 0 && j < number; i++) {
      if (bettingStates[i].liveState == BettingLiveState.Alive) {
        results[j] = bettings[i];
        j++;
      }
    }

    return results;
  }

  function withdraw(address token) public onlyOwner {
    uint256 amount = tokenAmounts[token];
    tokenAmounts[token] = 0;
    IERC20(token).transfer(msg.sender, amount);
  }

  function withdrawReward(uint256 bettingId) public {
    require(
      bettingStates[bettingId].liveState == BettingLiveState.Finished,
      "FightBetting:NOT_FINISHED"
    );
    require(betted[bettingId][msg.sender] == true, "FightBetting:DID'T_BET");

    for (uint256 i = 0; i < bettors[bettingId].length; i++) {
      if (bettors[bettingId][i].bettor == msg.sender) {
        require(
          bettors[bettingId][i].side == bettingStates[bettingId].side,
          "FightBetting:DIDN'T_WINNER"
        );
        require(!bettors[bettingId][i].hasWithdrawn, "FightBetting:ALREADY_WITHDRAWED");
        bettors[bettingId][i].hasWithdrawn = true;
        // calculate withdraw amount
        uint256 totalAmount = ((bettingStates[bettingId].totalAmount1 +
          bettingStates[bettingId].totalAmount2) * 88) / 100;

        uint256 winnerAmount = bettingStates[bettingId].side == Side.Fighter1
          ? bettingStates[bettingId].totalAmount1
          : bettingStates[bettingId].totalAmount1;

        uint256 rewardAmount = (totalAmount * bettors[bettingId][i].amount) / winnerAmount;
        IERC20(bettings[bettingId].token).transfer(msg.sender, rewardAmount);

        emit WinnerWithdrawed(bettingId, msg.sender, totalAmount);
        return;
      }
    }
  }

  // For provably.
  function getServerSeedHash(uint256 bettingId) public view returns (bytes32) {
    return seedData[bettingId].hashedServerSeed;
  }

  function getClientSeed(uint256 bettingId) public view returns (bytes32) {
    return seedData[bettingId].clientSeed;
  }

  function getServerSeed(uint256 bettingId) public view returns (bytes32) {
    require(
      bettingStates[bettingId].liveState == BettingLiveState.Finished,
      "FightBetting:NOT_FINISHED"
    );

    return seedData[bettingId].serverSeed;
  }

  function getBettorData(uint256 bettingId, uint256 bettorId) public view returns (Bettor memory) {
    return bettors[bettingId][bettorId];
  }

  function getWinBettorIds(uint256 bettingId) public view returns (uint256[] memory ids) {
    require(
      bettingStates[bettingId].liveState == BettingLiveState.Finished,
      "FightBetting:NOT_FINISHED"
    );

    uint256 total = bettingStates[bettingId].side == Side.Fighter1
      ? bettingStates[bettingId].bettorCount1
      : bettingStates[bettingId].bettorCount2;

    ids = new uint256[](total);

    uint256 j = 0;
    for (uint256 i = 0; j < total && i < bettors[bettingId].length; i++) {
      if (bettors[bettingId][i].side == bettingStates[bettingId].side) {
        ids[j] = i;
        j++;
      }
    }
  }

  function getLuckyWinner(uint256 bettingId)
    public
    view
    returns (address[] memory winners, uint256[] memory rewards)
  {
    require(
      bettingStates[bettingId].liveState == BettingLiveState.Finished,
      "FightBetting:NOT_FINISHED"
    );

    require(betted[bettingId][msg.sender], "FightBetting:DIDNT_BETTED");

    // get bettor data
    Bettor memory bettor;

    for (uint256 i = 0; i < bettors[bettingId].length; i++) {
      if (bettors[bettingId][i].bettor == msg.sender) {
        bettor = bettors[bettingId][i];
        break;
      }
    }

    require(bettingStates[bettingId].side == bettor.side, "FightBetting:LOSS");

    // hash seeds;
    uint256 winnerBettorCount = bettingStates[bettingId].side == Side.Fighter1
      ? bettingStates[bettingId].bettorCount1
      : bettingStates[bettingId].bettorCount2;
    uint256 luckyWinnerRewardAmount = ((bettingStates[bettingId].totalAmount1 +
      bettingStates[bettingId].totalAmount2) * 2) / 100;

    bytes32 hashed = keccak256(
      abi.encodePacked(
        seedData[bettingId].serverSeed,
        seedData[bettingId].clientSeed,
        winnerBettorCount,
        luckyWinnerRewardAmount
      )
    );

    uint256 goldIndex = uint256(hashed) % winnerBettorCount;
    uint256 silverIndex = (goldIndex + 1) % winnerBettorCount;
    uint256 bronzeIndex = (goldIndex + 2) % winnerBettorCount;

    winners = new address[](3);
    rewards = new uint256[](3);
    // gold winner
    winners[0] = bettors[bettingId][goldIndex].bettor;
    rewards[0] = (luckyWinnerRewardAmount * 5) / 8;

    // silver medal
    winners[1] = bettors[bettingId][silverIndex].bettor;
    rewards[1] = luckyWinnerRewardAmount / 4;

    // bronze medal
    winners[2] = bettors[bettingId][bronzeIndex].bettor;
    rewards[2] = luckyWinnerRewardAmount - rewards[0] - rewards[1];
  }

  function withdrawLuckyWinnerReward(uint256 bettingId) public {
    address[] memory winners;
    uint256[] memory rewards;
    (winners, rewards) = getLuckyWinner(bettingId);

    if (winners[0] == msg.sender) {
      require(luckyWinnerStates[bettingId] & 0x01 == 0, "FightBetting:ALREADY_WITHDRAWD");
      luckyWinnerStates[bettingId] += 0x01;
      IERC20(bettings[bettingId].token).transfer(msg.sender, rewards[0]);
    }

    if (winners[1] == msg.sender) {
      require(luckyWinnerStates[bettingId] & 0x02 == 0, "FightBetting:ALREADY_WITHDRAWD");
      luckyWinnerStates[bettingId] += 0x02;
      IERC20(bettings[bettingId].token).transfer(msg.sender, rewards[1]);
    }

    if (winners[2] == msg.sender) {
      require(luckyWinnerStates[bettingId] & 0x04 == 0, "FightBetting:ALREADY_WITHDRAWD");
      luckyWinnerStates[bettingId] += 0x04;
      IERC20(bettings[bettingId].token).transfer(msg.sender, rewards[2]);
    }
  }

  // JackPot
  function setJackPot(address jackpot) public onlyOwner {
    jackpotAddr = jackpot;
  }

  function canGetJackPotNFT() public view returns (uint256 amount) {
    amount = betNumber[msg.sender] / minBetNumForJackPot;
  }

  function getJackPotNFT() public returns (uint256 amount) {
    amount = canGetJackPotNFT();
    require(amount > 0, "FightBetting:NOT_ENOUGH");

    betNumber[msg.sender] -= minBetNumForJackPot * amount;
    IJackPot(jackpotAddr).mintTo(amount, msg.sender);
  }

  function setJackPotMin(uint256 min) public onlyOwner {
    minBetNumForJackPot = min;
  }

  function setTokenAllowance(address token, bool value) public onlyOwner {
    allowedTokens[token] = value;
  }
}
