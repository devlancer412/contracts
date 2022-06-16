// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.4;

interface ITournament {
  // 5slots
  struct Game {
    uint32 registrationStartTimestamp; // Registration start date in block.timestamp [4]
    uint32 registrationEndTimestamp; // Registeration end date in block.timestamp [4]
    uint32 tournamentStartTimestamp; // Tournament start date in block.timestamp [4]
    uint32 tournamentEndTimestamp; // Tournament end date in block.timestamp [4]
    uint32 minRoosters; // Minimum roosters required to start [4]
    uint32 maxRoosters; // Maximum roosters for game [4]
    uint32 roosters; // Number of rooosters [4]
    uint128 entranceFee; // Entrance fee in USDC [16]
    uint128 balance; // Balance of tournament pool in USDC [16]
    bytes32 rankingRoot; // Merkle root of tournament ranking [32]
    uint16[] distributions; // Array of distrubution percentages in hundreds [32 + 2n]
    uint16 fee; // Protocol fee in hundreds [4]
    uint16 requirementId; // Requirement id [4]
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

  event CreateGame(uint256 indexed gameId, uint16 indexed requirementId, address indexed organzier);
  event SetGame(uint256 indexed gameId, Action indexed action);
  event RegisterGame(uint256 indexed gameId, uint256[] roosterIds, address indexed sender);
  event ClaimReward(
    uint256 indexed gameId,
    uint256[] roosterIds,
    uint256 amount,
    address indexed recipient
  );
  event ClaimRefund(
    uint256 indexed gameId,
    uint256[] roosterIds,
    uint256 amount,
    address indexed recipient
  );
  event WithdrawExpiredRewards(uint256 indexed gameId, uint256 amount);
}
