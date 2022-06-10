// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

interface IFightBetting {
  // current betting live state
  enum BettingLiveState {
    Alive,
    Finished
  }
  // which player bet
  enum Side {
    Fighter1,
    Fighter2
  }
  // betting data
  struct Betting {
    uint256 fighter1; // First Fighter's token id
    uint256 fighter2; // Second Fighter's token id
    uint256 minAmount; // Minimum value of amount
    uint256 maxAmount; // Maximum value of amount
    uint32 startTime; // Start time of betting
    uint32 endTime; // End time of betting
    address creator; // Creator of betting
    address token; // Payable token address
  }
  // betting states
  struct BettingState {
    uint256 bettorCount1; // Count of bettor who bet first Fighter
    uint256 bettorCount2; // Count of bettor who bet second Fighter
    uint256 totalAmount1; // Total price of first Fighter bettors
    uint256 totalAmount2; // Total price of second Fighter bettors
    BettingLiveState liveState; // Set true after finish betting
    Side side; // who has winned
  }
  // bettor data
  struct Bettor {
    address bettor; // Address of bettor
    uint256 amount; // Deposit amount
    Side side; // which betted
    bool hasWithdrawn; // has withdrawn?
  }
  // signature struct
  struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }
  // game result struct
  struct ResultData {
    address bettor;
    uint256 amount;
    int256 reward; // Winner true => fighter1 | false => fighter2
  }
  // seed data of game
  struct SeedData {
    bytes32 hashedServerSeed;
    bytes32 serverSeed;
    bytes32 clientSeed;
  }

  // Events
  // emit when new betting is created
  event NewBetting(
    uint256 fighter1,
    uint256 fighter2,
    uint32 startTime,
    uint32 endTime,
    address token
  );
  // emit when bettor bet a player(fighter)
  event Betted(address indexed from, uint256 fighter, uint256 amount);
  // emit when betting is finished
  event Finished(uint256 bettingId, uint256 winner);
  // emit when bettor withdraw their reward
  event WinnerWithdrawed(uint256 bettingId, address indexed to, uint256 amount);
}
