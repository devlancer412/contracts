// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {Auth} from "../utils/Auth.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "hardhat/console.sol";

interface IJackPot {
  function mintTo(uint256 amount, address to) external;
}

interface IFightLiveBetting {
  enum BettingLiveState {
    Alive,
    Finished
  }

  enum Side {
    Fighter1,
    Fighter2
  }
  //
  struct Betting {
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
    Side which; // who has winned
  }

  struct Bettor {
    address bettor; // Address of bettor
    uint256 bettingId; // Id of betting which bettor betted
    uint256 amount; // Deposit amount
    Side which; // What betted
    bool hasWithdrawn; // has withdrawn?
  }

  struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  struct ResultData {
    address bettor;
    uint256 amount;
    int256 reward; // Winner true => fighter1 | false => fighter2
  }

  struct SeedData {
    bytes32 serverSeed;
    bytes32 clientSeed;
    string seedString;
  }

  struct LuckyWinnerWithdrawState {
    bool gold;
    bool silver;
    bool bronze;
  }
}

contract FightBetting is Auth, IFightLiveBetting {
  //
  uint256 public availableBettings;
  address public jackpotAddr;

  Betting[] public bettings;
  BettingState[] public bettingStates;
  SeedData[] private seedData;
  Bettor[] public bettors;
  LuckyWinnerWithdrawState[] public luckyWinnerStates;
  mapping(uint256 => mapping(address => bool)) private betted;

  mapping(address => uint256) private tokenAmounts;

  uint256 public minBetNumForJackPot;
  mapping(address => uint256) public betNumber;
  mapping(address => bool) public tokenVerify;

  // Events
  event NewBetting(
    uint256 fighter1,
    uint256 fighter2,
    uint32 startTime,
    uint32 endTime,
    address token
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
    Side result,
    string memory seedString,
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
        result,
        sig
      ),
      "FightBetting:INVALID_PARAM"
    );
    require(tokenVerify[tokenAddr], "FightBetting:INVALID_TOKEN");

    bettings.push(
      Betting(fighter1, fighter2, minAmount, maxAmount, startTime, endTime, msg.sender, tokenAddr)
    );

    bettingStates.push(BettingState(0, 0, 0, 0, 0, BettingLiveState.Alive, Side.Fighter1));
    luckyWinnerStates.push(LuckyWinnerWithdrawState(false, false, false));

    bytes32 serverSeed = keccak256(abi.encodePacked(result, seedString));
    seedData.push(SeedData(serverSeed, bytes32(0), seedString));

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
    Side result,
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
        bool(result == Side.Fighter1)
      )
    );
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );

    return hasRole("SIGNER", ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s));
  }

  function bettOne(
    uint256 bettingId,
    Side which,
    uint256 value
  ) public canBet(bettingId, value) {
    uint256 fighter;

    bettors.push(Bettor(msg.sender, bettingId, value, which, false));
    betted[bettingId][msg.sender] = true;
    betNumber[msg.sender]++;
    seedData[bettingId].clientSeed = keccak256(
      abi.encodePacked(seedData[bettingId].clientSeed, msg.sender, which == Side.Fighter1)
    );

    if (which == Side.Fighter1) {
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

    IERC20(bettings[bettingId].token).transferFrom(msg.sender, address(this), value);

    emit Betted(msg.sender, fighter, value);
  }

  function finishBetting(
    uint256 bettingId,
    Side result,
    Sig calldata sig
  ) public {
    require(_isFinishParamValid(bettingId, result, sig), "FightBetting:INVALID_PARAM");
    require(block.timestamp > bettings[bettingId].endTime, "FightBetting:TIME_YET");
    require(bettings[bettingId].creator == msg.sender, "FightBetting:PERMISSION_ERROR");
    require(
      keccak256(abi.encodePacked(result, seedData[bettingId].seedString)) ==
        seedData[bettingId].serverSeed,
      "FightBtting:INVALID_SEED"
    );

    bettingStates[bettingId].liveState = BettingLiveState.Finished;
    bettingStates[bettingId].which = result;
    availableBettings--;
    uint256 winner;

    uint256 fee = (bettingStates[bettingId].totalAmount1 + bettingStates[bettingId].totalAmount2) /
      20;

    tokenAmounts[bettings[bettingId].token] += fee;

    if (bettingStates[bettingId].which == Side.Fighter1) {
      winner = bettings[bettingId].fighter1;
    } else {
      winner = bettings[bettingId].fighter2;
    }

    IERC20(bettings[bettingId].token).transfer(jackpotAddr, fee);

    emit Finished(bettingId, winner);
  }

  function _isFinishParamValid(
    uint256 bettingId,
    Side result,
    Sig calldata sig
  ) private view returns (bool) {
    bytes32 messageHash = keccak256(
      abi.encodePacked(msg.sender, bettingId, bool(result == Side.Fighter1))
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
    uint256 betPrice = bettingStates[bettingId].which == Side.Fighter1
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
        if (bettors[i].which == bettingStates[bettingId].which) {
          results[j].reward = int256(((totalReward - betPrice) * bettors[i].amount) / betPrice);
        } else {
          results[j].reward = -1 * int256(bettors[i].amount);
        }
        j++;
      }
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

    for (
      uint256 bettorId = bettingStates[bettingId].firstBettorId;
      bettorId < bettors.length;
      bettorId++
    ) {
      if (bettors[bettorId].bettor == msg.sender) {
        require(
          bettors[bettorId].which == bettingStates[bettingId].which,
          "FightBetting:DIDN'T_WINNER"
        );
        require(!bettors[bettorId].hasWithdrawn, "FightBetting:ALREADY_WITHDRAWED");
        bettors[bettorId].hasWithdrawn = true;
        // calculate withdraw amount
        uint256 totalAmount = ((bettingStates[bettingId].totalAmount1 +
          bettingStates[bettingId].totalAmount2) * 88) / 100;

        uint256 winnerAmount = bettingStates[bettingId].which == Side.Fighter1
          ? bettingStates[bettingId].totalAmount1
          : bettingStates[bettingId].totalAmount1;

        uint256 rewardAmount = (totalAmount * bettors[bettorId].amount) / winnerAmount;
        IERC20(bettings[bettingId].token).transfer(msg.sender, rewardAmount);

        emit WinnerWithdrawed(bettingId, msg.sender, totalAmount);
        return;
      }
    }
  }

  // For provably.
  function getServerSeedHash(uint256 bettingId) public view returns (bytes32) {
    return keccak256(abi.encodePacked(seedData[bettingId].serverSeed, bettingId));
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

  function getWinner(uint256 bettingId) public view returns (Side) {
    require(
      bettingStates[bettingId].liveState == BettingLiveState.Finished,
      "FightBetting:NOT_FINISHED"
    );
    return bettingStates[bettingId].which;
  }

  function getBettorData(uint256 bettorId) public view returns (Bettor memory) {
    return bettors[bettorId];
  }

  function getWinBettorIds(uint256 bettingId) public view returns (uint256[] memory ids) {
    require(
      bettingStates[bettingId].liveState == BettingLiveState.Finished,
      "FightBetting:NOT_FINISHED"
    );

    uint256 total = bettingStates[bettingId].which == Side.Fighter1
      ? bettingStates[bettingId].bettorCount1
      : bettingStates[bettingId].bettorCount2;

    ids = new uint256[](total);

    uint256 j = 0;
    for (uint256 i = bettingStates[bettingId].firstBettorId; j < total && i < bettors.length; i++) {
      if (bettors[i].bettingId == bettingId && bettors[i].which == bettingStates[bettingId].which) {
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

    for (uint256 i = bettingStates[bettingId].firstBettorId; i < bettors.length; i++) {
      if (bettors[i].bettingId == bettingId && bettors[i].bettor == msg.sender) {
        bettor = bettors[i];
        break;
      }
    }

    require(bettingStates[bettingId].which == bettor.which, "FightBetting:LOSS");

    // hash seeds;
    uint256 winnerBettorCount = bettingStates[bettingId].which == Side.Fighter1
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
    bool goldSetted = false;
    uint256 silverIndex = (goldIndex + 1) % winnerBettorCount;
    bool silverSetted = false;
    uint256 bronzeIndex = (goldIndex + 2) % winnerBettorCount;
    bool bronzeSetted = false;

    uint256 j = 0;
    for (
      uint256 i = bettingStates[bettingId].firstBettorId;
      i < bettors.length && j < winnerBettorCount;
      i++
    ) {
      if (bettors[i].bettingId == bettingId && bettors[i].which == bettingStates[bettingId].which) {
        if (j == goldIndex && !goldSetted) {
          goldIndex = i;
          goldSetted = true;
        }
        if (j == silverIndex && !silverSetted) {
          silverIndex = i;
          silverSetted = true;
        }
        if (j == bronzeIndex && !bronzeSetted) {
          bronzeIndex = i;
          bronzeSetted = true;
        }

        if (goldSetted && silverSetted && bronzeSetted) {
          break;
        }
        j++;
      }
    }

    winners = new address[](3);
    rewards = new uint256[](3);
    // gold winner
    winners[0] = bettors[goldIndex].bettor;
    rewards[0] = (luckyWinnerRewardAmount * 5) / 8;

    // silver medal
    winners[1] = bettors[silverIndex].bettor;
    rewards[1] = luckyWinnerRewardAmount / 4;

    // bronze medal
    winners[2] = bettors[bronzeIndex].bettor;
    rewards[2] = luckyWinnerRewardAmount - rewards[0] - rewards[1];
  }

  function withdrawLuckyWinnerReward(uint256 bettingId) public {
    address[] memory winners;
    uint256[] memory rewards;
    (winners, rewards) = getLuckyWinner(bettingId);

    if (winners[0] == msg.sender) {
      require(!luckyWinnerStates[bettingId].gold, "FightBetting:ALREADY_WITHDRAWD");
      luckyWinnerStates[bettingId].gold = true;
      IERC20(bettings[bettingId].token).transfer(msg.sender, rewards[0]);
    }

    if (winners[1] == msg.sender) {
      require(!luckyWinnerStates[bettingId].silver, "FightBetting:ALREADY_WITHDRAWD");
      luckyWinnerStates[bettingId].silver = true;
      IERC20(bettings[bettingId].token).transfer(msg.sender, rewards[1]);
    }

    if (winners[2] == msg.sender) {
      require(!luckyWinnerStates[bettingId].bronze, "FightBetting:ALREADY_WITHDRAWD");
      luckyWinnerStates[bettingId].bronze = true;
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

  function setTokenVerification(address token, bool value) public onlyOwner {
    tokenVerify[token] = value;
  }
}
