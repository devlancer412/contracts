// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.4;

interface ITournament {
  struct Game {
    uint64 deadline; // Sign up deadline in block.timestamp [8]
    uint64 startTime; // Tournament start time in block.timestamp [8]
    uint64 endTime; // Tournament end time in block.timestamp [8]
    uint64 maxPlayers; // Max roosters for event [8]
    uint256 entranceFee; // Entrance fee in USDC [32]
    bytes32 qualification; // Tournament qualification hash [32]
    bytes32 distribution; // Merkle root of prize distribution [32]
    address organizer; // Organizer [20]
    State state; // Game state [1]
  }

  struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  enum State {
    ALIVE,
    ENDED,
    PAUSED,
    CANCELLED
  }

  event NewGame(
    uint256 gameId,
    uint64 deadline,
    uint64 startTime,
    uint64 endTime,
    uint64 maxPlayers,
    uint256 entranceFee,
    bytes32 requirement
  );
  event Distrubute(uint256 gameId, bytes32 distribution);

  error InvalidDeadline();
  error InvalidTimeWindow();
  error InvalidStartTime();
  error GameNotFinished();
  error InvalidAccess();
}
