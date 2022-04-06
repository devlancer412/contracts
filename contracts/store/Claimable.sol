// SPDX-License-Identifier: UNLICENSED
/**
  Claimable
 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Claimable is Ownable {
  mapping(address => bool) public signers;
  mapping(uint256 => bool) public burned;

  struct Claim {
    uint256 nonce;
    address target;
    uint256 amount;
    Sig signature;
  }

  struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  event UpdateSigner(address signer, bool state);
  event Claimed(uint256 indexed nonce, address indexed target, uint256 amount);

  function setSigner(address _signer, bool _state) public onlyOwner {
    signers[_signer] = _state;
    emit UpdateSigner(_signer, _state);
  }

  function authorize(
    Sig calldata sig,
    uint256 nonce,
    bytes32 messageHash
  ) internal view returns (bool) {
    require(!burned[nonce], "Claimable:BURNED");
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );
    address signer = ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s);
    return signers[signer];
  }

  function validateClaim(Claim calldata claimData) public view returns (bool) {
    bytes32 messageHash = keccak256(
      abi.encodePacked(claimData.nonce, claimData.target, claimData.amount)
    );
    return authorize(claimData.signature, claimData.nonce, messageHash);
  }

  function _burn_nonce(uint256 nonce) internal {
    burned[nonce] = true;
  }
}
