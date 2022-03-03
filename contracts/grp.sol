/**
    Game Rewards Pool or (GRP) handles the claiming of rewards from the game to the chain
    It facilitates $GALL to $GWIT conversion
 */
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract GRP is Ownable {
    address _token;
    mapping (uint => bool) public claimed;
    
    event Claimed(uint indexed nonce, address indexed target, uint amount);
    struct Claim {
        uint nonce;
        address target;
        uint amount;

        Sig signature;
    }

    address public signer;
    event UpdateSigner(address indexed signer);
    struct Sig {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    constructor(address _signer) {
        setSigner(_signer);
    }

    function setSigner(address newSigner) public onlyOwner {
        signer = newSigner;
        emit UpdateSigner(signer);
    }

    function authorize(Sig calldata sig, bytes32 messageHash) internal view returns(bool) {
        bytes32 ethSignedMessageHash = keccak256(
        abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        return ecrecover(ethSignedMessageHash, sig.v, sig.r, sig.s) == signer;
    }

    // run once
    function set_token_addr(address addr) public onlyOwner {
        assert(_token == address(0));
        _token = addr;
    }

    function token_addr() public view returns(address) {
        return _token;
    }

    function claim(Claim calldata claimData) public {
        // Validation
        require(!claimed[claimData.nonce], "claim already claimed");
        
        bytes32 messageHash = keccak256(abi.encodePacked(claimData.nonce, claimData.target, claimData.amount));
        require(authorize(claimData.signature, messageHash), "invalid signature");

        // Transfer
        IERC20 token = IERC20(_token);
        token.transfer(claimData.target, claimData.amount);

        // Cleanup
        claimed[claimData.nonce] = true;
        emit Claimed(claimData.nonce, claimData.target, claimData.amount);
    } 

    function reserves() public view returns(uint) {
        IERC20 token = IERC20(_token);
        return token.balanceOf(address(this));
    }

}

