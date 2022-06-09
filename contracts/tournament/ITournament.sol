// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.4;

interface ITournament {
  // 4slots
  struct Game {
    uint32 checkinStartTime; // Registration start date in block.timestamp [4]
    uint32 checkinEndTime; // Registeration end date in block.timestamp [4]
    uint32 gameStartTime; // Tournament start date in block.timestamp [4]
    uint32 gameEndTime; // Tournament end date in block.timestamp [4]
    uint32 rewardExpiration; // Reward expiration date to claim in block.timestamp [4]
    uint32 minRoosters; // Minimum roosters required to start [4]
    uint32 maxRoosters; // Maximum roosters for game [4]
    uint32 roosters; // Number of rooosters [4]
    uint256 entranceFee; // Entrance fee in USDC [32]
    bytes32 distribution; // Merkle root of prize distribution [32]
    bytes8 requirementId; // Requirement id [8]
    address organizer; // Organizer [20]
    State state; // Event state [1]
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

  enum Action {
    END,
    PAUSE,
    CANCEL
  }

  event NewGame(uint256 indexed gameId, bytes8 indexed requirementId, address indexed organzier);
  event SetGame(uint256 indexed gameId, bytes32 distribution);

  error InvalidDeadline();
  error InvalidTimeWindow();
  error InvalidStartTime();
  error GameNotFinished();
  error InvalidAccess();
}
