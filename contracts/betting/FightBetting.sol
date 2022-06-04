// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {Auth} from "../utils/Auth.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IJackPot {
  function mintTo(uint256 amount, address to) external;
}

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
    Side which; // Winner true => fighter1 | false => fighter2
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
    int256 reward;
  }

  struct ClientSeedData {
    address user;
    bytes32 seed;
  }

  struct LuckyWinnerWithdrawState {
    bool gold;
    bool silver;
    bool bronze;
  }
  //
  uint256 public availableBettings;
  address public jackpotAddr;

  Betting[] public bettings;
  BettingState[] public bettingStates;
  Bettor[] public bettors;
  LuckyWinnerWithdrawState[] public luckyWinnerStates;
  mapping(uint256 => mapping(address => bool)) private betted;

  address[] private currencyTokens;
  uint256[] private currencyAmounts;

  uint256 public minBetNumForJackPot;
  mapping(address => uint256) public betNumber;

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
      Betting(fighter1, fighter2, minAmount, maxAmount, startTime, endTime, msg.sender, tokenAddr)
    );

    bettingStates.push(BettingState(0, 0, 0, 0, 0, BettingLiveState.Alive, Side.Fighter1));
    luckyWinnerStates.push(LuckyWinnerWithdrawState(false, false, false));

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
    Side which,
    uint256 value
  ) public canBet(bettingId, value) {
    uint256 fighter;

    bettors.push(Bettor(msg.sender, bettingId, value, which, false));
    betted[bettingId][msg.sender] = true;
    betNumber[msg.sender]++;

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
    bool result,
    Sig calldata sig
  ) public {
    require(_isFinishParamValid(bettingId, result, sig), "FightBetting:INVALID_PARAM");
    require(block.timestamp > bettings[bettingId].endTime, "FightBetting:TIME_YET");
    require(bettings[bettingId].creator == msg.sender, "FightBetting:PERMISSION_ERROR");

    bettingStates[bettingId].liveState = BettingLiveState.Finished;
    availableBettings--;
    uint256 winner;

    uint256 fee = (bettingStates[bettingId].totalAmount1 + bettingStates[bettingId].totalAmount2) /
      20;

    setCurrency(bettings[bettingId].token, getCurrency(bettings[bettingId].token) + fee);

    if (result) {
      winner = bettings[bettingId].fighter1;
      bettingStates[bettingId].which = Side.Fighter1;
    } else {
      winner = bettings[bettingId].fighter2;
      bettingStates[bettingId].which = Side.Fighter2;
    }
    IERC20(bettings[bettingId].token).transfer(jackpotAddr, fee);

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

  function getCurrency(address token) private view returns (uint256) {
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
  function getSeeds(uint256 bettingId, bool which)
    public
    view
    returns (bytes32 serverSeed, ClientSeedData[] memory clientSeeds)
  {
    // calculate server seed
    serverSeed = keccak256(
      abi.encodePacked(
        bettings[bettingId].fighter1,
        bettings[bettingId].fighter2,
        bettings[bettingId].minAmount,
        bettings[bettingId].maxAmount,
        bettings[bettingId].startTime,
        bettings[bettingId].endTime,
        bettings[bettingId].creator,
        bettings[bettingId].token
      )
    );
    // get client's betting seeds
    uint256 count = which
      ? bettingStates[bettingId].bettorCount1
      : bettingStates[bettingId].bettorCount2;

    clientSeeds = new ClientSeedData[](count);

    uint256 j = 0;
    for (uint256 i = bettingStates[bettingId].firstBettorId; j < count && i < bettors.length; i++) {
      if ((bettors[i].which == Side.Fighter1) == which && bettors[i].bettingId == bettingId) {
        clientSeeds[j] = ClientSeedData(
          bettors[i].bettor,
          keccak256(
            abi.encodePacked(bettors[i].bettor, bettingId, bettors[i].which, bettors[i].which)
          )
        );
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

    // get seeds
    bytes32 serverSeed;
    ClientSeedData[] memory clientSeeds;

    (serverSeed, clientSeeds) = getSeeds(bettingId, bettor.which == Side.Fighter1);

    // hash client seeds;
    for (uint256 i = 0; i < clientSeeds.length; i++) {
      clientSeeds[i].seed = keccak256(
        abi.encodePacked(
          serverSeed,
          clientSeeds[i].seed,
          clientSeeds[i].user,
          bettingStates[bettingId].bettorCount1 + bettingStates[bettingId].bettorCount2,
          bettingStates[bettingId].totalAmount1 + bettingStates[bettingId].totalAmount2,
          bool(bettingStates[bettingId].which == Side.Fighter1)
        )
      );
    }

    // rearrange client seeds
    for (uint256 i = 0; i < clientSeeds.length; i++) {
      for (uint256 j = i + 1; j < clientSeeds.length; j++) {
        if (uint256(clientSeeds[i].seed) < uint256(clientSeeds[j].seed)) {
          (clientSeeds[i], clientSeeds[j]) = (clientSeeds[j], clientSeeds[i]);
        }
      }
    }

    // getting winners
    uint256 serverNumber = uint256(serverSeed);
    uint256 luckyWinnerRewardAmount = (bettingStates[bettingId].totalAmount1 +
      bettingStates[bettingId].totalAmount2) -
      (((bettingStates[bettingId].totalAmount1 + bettingStates[bettingId].totalAmount2) * 88) / // reward amount
        100) -
      ((bettingStates[bettingId].totalAmount1 + bettingStates[bettingId].totalAmount2) / 10); // go to jackpot and owner

    winners = new address[](3);
    rewards = new uint256[](3);
    // gold winner
    uint256 startIndex = serverNumber % clientSeeds.length;

    winners[0] = clientSeeds[startIndex].user;
    rewards[0] = (luckyWinnerRewardAmount * 5) / 8;

    // silver medal
    winners[1] = clientSeeds[(startIndex + 1) % clientSeeds.length].user;
    rewards[1] = luckyWinnerRewardAmount / 4;

    // bronze medal
    winners[2] = clientSeeds[(startIndex + 2) % clientSeeds.length].user;
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
}
