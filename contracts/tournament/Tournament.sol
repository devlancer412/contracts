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
  // 1 ~ 2^64 - 2: ranking of winners
  // 2^64 - 1: registered / unranked roosters
  mapping(uint256 => mapping(uint256 => uint64)) public roosters;
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
   * @param deadline Sign up deadline
   * @param startTime Tournament starting time
   * @param endTime Tournament ending time
   * @param maxPlayers Max roosters for event
   * @param entranceFee Entrance fee in USDC
   * @param qualification Tournament qualification hash
   * @return gameId uint256
   */
  function createGame(
    uint64 deadline,
    uint64 startTime,
    uint64 endTime,
    uint64 maxPlayers,
    uint256 entranceFee,
    bytes32 qualification
  ) external onlyRole("MANAGER") returns (uint256 gameId) {
    // Check param
    if (deadline < block.timestamp) revert InvalidDeadline();
    if (startTime > endTime) revert InvalidTimeWindow();
    if (startTime < deadline) revert InvalidStartTime();

    // Get game id
    gameId = games.length;

    // Create game
    Game memory game = Game(
      deadline,
      startTime,
      endTime,
      maxPlayers,
      entranceFee,
      qualification,
      bytes32(0),
      msg.sender,
      State.ALIVE
    );
    games.push(game);

    emit NewGame(gameId, deadline, startTime, endTime, maxPlayers, entranceFee, qualification);
  }

  /**
   * @notice Finish game
   * @param gameId uint256
   * @param distribution Merkle root of prize distribution
   */
  function finishGame(uint256 gameId, bytes32 distribution) external {
    Game storage game = games[gameId];

    // Check
    if (block.timestamp < game.endTime) revert GameNotFinished();
    if (msg.sender != game.organizer) revert InvalidAccess();
    if (distribution == bytes32(0)) revert();

    // Set game
    game.distribution = distribution;
    game.state = State.ENDED;

    emit Distrubute(gameId, distribution);
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

    roosters[gameId][roosterId] = type(uint64).max;

    usdc.transferFrom(msg.sender, address(this), game.entranceFee);
  }

  function claim(
    uint256 gameId,
    uint256 roosterId,
    uint256 amount,
    uint64 ranking,
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
