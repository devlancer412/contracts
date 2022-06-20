// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.4;

interface ITournament {
  // 4slots
  struct Game {
    uint32 registrationStartTimestamp; // Registration start date in block.timestamp [4]
    uint32 registrationEndTimestamp; // Registeration end date in block.timestamp [4]
    uint32 tournamentStartTimestamp; // Tournament start date in block.timestamp [4]
    uint32 tournamentEndTimestamp; // Tournament end date in block.timestamp [4]
    uint32 minRoosters; // Minimum roosters required to start [4]
    uint32 maxRoosters; // Maximum roosters for game [4]
    uint32 roosters; // Number of rooosters [4]
    uint64 entranceFee; // Entrance fee in USDC [8]
    uint64 balance; // Balance of tournament pool in USDC [8]
    uint64 prizePool; // Prize pool in USDC [8]
    uint16 fee; // Protocol fee in hundreds [2]
    State state; // Event state [1]
    bytes32 rankingRoot; // Merkle root of tournament ranking [32]
    uint16[] distributions; // Array of distrubution percentages in hundreds [32 + 2n]
  }

  struct CreateGameParam {
    uint32 registrationStartTimestamp;
    uint32 registrationEndTimestamp;
    uint32 tournamentStartTimestamp;
    uint32 tournamentEndTimestamp;
    uint32 minRoosters;
    uint32 maxRoosters;
    uint64 entranceFee;
    uint16 fee;
    uint16[] distributions;
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
    FUND,
    END,
    PAUSE,
    UNPAUSE,
    CANCEL
  }

  event CreateGame(uint256 indexed gameId, address indexed organzier);
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
