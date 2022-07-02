// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/Proxy.sol)

pragma solidity ^0.8.9;

contract TrackableProxy {
  event AffiliateCall(
    uint256 indexed affiliate,
    address indexed implement,
    address indexed from,
    bytes data
  );

  constructor() {}

  function _fallback() internal {
    bytes32 _id = keccak256(abi.encode("AffiliateCall(uint256, address, address, bytes)"));
    assembly {
      // Copy msg.data. We take full control of memory in this inline assembly
      // block because it will not return to Solidity code. We overwrite the
      // Solidity scratch pad at memory position 0.
      let dataPtr := 0xc0 // next call data pointer
      let paramNumber := div(sub(calldatasize(), 0x64), 0x20) // get reall call parameter number
      calldatacopy(add(dataPtr, 0x24), 0x04, mul(paramNumber, 0x20)) // copy call params
      calldatacopy(0x60, add(mul(paramNumber, 0x20), 0x04), 0x40) // capy distination and affiliate address
      calldatacopy(dataPtr, add(mul(paramNumber, 0x20), 0x60), 0x04) // copy function selector
      mstore(add(dataPtr, 0x04), caller()) // sent msg.sender to first param
      let to := mload(0x60) // load distination address
      let affiliate := mload(0x80) // load affiliate address

      // Call the implementation.
      // out and outsize are 0 because we don't know the size yet.
      let result := call(gas(), to, callvalue(), dataPtr, add(mul(paramNumber, 0x20), 0x24), 0, 0)

      // emit log
      log4(add(dataPtr, 0x24), mul(paramNumber, 0x20), _id, affiliate, to, caller())
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
