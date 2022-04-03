// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "./AccessControl.sol";

contract GwitVesting is AccessControl {
  //Address of signer
  address public immutable signer;
  //Address of GWIT
  address public immutable gwit;
  //Address of pGWIT
  address public immutable pGwit;

  Term[] terms;

  mapping(uint256 => mapping(address => uint256)) public deposits;
  mapping(uint256 => mapping(address => uint256)) public releases;

  struct Term {
    uint32 start;
    uint32 duration;
    uint256 supply;
    uint256 released;
  }

  struct Sig {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  constructor(
    address signer_,
    address gwit_,
    address pGwit_
  ) {
    signer = signer_;
    gwit = gwit_;
    pGwit = pGwit_;
  }

  function register(
    uint256 id,
    uint256 amount,
    Sig calldata sig
  ) external whenNotPaused {
    require(_isParamValid(id, sig), "Invalid parameter");
    deposits[id][msg.sender] += amount;
    IERC20(pGwit).transferFrom(msg.sender, address(this), amount);
  }

  function claim(uint256 id, address recipient) external {
    uint256 amount = getClaimable(id, msg.sender);

    Term storage term = terms[id];
    term.released += amount;
    releases[id][msg.sender] += amount;

    IERC20(gwit).transfer(recipient, amount);
  }

  function getClaimable(uint256 id, address user) public view returns (uint256) {
    Term memory term = terms[id];
    uint32 currentTime = uint32(block.timestamp);
    if (currentTime <= term.start) {
      return 0;
    }
    uint256 amount = ((currentTime - term.start) * deposits[id][user]) /
      term.duration -
      releases[id][user];
    return amount;
  }

  function createTerm(
    uint32 start,
    uint32 duration,
    uint256 supply
  ) external onlyOwner {
    Term memory term = Term(start, duration, supply, 0);
    terms.push(term);
    IERC20(gwit).transferFrom(msg.sender, address(this), supply);
  }

  function updateTerm(
    uint256 id,
    uint32 start,
    uint32 duration,
    uint256 supply
  ) external onlyOwner {
    Term memory term = terms[id];

    if (block.timestamp < term.start) {
      term.start = start;
      term.duration = duration;
    }

    term.supply = supply;
    if (supply < term.supply) {
      IERC20(gwit).transfer(msg.sender, term.supply - supply);
    } else {
      IERC20(gwit).transferFrom(msg.sender, address(this), supply - term.supply);
    }

    terms[id] = term;
  }

  function _isParamValid(uint256 id, Sig calldata sig) private view returns (bool) {
    bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, id));
    bytes32 ethSignedMessageHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );
    return ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s) == signer;
  }
}
