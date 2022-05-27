// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {FightBetting} from "contracts/betting/FightBetting.sol";
import {Auth} from "contracts/utils/Auth.sol";
import "./BasicSetup.sol";

contract FightBettingSetup is BasicSetup {
  FightBetting bettingContract;

  function setUp() public virtual {
    bettingContract = new FightBetting();
    bettingContract.grantRole("SIGNER", signer);
  }

  function sign(
    address to,
    uint256 fighter1,
    uint256 fighter2,
    uint32 startTime,
    uint32 endTime
  )
    public
    virtual
    returns (
      bytes32,
      bytes32,
      uint8
    )
  {
    bytes32 messageHash = keccak256(abi.encodePacked(to, fighter1, fighter2, startTime, endTime));
    bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSecretKey, digest);
    return (r, s, v);
  }
}
