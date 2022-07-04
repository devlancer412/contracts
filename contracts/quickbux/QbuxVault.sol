// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";

contract QBuxVault is Ownable {
  address public erc20token;
  IUniswapV2Router01 public router;
  address public authorizer;
  uint256 exchange_rate;
  mapping(address => uint256) public last_signed_nonce;
  mapping(address => bool) public approvedToken;
  uint256 vaultUSD;

  address vaultFees;
  uint256 withdrawPercentage;

  uint256 private constant _MAX_UINT256 = type(uint256).max;

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
    address _erc20token,
    address _authorizer,
    address _router,
    uint256 _exchange_rate
  ) {
    erc20token = _erc20token;
    authorizer = _authorizer;
    router = IUniswapV2Router01(_router);
    exchange_rate = _exchange_rate;

    IERC20(_erc20token).approve(address(_router), _MAX_UINT256);
  }

  function setAuthorizer(address new_authorizer) public onlyOwner {
    authorizer = new_authorizer;
  }

  function setExchangeRate(uint256 _exchange_rate) public onlyOwner {
    exchange_rate = _exchange_rate;
  }

  function setApprovedToken(address token, bool approve) public onlyOwner {
    approvedToken[token] = approve;
    if (approve) {
      IERC20(token).approve(address(router), _MAX_UINT256);
    } else {
      IERC20(token).approve(address(router), 0);
    }
  }

  function setWithdrawFees(address vault, uint256 fee) public onlyOwner {
    vaultFees = vault;
    withdrawPercentage = fee;
  }

  function deposit(address token, uint256 value_token) public onlyApprovedToken(token) {
    uint256 converted = value_token * exchange_rate;
    vaultUSD += value_token;

    if (token == erc20token) {
      IERC20(token).transferFrom(msg.sender, address(this), value_token);
    } else {
      address[] memory path = new address[](2);
      path[0] = token;
      path[1] = erc20token;

      uint256[] memory amounts = router.getAmountsIn(value_token, path);

      IERC20(token).transferFrom(msg.sender, address(this), amounts[0]);
      router.swapTokensForExactTokens(value_token, amounts[0], path, address(this), _MAX_UINT256);
    }

    emit Deposit(msg.sender, block.timestamp, value_token, converted);
  }

  function withdraw(
    address token,
    address account,
    uint256 value_qbux,
    uint256 timestamp,
    Sig calldata signature
  ) public onlyApprovedToken(token) {
    require(block.timestamp - timestamp < 600, "QBuxVault:OLD_SIGNATURE");
    require(
      _validRedeemParam(account, value_qbux, timestamp, signature),
      "QBuxVault:INVALID_SIGNATURE"
    );
    require(last_signed_nonce[account] != timestamp, "QBuxVault:NONCE_USED");

    uint256 converted = value_qbux / exchange_rate;
    if (withdrawPercentage > 0) {
      converted -= converted * (withdrawPercentage / 10000);
    }

    vaultUSD -= converted;
    last_signed_nonce[account] = timestamp;

    if (token == erc20token) {
      IERC20(token).transfer(account, converted);
    } else {
      address[] memory path = new address[](2);
      path[0] = erc20token;
      path[1] = token;

      router.swapExactTokensForTokens(converted, 0, path, account, _MAX_UINT256);
    }

    emit Withdraw(account, timestamp, converted, value_qbux);
  }

  modifier onlyApprovedToken(address token) {
    require(approvedToken[token], "QBuxValut:TOKEN_NOT_APPROVED");
    _;
  }
}
