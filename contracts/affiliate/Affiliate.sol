// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Auth} from "../utils/Auth.sol";

contract Affiliate is Auth {
  // redeem token address
  address public erc20token;
  // shows redeemed if true => redeemed else not redeemed
  mapping(uint64 => bool) public rewards_redeem;
  // reward distributor
  address public rewards_distributor;

  event Redeem(address redeemer, uint64[] redeem_codes, uint256 redeemed_value);

  struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  // constructor
  constructor(address _erc20token, address _rewards_distributor) {
    erc20token = _erc20token;
    rewards_distributor = _rewards_distributor;
  }

  // redeem parameter validate function
  function _validRedeemParam(
    address redeemer,
    uint64[] calldata redeem_codes,
    uint256[] calldata values,
    Sig calldata signature
  ) private view returns (bool) {
    bytes32 messageHash = keccak256(abi.encodePacked(redeemer, redeem_codes, values));
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );

    return
      hasRole(
        "DISTRIBUTOR",
        ecrecover(ethSignedMessageHash, signature.v, signature.r, signature.s)
      );
  }

  // funciton
  // @param   redeemer: affiliates receiving rewards.
  // @param   redeem_codes: array of redeem code
  // @param   values: array of reward value
  // @param   signature: signature of distributor
  function redeemCode(
    address redeemer,
    uint64[] calldata redeem_codes,
    uint256[] calldata values,
    Sig calldata signature
  ) public {
    require(redeem_codes.length == values.length, "Affiliate:INVALID_PARAM");
    //  keccak256(abi.encodePacked(address, redeem_codes, values)) and make sure that the result of ECRECOVER is rewards_distributor
    require(
      _validRedeemParam(redeemer, redeem_codes, values, signature),
      "Affiliate:SIGNER_NOT_VALID"
    );

    uint256 total_value;
    for (uint256 i = 0; i < redeem_codes.length; i++) {
      require(!rewards_redeem[redeem_codes[i]], "Affiliate:ALREADY_REDEEMED");
      rewards_redeem[redeem_codes[i]] = true;
      total_value += values[i];
    }

    IERC20(erc20token).transferFrom(rewards_distributor, redeemer, total_value);
    emit Redeem(redeemer, redeem_codes, total_value);
  }
}
