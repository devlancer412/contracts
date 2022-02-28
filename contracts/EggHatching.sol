// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IEgg {
  function burnBatch(uint24[] memory eggIds) external;
}

interface IRooster {
  function mintBatch(address to, uint8[] memory breeds) external;
}

interface IGaff {
  function mintBatch(address to, uint256[] memory amounts) external;
}

interface IGem {
  function mintByIds(
    address to,
    uint256[] memory gemIds
  ) external;
}

contract RoosterEggHatching is Ownable, Pausable {
  //Address of RoosterEgg contract
  address public immutable egg;
  //Address of Rooster contract
  address public immutable rooster;
  //Address of Gaff contract
  address public immutable gaff;
  //Address of Gem contract
  address public immutable gem;
  //Address of signer
  address public signer;

  event UpdateSigner(address indexed signer);

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
    setSigner(signer_);
  }

  function hatch(
    address to,
    uint24[] memory eggIds,
    uint8[] calldata breeds,
    uint256[] calldata gaffAmounts,
    uint256[] calldata gemIds,
    Sig calldata sig
  ) external whenNotPaused {
    //Check if parameters are valid
    require(
      _isParamValid(breeds, gaffAmounts, gemIds, sig),
      "Invalid parameter"
    );

    //Burn eggs
    IEgg(egg).burnBatch(eggIds);
    //Mint roosters
    IRooster(rooster).mintBatch(to, breeds);
    //Mint gaffs
    IGaff(gaff).mintBatch(to, gaffAmounts);
    //Mint gems
    IGem(gem).mintByIds(to, gemIds);
  }

  function _isParamValid(
    uint8[] calldata breeds,
    uint256[] calldata gaffAmounts,
    uint256[] calldata gemIds,
    Sig calldata sig
  ) private view returns (bool) {
    bytes32 messageHash = keccak256(
      abi.encodePacked(msg.sender, breeds, gaffAmounts, gemIds)
    );
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );

    return ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s) == signer;
  }

  function setSigner(address newSigner) public onlyOwner {
    signer = newSigner;
    emit UpdateSigner(signer);
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }
}
