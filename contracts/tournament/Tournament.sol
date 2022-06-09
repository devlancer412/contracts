// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {ITournament} from "./ITournament.sol";
import {Auth} from "../utils/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Tournament is ITournament, Auth {
  // Address of USDC
  IERC20 public immutable usdc;
  // Address of rooster
  IERC721 public immutable rooster;
  // Address of vault -- where fees go
  address public vault;

  // List of tournament games
  Game[] public games;
  // List of roosters (game id => rooster id => rooster state)
  // 0: not registered
  // 1 ~ 2^32 - 2: ranking of winners
  // 2^32 - 1: registered / unranked roosters
  mapping(uint256 => mapping(uint256 => uint32)) public roosters;
  // Burned nonces
  mapping(bytes32 => bool) private _nonceBurned;

  constructor(
    address usdc_,
    address rooster_,
    address vault_
  ) {
    usdc = IERC20(usdc_);
    rooster = IERC721(rooster_);
    vault = vault_;
  }

  /**
   * @notice Creates new game
   * @param game Game info
   * @return gameId uint256
   */
  function createGame(Game memory game) external onlyRole("MANAGER") returns (uint256 gameId) {
    // Param check
    require(game.checkinStartTime < game.checkinEndTime, "");
    require(game.checkinStartTime >= block.timestamp, "");
    require(game.gameStartTime > game.checkinEndTime, "");
    require(game.gameStartTime < game.gameEndTime, "");

    // Get game id
    gameId = games.length;

    // Create game
    game.roosters = 0;
    game.distribution = bytes32(0);
    game.organizer = msg.sender;
    game.state = State.ALIVE;
    games.push(game);

    emit NewGame(gameId, game.requirementId, msg.sender);
  }

  /**
   * @notice Sets state of game
   * @param action Action enum
   * @param gameId Game id
   * @param distribution Merkle root of prize distrubution
   */
  function setGame(
    Action action,
    uint256 gameId,
    bytes32 distribution
  ) external {
    Game storage game = games[gameId];

    // Access check
    require(msg.sender == game.organizer, "");

    if (action == Action.END) {
      require(block.timestamp >= game.gameEndTime, "");
      require(distribution != bytes32(0), "");
      game.distribution = distribution;
      game.state = State.ENDED;
    } else if (action == Action.CANCEL) {
      require(game.state != State.ENDED, "");
      game.state = State.CANCELLED;
    } else if (action == Action.PAUSE) {
      game.state = State.PAUSED;
    }

    emit SetGame(gameId, distribution);
  }

  function register(
    uint256 gameId,
    uint256 roosterId,
    bytes32 nonce,
    Sig calldata sig
  ) external {
    Game storage game = games[gameId];

    if (_canRegister(gameId, roosterId) == false) revert();
    if (_isQualified(roosterId, nonce, sig) == false) revert();

    roosters[gameId][roosterId] = type(uint32).max;

    usdc.transferFrom(msg.sender, address(this), game.entranceFee);
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

    if (game.distribution == bytes32(0)) revert();
    if (roosters[gameId][roosterId] != type(uint64).max) revert();
    if (MerkleProof.verify(proof, game.distribution, node)) revert();

    roosters[gameId][roosterId] = ranking;

    usdc.transfer(msg.sender, amount / 9);
    usdc.transfer(msg.sender, (amount * 9) / 10);
  }

  function _canRegister(uint256 gameId, uint256 roosterId) private returns (bool) {}

  function _isQualified(
    uint256 roosterId,
    bytes32 nonce,
    Sig calldata sig
  ) private returns (bool) {}
}
