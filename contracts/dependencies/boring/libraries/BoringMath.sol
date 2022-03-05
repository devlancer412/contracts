// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// a library for performing overflow-safe math, updated with awesomeness from of DappHub (https://github.com/dapphub/ds-math)
library BoringMath {
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    require((c = a + b) >= b, "BoringMath: Add Overflow");
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256 c) {
    require((c = a - b) <= a, "BoringMath: Underflow");
  }

  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    require(b == 0 || (c = a * b) / b == a, "BoringMath: Mul Overflow");
  }

  function to128(uint256 a) internal pure returns (uint128 c) {
    require(a <= type(uint128).max, "BoringMath: uint128 Overflow");
    c = uint128(a);
  }

  function to64(uint256 a) internal pure returns (uint64 c) {
    require(a <= type(uint64).max, "BoringMath: uint64 Overflow");
    c = uint64(a);
  }

  function to32(uint256 a) internal pure returns (uint32 c) {
    require(a <= type(uint32).max, "BoringMath: uint32 Overflow");
    c = uint32(a);
  }
}

library BoringMath128 {
  function add(uint128 a, uint128 b) internal pure returns (uint128 c) {
    require((c = a + b) >= b, "BoringMath: Add Overflow");
  }

  function sub(uint128 a, uint128 b) internal pure returns (uint128 c) {
    require((c = a - b) <= a, "BoringMath: Underflow");
  }
}

library BoringMath64 {
  function add(uint64 a, uint64 b) internal pure returns (uint64 c) {
    require((c = a + b) >= b, "BoringMath: Add Overflow");
  }

  function sub(uint64 a, uint64 b) internal pure returns (uint64 c) {
    require((c = a - b) <= a, "BoringMath: Underflow");
  }
}

library BoringMath32 {
  function add(uint32 a, uint32 b) internal pure returns (uint32 c) {
    require((c = a + b) >= b, "BoringMath: Add Overflow");
  }

  function sub(uint32 a, uint32 b) internal pure returns (uint32 c) {
    require((c = a - b) <= a, "BoringMath: Underflow");
  }
}
