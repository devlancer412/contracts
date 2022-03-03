pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract FarmPool {
    IERC20 _token;
    bool token_set;

    mapping (address => uint) stakes;
    constructor() {
    }
    
    // run once
    function set_token_addr(address addr) public {
        assert(!token_set);
        _token = IERC20(addr);
        token_set = true;
    }

    function token_addr() public view returns(address) {
        return address(_token);
    }

}