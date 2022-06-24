// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/Proxy.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract TrackableProxy is Ownable {
  event Purchase(address indexed affiliate, uint256 amount);

  // event Test(address indexed implement, address indexed , uint256 len)

  constructor() {}

  function _fallback() internal {
    bytes32 _id = keccak256(abi.encode("Purchase(address indexed, uint256)"));
    assembly {
      // Copy msg.data. We take full control of memory in this inline assembly
      // block because it will not return to Solidity code. We overwrite the
      // Solidity scratch pad at memory position 0.
      let len := mload(0x40)
      let dataPtr := 0xc0
      len := sub(calldatasize(), 0x60)
      mstore(dataPtr, div(sub(len, 4), 0x20))
      calldatacopy(add(dataPtr, 0x20), 0, len)
      calldatacopy(0x60, len, 0x20)
      calldatacopy(0x80, add(len, 0x20), 0x20)
      calldatacopy(add(dataPtr, 0x20), add(len, 0x5c), 0x04)
      let to := mload(0x60)
      let affiliate := mload(0x80)

      // Call the implementation.
      // out and outsize are 0 because we don't know the size yet.
      let result := call(gas(), to, callvalue(), add(dataPtr, 0x20), len, 0, 0)

      log2(add(dataPtr, len), 0x20, _id, affiliate)
      // Copy the returned data.
      returndatacopy(0, 0, returndatasize())

      switch result
      // delegatecall returns 0 on error.
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }

  /**
   * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
   * function in the contract matches the call data.
   */
  fallback() external payable {
    _fallback();
  }

  /**
   * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
   * is empty.
   */
  receive() external payable {
    _fallback();
  }
}
