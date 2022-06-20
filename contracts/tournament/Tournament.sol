// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {Auth} from "../utils/Auth.sol";
import {ITournament} from "./ITournament.sol";
import {Scholarship} from "../scholarship/Scholarship.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Tournament is ITournament, Auth {
  using SafeERC20 for IERC20;
  using SafeCast for uint256;

  // Constants
  uint256 private constant _BASIS_POINTS = 100_00;
  uint256 private constant _EXPIRATION_PERIOD = 1 weeks;
  string private constant _MANAGER = "MANAGER";
  uint32 private constant _MAX_UINT32 = type(uint32).max;

  // Address of USDC
  IERC20 public immutable usdc;
  // Address of rooster
  IERC721 public immutable rooster;
  // Address of scholarship contract
  Scholarship public scholarship;
  // Address of vault -- where fees go
  address public vault;

  // List of tournament games
  Game[] public games;
  // List of roosters (game id => rooster id => rooster state)
  // 0: not registered
  // 1 ~ 2^32 - 2: ranking of winners
  // 2^32 - 1: registered / unranked roosters
  mapping(uint256 => mapping(uint256 => uint32)) public roosters;

  constructor(
    address usdc_,
    address rooster_,
    address scholarship_,
    address vault_
  ) {
    usdc = IERC20(usdc_);
    rooster = IERC721(rooster_);
    scholarship = Scholarship(scholarship_);
    vault = vault_;
  }

  /**
   * @notice Queries state of roosters in batch
   * @param gameId Game id
   * @param roosterIds List of rooster ids
   */
  function batchQuery(uint256 gameId, uint256[] calldata roosterIds)
    external
    view
    returns (uint32[] memory)
  {
    uint32[] memory result = new uint32[](roosterIds.length);
    for (uint256 i = 0; i < roosterIds.length; i++) {
      result[i] = roosters[gameId][roosterIds[i]];
    }
    return result;
  }

  /**
   * @notice Returns total `games` created
   * @return uint256
   */
  function totalGames() external view returns (uint256) {
    return games.length;
  }

  /**
   * @notice Gets sum of distribution percentages
   * @param gameId Game id
   * @return sum uint16
   */
  function getDistributionsSum(uint256 gameId) external view returns (uint16 sum) {
    Game storage game = games[gameId];
    for (uint256 i = 1; i < game.distributions.length; i++) {
      sum += game.distributions[i];
    }
  }

  /**
   * @notice Creates new game
   * @param game CreateGameParam new game info
   * @return gameId uint256
   */
  function createGame(CreateGameParam calldata game)
    external
    onlyRole(_MANAGER)
    returns (uint256 gameId)
  {
    // Param check
    require(
      game.registrationStartTimestamp < game.registrationEndTimestamp,
      "Invalid registeration time window"
    );
    require(game.registrationStartTimestamp >= block.timestamp, "Invalid registeration start time");
    require(
      game.tournamentStartTimestamp < game.tournamentEndTimestamp,
      "Invalid tournament time window"
    );
    require(
      game.tournamentStartTimestamp > game.registrationEndTimestamp,
      "Invalid tournament start time"
    );
    require(game.distributions[0] == 0, "0th index must be 0");
    require(game.fee <= _BASIS_POINTS, "Invalid fee");

    // Get game id
    gameId = games.length;

    // Initialize and create game
    Game memory newGame = Game({
      registrationStartTimestamp: game.registrationStartTimestamp,
      registrationEndTimestamp: game.registrationEndTimestamp,
      tournamentStartTimestamp: game.tournamentStartTimestamp,
      tournamentEndTimestamp: game.tournamentEndTimestamp,
      minRoosters: game.minRoosters,
      maxRoosters: game.maxRoosters,
      roosters: 0,
      entranceFee: game.entranceFee,
      balance: 0,
      prizePool: 0,
      fee: game.fee,
      state: State.ONGOING,
      rankingRoot: bytes32(0),
      distributions: game.distributions
    });
    games.push(newGame);

    emit CreateGame(gameId, msg.sender);
  }

  /**
   * @notice Sets state of game
   * @param action Action enum
   * @param gameId Game id
   * @param fundAmount Amount to fund in USDC
   * @param rankingRoot Merkle root of ranking
   * @param distributions Distrubtion percentages to add.
   */
  function setGame(
    Action action,
    uint256 gameId,
    uint256 fundAmount,
    bytes32 rankingRoot,
    uint16[] calldata distributions
  ) external onlyRole(_MANAGER) {
    Game storage game = games[gameId];

    if (action == Action.ADD) {
      // Add distributions percentages
      uint256 num = distributions.length;
      require(block.timestamp < game.registrationStartTimestamp, "Registeration started");
      require(num > 0, "distrubutions not provided");

      // TODO: pre-package `distributions` and push by batch
      for (uint256 i = 0; i < num; i++) {
        game.distributions.push(distributions[i]);
      }
    } else if (action == Action.FUND) {
      // Fund to prize pool
      require(game.state != State.ENDED && game.state != State.CANCELLED, "Ended or cancelled");
      require(fundAmount > 0, "Amount not provided");
      game.balance += fundAmount.toUint64();
      game.prizePool += fundAmount.toUint64();
      usdc.safeTransferFrom(msg.sender, address(this), fundAmount);
    } else if (action == Action.END) {
      // End game
      require(block.timestamp >= game.tournamentEndTimestamp, "Not ended");
      require(rankingRoot != bytes32(0), "rankingRoot not provided");
      require(game.roosters >= game.minRoosters, "Not enough roosters");
      game.rankingRoot = rankingRoot;
      game.state = State.ENDED;
    } else if (action == Action.CANCEL) {
      // Cancel game and withdraw funded rewards
      require(game.state == State.ONGOING, "Not ongoing");
      uint256 fundedAmount = game.prizePool - game.roosters * game.entranceFee;
      game.state = State.CANCELLED;
      if (fundedAmount > 0) {
        game.balance -= fundedAmount.toUint64();
        usdc.safeTransfer(vault, fundedAmount);
      }
    } else if (action == Action.PAUSE) {
      // Pause game
      require(game.state == State.ONGOING, "Not ongoing");
      game.state = State.PAUSED;
    } else if (action == Action.UNPAUSE) {
      // Unpause game
      require(game.state == State.PAUSED, "Not paused");
      game.state = State.ONGOING;
    }

    emit SetGame(gameId, action);
  }

  /**
   * @notice Registers for the tournament game
   * @param gameId Game id
   * @param roosterIds List of roosters to register
   * @param sig Signature for tournament qualification
   * @return amount Total USDC paid
   */
  function register(
    uint256 gameId,
    uint256[] calldata roosterIds,
    Sig calldata sig
  ) external whenNotPaused returns (uint256 amount) {
    Game storage game = games[gameId];
    uint256 num = roosterIds.length;

    // Checks
    require(block.timestamp >= game.registrationStartTimestamp, "Not started");
    require(block.timestamp < game.registrationEndTimestamp, "Ended");
    require(game.state == State.ONGOING, "Paused or Cancelled");
    require(num <= game.maxRoosters - game.roosters, "Reached limit");
    require(_isOwner(msg.sender, roosterIds), "Not owner");
    require(_isQualified(gameId, roosterIds, sig), "Not qualified");

    // Effects
    for (uint256 i = 0; i < num; i++) {
      require(roosters[gameId][roosterIds[i]] == 0, "Already registered");
      roosters[gameId][roosterIds[i]] = _MAX_UINT32;
    }
    game.roosters += num.toUint32();
    game.balance += ((amount = game.entranceFee * num)).toUint64();
    game.prizePool += amount.toUint64();

    // Interactions
    usdc.safeTransferFrom(msg.sender, address(this), amount);

    emit RegisterGame(gameId, roosterIds, msg.sender);
  }

  /**
   * @notice Claims reward from tournament prize pool
   * @param gameId Game id
   * @param roosterIds List of rooster ids
   * @param rankings List of rankings
   * @return amount Total USDC rewarded
   * @return fee Fee in USDC
   */
  function claimReward(
    uint256 gameId,
    uint256[] calldata roosterIds,
    uint32[] calldata rankings,
    bytes32[][] memory proofs,
    address recipient
  ) external whenNotPaused returns (uint256 amount, uint256 fee) {
    Game storage game = games[gameId];

    // Checks
    require(roosterIds.length == rankings.length, "Length mismatch");
    require(game.state == State.ENDED, "Not ended");
    require(block.timestamp < game.tournamentEndTimestamp + _EXPIRATION_PERIOD, "Expired");
    require(_isOwner(msg.sender, roosterIds), "Not owner");

    // Individual Checks & Effects
    for (uint256 i = 0; i < roosterIds.length; i++) {
      bytes32 node = keccak256(abi.encodePacked(gameId, roosterIds[i], rankings[i]));
      require(MerkleProof.verify(proofs[i], game.rankingRoot, node), "Invalid proof");
      require(roosters[gameId][roosterIds[i]] == _MAX_UINT32, "Already claimed or not registered");

      // Set rooster ranking
      roosters[gameId][roosterIds[i]] = rankings[i];
      // Sum up distribution percentages
      amount += game.distributions[rankings[i]];
    }
    amount = (game.prizePool * amount) / _BASIS_POINTS;
    fee = (amount * game.fee) / _BASIS_POINTS;
    game.balance -= amount.toUint64();

    // Interactions
    usdc.safeTransfer(vault, fee);
    usdc.safeTransfer(recipient, amount - fee);

    emit ClaimReward(gameId, roosterIds, amount, recipient);
  }

  /**
   * @notice Claims refund from cancelled tournament
   * @param gameId Game id
   * @param roosterIds List of roosters registered
   * @param recipient Recipient address
   * @return amount Amount claimed
   */
  function claimRefund(
    uint256 gameId,
    uint256[] calldata roosterIds,
    address recipient
  ) external whenNotPaused returns (uint256 amount) {
    Game storage game = games[gameId];
    uint256 num = roosterIds.length;

    // Checks
    require(game.state == State.CANCELLED, "Not cancelled");
    require(_isOwner(msg.sender, roosterIds), "Not owner");

    // Individual Checks & Effects
    for (uint256 i = 0; i < num; i++) {
      require(roosters[gameId][roosterIds[i]] == _MAX_UINT32, "Already claimed");
      roosters[gameId][roosterIds[i]] = _MAX_UINT32 - 1;
    }
    amount = game.entranceFee * num;
    game.balance -= amount.toUint64();

    // Interactions
    usdc.safeTransfer(recipient, amount);

    emit ClaimRefund(gameId, roosterIds, amount, recipient);
  }

  function withdrawExpiredRewards(uint256 gameId)
    external
    onlyRole(_MANAGER)
    returns (uint256 amount)
  {
    Game storage game = games[gameId];

    // Checks
    require(block.timestamp >= game.tournamentEndTimestamp + _EXPIRATION_PERIOD, "Not expired");
    require(game.state == State.ENDED, "Not ended");
    require((amount = game.balance) > 0, "Nothing to withdraw");

    // Effects
    game.balance = 0;

    // Interactions
    usdc.safeTransfer(vault, amount);

    emit WithdrawExpiredRewards(gameId, amount);
  }

  function _isOwner(address owner, uint256[] calldata roosterIds) private view returns (bool) {
    for (uint256 i = 0; i < roosterIds.length; i++) {
      if (
        rooster.ownerOf(roosterIds[i]) != owner && scholarship.nft_owner(roosterIds[i]) != owner
      ) {
        return false;
      }
    }
    return true;
  }

  function _isQualified(
    uint256 gameId,
    uint256[] calldata roosterIds,
    Sig calldata sig
  ) private view returns (bool) {
    bytes32 messageHash = keccak256(abi.encodePacked(gameId, roosterIds));
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );
    return hasRole("SIGNER", ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s));
  }

  /**
   * @notice Sets addresses
   * @param vault_ Vault address
   * @param scholarship_ Scholarship contract address
   */
  function setProtocol(address vault_, address scholarship_) external onlyOwner {
    if (vault_ != address(0)) {
      vault = vault_;
    }
    if (scholarship_ != address(0)) {
      scholarship = Scholarship(scholarship_);
    }
  }
}
