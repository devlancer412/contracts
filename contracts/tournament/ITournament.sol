// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.4;

interface ITournament {
  struct Game {
    uint64 deadline; // Sign up deadline in block.timestamp
    uint64 startTime; // Tournament start time in block.timestamp
    uint64 endTime; // Tournament end time in block.timestamp
    uint64 maxPlayers; // Max roosters for event
    uint256 entranceFee; // Entrance fee in USDC
    bytes32 qualification; // Tournament qualification hash
    bytes32 distribution; // Merkle root of prize distribution
    address organizer; // Organizer
    bool paused; // Is paused
  }

  struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  event NewGame(
    uint256 index,
    uint64 deadline,
    uint64 startTime,
    uint64 endTime,
    uint64 maxPlayers,
    uint256 entranceFee,
    bytes32 requirement
  );

  error InvalidDeadline();
  error InvalidTimeWindow();
  error InvalidStartTime();
}
