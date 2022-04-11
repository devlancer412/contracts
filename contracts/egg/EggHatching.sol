// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {Auth} from "../utils/Auth.sol";

interface IEgg {
  function burnBatch(uint24[] memory eggIds) external;

  function ownerOf(uint256 tokenId) external view returns (address);
}

interface INft {
  function batchMint(address to, uint256[] memory types) external;
}

contract RoosterEggHatching is Auth {
  //Address of RoosterEgg contract
  address public immutable egg;
  //Address of Rooster contract
  address public immutable rooster;
  //Address of Gaff contract
  address public immutable gaff;
  //Address of Gem contract
  address public immutable gem;
  //Egg hatch starting time
  uint256 public startingTime;

  //Fires when eggs are hatched
  event EggsHatched(address indexed user, uint24[] eggIds);

  struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  constructor(
    address signer_,
    address egg_,
    address rooster_,
    address gaff_,
    address gem_
  ) {
    egg = egg_;
    rooster = rooster_;
    gaff = gaff_;
    gem = gem_;
    _grantRole("SIGNER", signer_);
  }

  function hasStarted() public view returns (bool) {
    return block.timestamp >= startingTime && startingTime > 0 ? true : false;
  }

  /**
   * @param eggIds Array of rooster egg ids to burn
   * @param breeds Array of rooster breeds to mint
   * @param gaffTypes Array of gaff amounts to mint (Index number corresponds to gaff id)
   * @param gemTypes Array of gem ids to mint
   */
  function hatch(
    address to,
    uint24[] calldata eggIds,
    uint256[] calldata breeds,
    uint256[] calldata gaffTypes,
    uint256[] calldata gemTypes,
    Sig calldata sig
  ) external whenNotPaused {
    //Check if hatch event is started
    require(hasStarted(), "Not started");
    //Check if parameters are valid
    require(_isParamValid(breeds, gaffTypes, gemTypes, sig), "Invalid parameter");
    //Check if egg owner
    require(_isOwnerCorrect(eggIds), "Invalid owner");

    //Burn eggs
    IEgg(egg).burnBatch(eggIds);
    //Mint roosters
    INft(rooster).batchMint(to, breeds);
    //Mint gaffs
    INft(gaff).batchMint(to, gaffTypes);
    //Mint gems
    INft(gem).batchMint(to, gemTypes);

    emit EggsHatched(msg.sender, eggIds);
  }

  function _isParamValid(
    uint256[] calldata breeds,
    uint256[] calldata gaffTypes,
    uint256[] calldata gemTypes,
    Sig calldata sig
  ) private view returns (bool) {
    bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, breeds, gaffTypes, gemTypes));
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );

    return hasRole("SIGNER", ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s));
  }

  function _isOwnerCorrect(uint24[] calldata eggIds) private view returns (bool) {
    unchecked {
      for (uint256 i = 0; i < eggIds.length; i++) {
        if (IEgg(egg).ownerOf(eggIds[i]) != msg.sender) {
          return false;
        }
      }
    }
    return true;
  }

  function setStartingTime(uint256 startingTime_) external onlyOwner {
    require(startingTime_ > block.timestamp, "Invalid starting time");
    startingTime = startingTime_;
  }
}
