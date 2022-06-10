// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.4;

interface ITournament {
  // 5slots
  struct Game {
    uint32 checkinStartTime; // Registration start date in block.timestamp [4]
    uint32 checkinEndTime; // Registeration end date in block.timestamp [4]
    uint32 gameStartTime; // Tournament start date in block.timestamp [4]
    uint32 gameEndTime; // Tournament end date in block.timestamp [4]
    uint32 expirationTime; // Expiration date to claim in block.timestamp [4]
    uint32 minRoosters; // Minimum roosters required to start [4]
    uint32 maxRoosters; // Maximum roosters for game [4]
    uint32 roosters; // Number of rooosters [4]
    uint256 entranceFee; // Entrance fee in USDC [32]
    bytes32 rankingRoot; // Merkle root of tournament ranking [32]
    uint16[] distributions; // Array of distrubution percentages in hundreds [32 + 2n]
    uint16 fee; // Protocol fee in hundreds [4]
    bytes4 requirementId; // Requirement id [4]
    address organizer; // Organizer [20]
    State state; // Event state [1]
  }

  struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  enum State {
    ONGOING,
    ENDED,
    PAUSED,
    CANCELLED
  }

  enum Action {
    ADD,
    END,
    PAUSE,
    UNPAUSE,
    CANCEL
  }

  event NewGame(uint256 indexed gameId, bytes8 indexed requirementId, address indexed organzier);
  event SetGame(uint256 indexed gameId, Action indexed action);

  error InvalidDeadline();
  error InvalidTimeWindow();
  error InvalidStartTime();
  error GameNotFinished();
  error InvalidAccess();
}
