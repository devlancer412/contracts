// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract QBuxVault is Ownable {
  IERC20 public erc20token;
  address public authorizer;
  uint256 exchange_rate;
  mapping(address => uint256) public last_signed_nonce;
  uint256 vaultUSD;

  event Deposit(
    address indexed account,
    uint256 indexed timestamp,
    uint256 usdValue,
    uint256 value
  );
  event Withdraw(
    address indexed account,
    uint256 indexed timestamp,
    uint256 usdValue,
    uint256 value
  );

  struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  function _validRedeemParam(
    address account,
    uint256 value,
    uint256 timestamp,
    Sig calldata signature
  ) private view returns (bool) {
    bytes32 messageHash = keccak256(abi.encodePacked(account, value, timestamp));
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );

    return ecrecover(ethSignedMessageHash, signature.v, signature.r, signature.s) == authorizer;
  }

  constructor(
    IERC20 _erc20token,
    address _authorizer,
    uint256 _exchange_rate
  ) {
    erc20token = _erc20token;
    authorizer = _authorizer;
    exchange_rate = _exchange_rate;
  }

  function setAuthorizer(address new_authorizer) public onlyOwner {
    authorizer = new_authorizer;
  }

  function setExchangeRate(uint256 _exchange_rate) public onlyOwner {
    exchange_rate = _exchange_rate;
  }

  function deposit(uint256 value_token) public {
    uint256 converted = value_token * exchange_rate;
    vaultUSD += value_token;

    emit Deposit(msg.sender, block.timestamp, value_token, converted);
  }

  function withdraw(
    address account,
    uint256 value_qbux,
    uint256 timestamp,
    Sig calldata signature
  ) public {
    require(block.timestamp - timestamp < 600, "QBuxVault:OLD_SIGNATURE");
    require(
      _validRedeemParam(account, value_qbux, timestamp, signature),
      "QBuxVault:INVALID_SIGNATURE"
    );

    uint256 converted = value_qbux / exchange_rate;
    vaultUSD -= converted;
    last_signed_nonce[account] = timestamp;
    emit Withdraw(account, timestamp, converted, value_qbux);
  }
}
