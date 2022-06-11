// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {Auth} from "../utils/Auth.sol";
import {ITournament} from "./ITournament.sol";
import {Scholarship} from "../scholarship/Scholarship.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Tournament is ITournament, Auth {
  using SafeERC20 for IERC20;
  using SafeCast for uint256;

  uint256 private constant _BASIS_POINTS = 100_00;

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
   * @notice Creates new game
   * @param game Game info
   * @return gameId uint256
   */
  function createGame(Game memory game) external onlyRole("MANAGER") returns (uint256 gameId) {
    // Param check
    require(game.checkinStartTime < game.checkinEndTime, "Invalid checkin time window");
    require(game.checkinStartTime >= block.timestamp, "Invalid checkin start time");
    require(game.gameStartTime < game.gameEndTime, "Invalid game time window");
    require(game.gameStartTime > game.checkinEndTime, "Invalid game time window");
    require(game.distributions[0] == 0, "0th index must be 0");
    require(game.fee <= _BASIS_POINTS, "Invalid fee");

    // Get game id
    gameId = games.length;

    // Create game
    game.roosters = 0;
    game.state = State.ONGOING;
    game.organizer = msg.sender;
    game.rankingRoot = bytes32(0);
    games.push(game);

    emit NewGame(gameId, game.requirementId, msg.sender);
  }

  /**
   * @notice Sets state of game
   * @param action Action enum
   * @param gameId Game id
   * @param rankingRoot Merkle root of ranking
   * @param distributions Distrubtion percentages to add.
   */
  function setGame(
    Action action,
    uint256 gameId,
    bytes32 rankingRoot,
    uint16[] calldata distributions
  ) external {
    Game storage game = games[gameId];

    // Access check
    require(msg.sender == game.organizer, "Not organizer");

    if (action == Action.ADD) {
      uint256 n = distributions.length;
      require(block.timestamp < game.checkinStartTime, "Signup started");
      require(n > 1, "distrubutions not provided");

      // TODO: pre-package `distributions` and push by batch
      for (uint256 i = 0; i < n; i++) {
        game.distributions.push(distributions[i]);
      }
    }
    if (action == Action.END) {
      require(block.timestamp >= game.gameEndTime, "Game ongoing");
      require(rankingRoot != bytes32(0), "rankingRoot not provided");
      game.rankingRoot = rankingRoot;
      game.state = State.ENDED;
    } else if (action == Action.CANCEL) {
      require(game.state == State.ONGOING, "Game ended");
      game.state = State.CANCELLED;
    } else if (action == Action.PAUSE) {
      require(game.state == State.ONGOING, "Game ended");
      game.state = State.PAUSED;
    } else if (action == Action.UNPAUSE) {
      require(game.state != State.PAUSED, "Not paused");
      game.state = State.ONGOING;
    }

    emit SetGame(gameId, action);
  }

  /**
   * @notice Registers for the tournament game
   * @param gameId Game id
   * @param roosterIds List of roosters to register
   * @param sig Signature for tournament qualification
   */
  function register(
    uint256 gameId,
    uint256[] calldata roosterIds,
    Sig calldata sig
  ) external {
    Game storage game = games[gameId];
    uint256 n = roosterIds.length;

    // Checks
    require(block.timestamp >= game.checkinStartTime, "Not started");
    require(block.timestamp < game.checkinEndTime, "Ended");
    require(game.state == State.ONGOING, "Paused or Cancelled");
    require(n > game.maxRoosters - game.roosters, "Reached limit");
    require(_isOwner(msg.sender, roosterIds), "Not owner");
    require(_isQualified(gameId, game.requirementId, roosterIds, sig), "Not qualified");

    // Effects
    for (uint256 i = 0; i < n; i++) {
      require(roosters[gameId][roosterIds[i]] == 0, "Already registered");
      roosters[gameId][roosterIds[i]] = type(uint32).max;
    }
    game.roosters += n.toUint32();
    game.balance += (game.entranceFee * n).toUint128();

    // Interactions
    usdc.safeTransferFrom(msg.sender, address(this), game.entranceFee * n);

    emit RegisterGame(gameId, roosterIds, msg.sender);
  }

  /**
   * @notice Claims reward from tournament prize pool
   * @param gameId Game id
   * @param roosterIds List of rooster ids
   * @param rankings List of rankings
   */
  function claimReward(
    uint256 gameId,
    uint256[] calldata roosterIds,
    uint32[] calldata rankings,
    bytes32[] calldata proofs,
    address recipient
  ) external returns (uint256 amount, uint256 fee) {
    Game storage game = games[gameId];
    uint256 n = roosterIds.length;

    // Checks
    require(n == rankings.length, "Length mismatch");
    require(game.state == State.ENDED, "Not ended");
    require(_isOwner(msg.sender, roosterIds), "Not owner");

    uint256 length = proofs.length / n;
    bytes32[] memory proof = new bytes32[](length);
    for (uint256 i = 0; i < n; i++) {
      // Validate rooster ranking using Merkle proof
      for (uint256 j = 0; j < length; j++) {
        proof[j] = proofs[j + length * i];
      }
      bytes32 node = keccak256(abi.encodePacked(gameId, roosterIds[i], rankings[i]));
      require(MerkleProof.verify(proof, game.rankingRoot, node), "Invalid proof");
      require(
        roosters[gameId][roosterIds[i]] == type(uint32).max,
        "Already claimed or not registered"
      );

      // Set rooster ranking
      roosters[gameId][roosterIds[i]] = rankings[i];
      amount +=
        (game.entranceFee * game.roosters * game.distributions[rankings[i]]) /
        _BASIS_POINTS;
    }
    game.balance -= amount.toUint128();

    // Interactions
    usdc.safeTransfer(vault, (fee = (amount * game.fee) / _BASIS_POINTS));
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
  ) external returns (uint256 amount) {
    Game storage game = games[gameId];
    uint256 n = roosterIds.length;

    // Checks
    require(game.state == State.CANCELLED, "Not cancelled");
    require(_isOwner(msg.sender, roosterIds), "Not owner");

    // Effects
    for (uint256 i = 0; i < n; i++) {
      require(roosters[gameId][roosterIds[i]] == type(uint32).max, "Already withdrawn");
      roosters[gameId][roosterIds[i]] = 0;
    }

    // Interactions
    usdc.safeTransfer(recipient, (amount = game.entranceFee * n));

    emit ClaimRefund(gameId, roosterIds, amount, recipient);
  }

  /**
   * @notice Withdraws expired rewards from tournament pool
   * @param gameId Game id
   * @param recipient Address of recipient
   * @return amount Amount withdrawn
   */
  function withdrawExpiredRewards(uint256 gameId, address recipient)
    external
    returns (uint256 amount)
  {
    Game storage game = games[gameId];

    // Checks
    require(msg.sender == game.organizer, "Not organizer");
    require(block.timestamp > game.expirationTime, "Not expired");
    require(game.state == State.ENDED, "Not ended");
    require((amount = game.balance) > 0, "Nothing to withdraw");

    // Effects
    game.balance = 0;

    // Interactions
    usdc.safeTransfer(recipient, amount);

    emit WithdrawExpiredReward(gameId, amount, recipient);
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
    bytes8 requirementId,
    uint256[] calldata roosterIds,
    Sig calldata sig
  ) private view returns (bool) {
    bytes32 messageHash = keccak256(abi.encodePacked(gameId, requirementId, roosterIds));
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );
    return hasRole("SIGNER", ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s));
  }

  /**
   * @notice Sets addresses
   */
  function setProtocol(address vault_, address scholarship_) external onlyOwner {
    vault = vault_;
    scholarship = Scholarship(scholarship_);
  }
}
