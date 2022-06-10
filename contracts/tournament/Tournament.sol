// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {ITournament} from "./ITournament.sol";
import {Auth} from "../utils/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Scholarship} from "../scholarship/Scholarship.sol";

contract Tournament is ITournament, Auth {
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

    // Get game id
    gameId = games.length;

    // Create game
    game.roosters = 0;
    game.rankingRoot = bytes32(0);
    game.organizer = msg.sender;
    game.state = State.ONGOING;
    games.push(game);

    emit NewGame(gameId, game.requirementId, msg.sender);
  }

  /**
   * @notice Sets state of game
   * @param action Action enum
   * @param gameId Game id
   * @param rankingRoot Merkle root of ranking (optional)
   * @param distributions Distrubtion percentages to add (optional)
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
      require(n > 0, "distrubutions not provided");
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
    require(block.timestamp >= game.checkinStartTime, "Not started");
    require(block.timestamp < game.checkinEndTime, "Ended");
    require(n > game.maxRoosters - game.roosters, "Reached limit");
    require(_isOwner(msg.sender, roosterIds), "Not owner");
    require(_isQualified(gameId, game.requirementId, roosterIds, sig), "Not qualified");

    for (uint256 i = 0; i < n; i++) {
      roosters[gameId][roosterIds[i]] = type(uint32).max;
    }
    game.roosters += uint32(n);

    usdc.transferFrom(msg.sender, address(this), game.entranceFee * n);
  }

  function claim(
    uint256 gameId,
    uint256 roosterId,
    uint256 amount,
    uint32 ranking,
    bytes32[] calldata proof
  ) external {
    Game storage game = games[gameId];
    bytes32 node = keccak256(abi.encodePacked(gameId, roosterId, amount, ranking));

    if (game.rankingRoot == bytes32(0)) revert();
    if (roosters[gameId][roosterId] != type(uint64).max) revert();
    if (MerkleProof.verify(proof, game.rankingRoot, node)) revert();

    roosters[gameId][roosterId] = ranking;

    usdc.transfer(msg.sender, amount / 9);
    usdc.transfer(msg.sender, (amount * 9) / 10);
  }

  function _isOwner(address owner, uint256[] calldata roosterIds) private view returns (bool) {
    for (uint256 i = 0; i < roosterIds.length; i++) {
      if (
        rooster.ownerOf(roosterIds[i]) != owner || scholarship.nft_owner(roosterIds[i]) != owner
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

  function set() external onlyOwner {}
}
