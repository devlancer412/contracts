/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import type { Gem, GemInterface } from "../Gem";

const _abi = [
  {
    inputs: [
      {
        internalType: "string",
        name: "uri",
        type: "string",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "account",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "operator",
        type: "address",
      },
      {
        indexed: false,
        internalType: "bool",
        name: "approved",
        type: "bool",
      },
    ],
    name: "ApprovalForAll",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousOwner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "OwnershipTransferred",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "Paused",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "operator",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256[]",
        name: "ids",
        type: "uint256[]",
      },
      {
        indexed: false,
        internalType: "uint256[]",
        name: "values",
        type: "uint256[]",
      },
    ],
    name: "TransferBatch",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "operator",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "TransferSingle",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "value",
        type: "string",
      },
      {
        indexed: true,
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
    ],
    name: "URI",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "Unpaused",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "bool",
        name: "isOperator",
        type: "bool",
      },
    ],
    name: "UpdateOperator",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
    ],
    name: "balanceOf",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address[]",
        name: "accounts",
        type: "address[]",
      },
      {
        internalType: "uint256[]",
        name: "ids",
        type: "uint256[]",
      },
    ],
    name: "balanceOfBatch",
    outputs: [
      {
        internalType: "uint256[]",
        name: "",
        type: "uint256[]",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "burn",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
      {
        internalType: "uint256[]",
        name: "ids",
        type: "uint256[]",
      },
      {
        internalType: "uint256[]",
        name: "values",
        type: "uint256[]",
      },
    ],
    name: "burnBatch",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
      {
        internalType: "address",
        name: "operator",
        type: "address",
      },
    ],
    name: "isApprovedForAll",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "isOperator",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        internalType: "bytes",
        name: "data",
        type: "bytes",
      },
    ],
    name: "mint",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256[]",
        name: "ids",
        type: "uint256[]",
      },
      {
        internalType: "uint256[]",
        name: "amounts",
        type: "uint256[]",
      },
      {
        internalType: "bytes",
        name: "data",
        type: "bytes",
      },
    ],
    name: "mintBatch",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "owner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "pause",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "paused",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "renounceOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256[]",
        name: "ids",
        type: "uint256[]",
      },
      {
        internalType: "uint256[]",
        name: "amounts",
        type: "uint256[]",
      },
      {
        internalType: "bytes",
        name: "data",
        type: "bytes",
      },
    ],
    name: "safeBatchTransferFrom",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        internalType: "bytes",
        name: "data",
        type: "bytes",
      },
    ],
    name: "safeTransferFrom",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "operator",
        type: "address",
      },
      {
        internalType: "bool",
        name: "approved",
        type: "bool",
      },
    ],
    name: "setApprovalForAll",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        internalType: "bool",
        name: "isOperator_",
        type: "bool",
      },
    ],
    name: "setOperator",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "newuri",
        type: "string",
      },
    ],
    name: "setURI",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes4",
        name: "interfaceId",
        type: "bytes4",
      },
    ],
    name: "supportsInterface",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "transferOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "unpause",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "uri",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];

const _bytecode =
  "0x60806040523480156200001157600080fd5b50604051620025da380380620025da8339810160408190526200003491620001a6565b80620000408162000077565b506003805460ff19169055620000563362000090565b50336000908152600460205260409020805460ff19166001179055620002bf565b80516200008c906002906020840190620000ea565b5050565b600380546001600160a01b03838116610100818102610100600160a81b031985161790945560405193909204169182907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e090600090a35050565b828054620000f89062000282565b90600052602060002090601f0160209004810192826200011c576000855562000167565b82601f106200013757805160ff191683800117855562000167565b8280016001018555821562000167579182015b82811115620001675782518255916020019190600101906200014a565b506200017592915062000179565b5090565b5b808211156200017557600081556001016200017a565b634e487b7160e01b600052604160045260246000fd5b60006020808385031215620001ba57600080fd5b82516001600160401b0380821115620001d257600080fd5b818501915085601f830112620001e757600080fd5b815181811115620001fc57620001fc62000190565b604051601f8201601f19908116603f0116810190838211818310171562000227576200022762000190565b8160405282815288868487010111156200024057600080fd5b600093505b8284101562000264578484018601518185018701529285019262000245565b82841115620002765760008684830101525b98975050505050505050565b600181811c908216806200029757607f821691505b60208210811415620002b957634e487b7160e01b600052602260045260246000fd5b50919050565b61230b80620002cf6000396000f3fe608060405234801561001057600080fd5b50600436106101365760003560e01c80636b20c454116100b85780638da5cb5b1161007c5780638da5cb5b1461027e578063a22cb465146102a7578063e985e9c5146102ba578063f242432a146102f6578063f2fde38b14610309578063f5298aca1461031c57600080fd5b80636b20c454146102255780636d70f7ae14610238578063715018a61461025b578063731133e9146102635780638456cb591461027657600080fd5b80632eb2c2d6116100ff5780632eb2c2d6146101cc5780633f4ba83a146101df5780634e1273f4146101e7578063558a7297146102075780635c975abb1461021a57600080fd5b8062fdd58e1461013b57806301ffc9a71461016157806302fe5305146101845780630e89341c146101995780631f7fdffa146101b9575b600080fd5b61014e61014936600461174f565b61032f565b6040519081526020015b60405180910390f35b61017461016f36600461178f565b6103c6565b6040519015158152602001610158565b610197610192366004611854565b6103d7565b005b6101ac6101a73660046118a5565b610412565b604051610158919061190b565b6101976101c73660046119d3565b6104a6565b6101976101da366004611a6c565b6104e7565b61019761057e565b6101fa6101f5366004611b16565b6105b7565b6040516101589190611c1c565b610197610215366004611c2f565b6106e1565b60035460ff16610174565b610197610233366004611c6b565b610774565b610174610246366004611cdf565b60046020526000908152604090205460ff1681565b6101976107bc565b610197610271366004611cfa565b6107f6565b610197610831565b60035461010090046001600160a01b03166040516001600160a01b039091168152602001610158565b6101976102b5366004611c2f565b610868565b6101746102c8366004611d4f565b6001600160a01b03918216600090815260016020908152604080832093909416825291909152205460ff1690565b610197610304366004611d82565b610877565b610197610317366004611cdf565b6108bc565b61019761032a366004611de7565b61095a565b60006001600160a01b0383166103a05760405162461bcd60e51b815260206004820152602b60248201527f455243313135353a2062616c616e636520717565727920666f7220746865207a60448201526a65726f206164647265737360a81b60648201526084015b60405180910390fd5b506000908152602081815260408083206001600160a01b03949094168352929052205490565b60006103d18261099d565b92915050565b3360009081526004602052604090205460ff166104065760405162461bcd60e51b815260040161039790611e1a565b61040f816109ed565b50565b60606002805461042190611e42565b80601f016020809104026020016040519081016040528092919081815260200182805461044d90611e42565b801561049a5780601f1061046f5761010080835404028352916020019161049a565b820191906000526020600020905b81548152906001019060200180831161047d57829003601f168201915b50505050509050919050565b3360009081526004602052604090205460ff166104d55760405162461bcd60e51b815260040161039790611e1a565b6104e184848484610a00565b50505050565b6001600160a01b038516331480610503575061050385336102c8565b61056a5760405162461bcd60e51b815260206004820152603260248201527f455243313135353a207472616e736665722063616c6c6572206973206e6f74206044820152711bdddb995c881b9bdc88185c1c1c9bdd995960721b6064820152608401610397565b6105778585858585610b5a565b5050505050565b3360009081526004602052604090205460ff166105ad5760405162461bcd60e51b815260040161039790611e1a565b6105b5610d04565b565b6060815183511461061c5760405162461bcd60e51b815260206004820152602960248201527f455243313135353a206163636f756e747320616e6420696473206c656e677468604482015268040dad2e6dac2e8c6d60bb1b6064820152608401610397565b6000835167ffffffffffffffff811115610638576106386117b3565b604051908082528060200260200182016040528015610661578160200160208202803683370190505b50905060005b84518110156106d9576106ac85828151811061068557610685611e7d565b602002602001015185838151811061069f5761069f611e7d565b602002602001015161032f565b8282815181106106be576106be611e7d565b60209081029190910101526106d281611ea9565b9050610667565b509392505050565b6003546001600160a01b036101009091041633146107115760405162461bcd60e51b815260040161039790611ec4565b6001600160a01b038216600081815260046020908152604091829020805460ff19168515159081179091558251938452908301527f2ee52be9d342458b3d25e07faada7ff9bc06723b4aa24edb6321ac1316b8a9dd910160405180910390a15050565b6001600160a01b038316331480610790575061079083336102c8565b6107ac5760405162461bcd60e51b815260040161039790611ef9565b6107b7838383610d97565b505050565b6003546001600160a01b036101009091041633146107ec5760405162461bcd60e51b815260040161039790611ec4565b6105b56000610f25565b3360009081526004602052604090205460ff166108255760405162461bcd60e51b815260040161039790611e1a565b6104e184848484610f7f565b3360009081526004602052604090205460ff166108605760405162461bcd60e51b815260040161039790611e1a565b6105b5611055565b6108733383836110d0565b5050565b6001600160a01b038516331480610893575061089385336102c8565b6108af5760405162461bcd60e51b815260040161039790611ef9565b61057785858585856111b1565b6003546001600160a01b036101009091041633146108ec5760405162461bcd60e51b815260040161039790611ec4565b6001600160a01b0381166109515760405162461bcd60e51b815260206004820152602660248201527f4f776e61626c653a206e6577206f776e657220697320746865207a65726f206160448201526564647265737360d01b6064820152608401610397565b61040f81610f25565b6001600160a01b038316331480610976575061097683336102c8565b6109925760405162461bcd60e51b815260040161039790611ef9565b6107b78383836112ce565b60006001600160e01b03198216636cdb3d1360e11b14806109ce57506001600160e01b031982166303a24d0760e21b145b806103d157506301ffc9a760e01b6001600160e01b03198316146103d1565b805161087390600290602084019061169a565b6001600160a01b038416610a265760405162461bcd60e51b815260040161039790611f42565b8151835114610a475760405162461bcd60e51b815260040161039790611f83565b33610a57816000878787876113cf565b60005b8451811015610af257838181518110610a7557610a75611e7d565b6020026020010151600080878481518110610a9257610a92611e7d565b602002602001015181526020019081526020016000206000886001600160a01b03166001600160a01b031681526020019081526020016000206000828254610ada9190611fcb565b90915550819050610aea81611ea9565b915050610a5a565b50846001600160a01b031660006001600160a01b0316826001600160a01b03167f4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb8787604051610b43929190611fe3565b60405180910390a46105778160008787878761141a565b8151835114610b7b5760405162461bcd60e51b815260040161039790611f83565b6001600160a01b038416610ba15760405162461bcd60e51b815260040161039790612011565b33610bb08187878787876113cf565b60005b8451811015610c96576000858281518110610bd057610bd0611e7d565b602002602001015190506000858381518110610bee57610bee611e7d565b602090810291909101810151600084815280835260408082206001600160a01b038e168352909352919091205490915081811015610c3e5760405162461bcd60e51b815260040161039790612056565b6000838152602081815260408083206001600160a01b038e8116855292528083208585039055908b16825281208054849290610c7b908490611fcb565b9250508190555050505080610c8f90611ea9565b9050610bb3565b50846001600160a01b0316866001600160a01b0316826001600160a01b03167f4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb8787604051610ce6929190611fe3565b60405180910390a4610cfc81878787878761141a565b505050505050565b60035460ff16610d4d5760405162461bcd60e51b815260206004820152601460248201527314185d5cd8589b194e881b9bdd081c185d5cd95960621b6044820152606401610397565b6003805460ff191690557f5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa335b6040516001600160a01b03909116815260200160405180910390a1565b6001600160a01b038316610dbd5760405162461bcd60e51b8152600401610397906120a0565b8051825114610dde5760405162461bcd60e51b815260040161039790611f83565b6000339050610e01818560008686604051806020016040528060008152506113cf565b60005b8351811015610ec6576000848281518110610e2157610e21611e7d565b602002602001015190506000848381518110610e3f57610e3f611e7d565b602090810291909101810151600084815280835260408082206001600160a01b038c168352909352919091205490915081811015610e8f5760405162461bcd60e51b8152600401610397906120e3565b6000928352602083815260408085206001600160a01b038b1686529091529092209103905580610ebe81611ea9565b915050610e04565b5060006001600160a01b0316846001600160a01b0316826001600160a01b03167f4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb8686604051610f17929190611fe3565b60405180910390a450505050565b600380546001600160a01b03838116610100818102610100600160a81b031985161790945560405193909204169182907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e090600090a35050565b6001600160a01b038416610fa55760405162461bcd60e51b815260040161039790611f42565b33610fc581600087610fb688611585565b610fbf88611585565b876113cf565b6000848152602081815260408083206001600160a01b038916845290915281208054859290610ff5908490611fcb565b909155505060408051858152602081018590526001600160a01b0380881692600092918516917fc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62910160405180910390a4610577816000878787876115d0565b60035460ff161561109b5760405162461bcd60e51b815260206004820152601060248201526f14185d5cd8589b194e881c185d5cd95960821b6044820152606401610397565b6003805460ff191660011790557f62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258610d7a3390565b816001600160a01b0316836001600160a01b031614156111445760405162461bcd60e51b815260206004820152602960248201527f455243313135353a2073657474696e6720617070726f76616c20737461747573604482015268103337b91039b2b63360b91b6064820152608401610397565b6001600160a01b03838116600081815260016020908152604080832094871680845294825291829020805460ff191686151590811790915591519182527f17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31910160405180910390a3505050565b6001600160a01b0384166111d75760405162461bcd60e51b815260040161039790612011565b336111e7818787610fb688611585565b6000848152602081815260408083206001600160a01b038a168452909152902054838110156112285760405162461bcd60e51b815260040161039790612056565b6000858152602081815260408083206001600160a01b038b8116855292528083208785039055908816825281208054869290611265908490611fcb565b909155505060408051868152602081018690526001600160a01b03808916928a821692918616917fc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62910160405180910390a46112c58288888888886115d0565b50505050505050565b6001600160a01b0383166112f45760405162461bcd60e51b8152600401610397906120a0565b336113238185600061130587611585565b61130e87611585565b604051806020016040528060008152506113cf565b6000838152602081815260408083206001600160a01b0388168452909152902054828110156113645760405162461bcd60e51b8152600401610397906120e3565b6000848152602081815260408083206001600160a01b03898116808652918452828520888703905582518981529384018890529092908616917fc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62910160405180910390a45050505050565b60035460ff16156114155760405162461bcd60e51b815260206004820152601060248201526f14185d5cd8589b194e881c185d5cd95960821b6044820152606401610397565b610cfc565b6001600160a01b0384163b15610cfc5760405163bc197c8160e01b81526001600160a01b0385169063bc197c819061145e9089908990889088908890600401612127565b602060405180830381600087803b15801561147857600080fd5b505af19250505080156114a8575060408051601f3d908101601f191682019092526114a591810190612185565b60015b611555576114b46121a2565b806308c379a014156114ee57506114c96121be565b806114d457506114f0565b8060405162461bcd60e51b8152600401610397919061190b565b505b60405162461bcd60e51b815260206004820152603460248201527f455243313135353a207472616e7366657220746f206e6f6e20455243313135356044820152732932b1b2b4bb32b91034b6b83632b6b2b73a32b960611b6064820152608401610397565b6001600160e01b0319811663bc197c8160e01b146112c55760405162461bcd60e51b815260040161039790612248565b604080516001808252818301909252606091600091906020808301908036833701905050905082816000815181106115bf576115bf611e7d565b602090810291909101015292915050565b6001600160a01b0384163b15610cfc5760405163f23a6e6160e01b81526001600160a01b0385169063f23a6e61906116149089908990889088908890600401612290565b602060405180830381600087803b15801561162e57600080fd5b505af192505050801561165e575060408051601f3d908101601f1916820190925261165b91810190612185565b60015b61166a576114b46121a2565b6001600160e01b0319811663f23a6e6160e01b146112c55760405162461bcd60e51b815260040161039790612248565b8280546116a690611e42565b90600052602060002090601f0160209004810192826116c8576000855561170e565b82601f106116e157805160ff191683800117855561170e565b8280016001018555821561170e579182015b8281111561170e5782518255916020019190600101906116f3565b5061171a92915061171e565b5090565b5b8082111561171a576000815560010161171f565b80356001600160a01b038116811461174a57600080fd5b919050565b6000806040838503121561176257600080fd5b61176b83611733565b946020939093013593505050565b6001600160e01b03198116811461040f57600080fd5b6000602082840312156117a157600080fd5b81356117ac81611779565b9392505050565b634e487b7160e01b600052604160045260246000fd5b601f8201601f1916810167ffffffffffffffff811182821017156117ef576117ef6117b3565b6040525050565b600067ffffffffffffffff831115611810576118106117b3565b604051611827601f8501601f1916602001826117c9565b80915083815284848401111561183c57600080fd5b83836020830137600060208583010152509392505050565b60006020828403121561186657600080fd5b813567ffffffffffffffff81111561187d57600080fd5b8201601f8101841361188e57600080fd5b61189d848235602084016117f6565b949350505050565b6000602082840312156118b757600080fd5b5035919050565b6000815180845260005b818110156118e4576020818501810151868301820152016118c8565b818111156118f6576000602083870101525b50601f01601f19169290920160200192915050565b6020815260006117ac60208301846118be565b600067ffffffffffffffff821115611938576119386117b3565b5060051b60200190565b600082601f83011261195357600080fd5b813560206119608261191e565b60405161196d82826117c9565b83815260059390931b850182019282810191508684111561198d57600080fd5b8286015b848110156119a85780358352918301918301611991565b509695505050505050565b600082601f8301126119c457600080fd5b6117ac838335602085016117f6565b600080600080608085870312156119e957600080fd5b6119f285611733565b9350602085013567ffffffffffffffff80821115611a0f57600080fd5b611a1b88838901611942565b94506040870135915080821115611a3157600080fd5b611a3d88838901611942565b93506060870135915080821115611a5357600080fd5b50611a60878288016119b3565b91505092959194509250565b600080600080600060a08688031215611a8457600080fd5b611a8d86611733565b9450611a9b60208701611733565b9350604086013567ffffffffffffffff80821115611ab857600080fd5b611ac489838a01611942565b94506060880135915080821115611ada57600080fd5b611ae689838a01611942565b93506080880135915080821115611afc57600080fd5b50611b09888289016119b3565b9150509295509295909350565b60008060408385031215611b2957600080fd5b823567ffffffffffffffff80821115611b4157600080fd5b818501915085601f830112611b5557600080fd5b81356020611b628261191e565b604051611b6f82826117c9565b83815260059390931b8501820192828101915089841115611b8f57600080fd5b948201945b83861015611bb457611ba586611733565b82529482019490820190611b94565b96505086013592505080821115611bca57600080fd5b50611bd785828601611942565b9150509250929050565b600081518084526020808501945080840160005b83811015611c1157815187529582019590820190600101611bf5565b509495945050505050565b6020815260006117ac6020830184611be1565b60008060408385031215611c4257600080fd5b611c4b83611733565b915060208301358015158114611c6057600080fd5b809150509250929050565b600080600060608486031215611c8057600080fd5b611c8984611733565b9250602084013567ffffffffffffffff80821115611ca657600080fd5b611cb287838801611942565b93506040860135915080821115611cc857600080fd5b50611cd586828701611942565b9150509250925092565b600060208284031215611cf157600080fd5b6117ac82611733565b60008060008060808587031215611d1057600080fd5b611d1985611733565b93506020850135925060408501359150606085013567ffffffffffffffff811115611d4357600080fd5b611a60878288016119b3565b60008060408385031215611d6257600080fd5b611d6b83611733565b9150611d7960208401611733565b90509250929050565b600080600080600060a08688031215611d9a57600080fd5b611da386611733565b9450611db160208701611733565b93506040860135925060608601359150608086013567ffffffffffffffff811115611ddb57600080fd5b611b09888289016119b3565b600080600060608486031215611dfc57600080fd5b611e0584611733565b95602085013595506040909401359392505050565b6020808252600e908201526d496e76616c69642061636365737360901b604082015260600190565b600181811c90821680611e5657607f821691505b60208210811415611e7757634e487b7160e01b600052602260045260246000fd5b50919050565b634e487b7160e01b600052603260045260246000fd5b634e487b7160e01b600052601160045260246000fd5b6000600019821415611ebd57611ebd611e93565b5060010190565b6020808252818101527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604082015260600190565b60208082526029908201527f455243313135353a2063616c6c6572206973206e6f74206f776e6572206e6f7260408201526808185c1c1c9bdd995960ba1b606082015260800190565b60208082526021908201527f455243313135353a206d696e7420746f20746865207a65726f206164647265736040820152607360f81b606082015260800190565b60208082526028908201527f455243313135353a2069647320616e6420616d6f756e7473206c656e677468206040820152670dad2e6dac2e8c6d60c31b606082015260800190565b60008219821115611fde57611fde611e93565b500190565b604081526000611ff66040830185611be1565b82810360208401526120088185611be1565b95945050505050565b60208082526025908201527f455243313135353a207472616e7366657220746f20746865207a65726f206164604082015264647265737360d81b606082015260800190565b6020808252602a908201527f455243313135353a20696e73756666696369656e742062616c616e636520666f60408201526939103a3930b739b332b960b11b606082015260800190565b60208082526023908201527f455243313135353a206275726e2066726f6d20746865207a65726f206164647260408201526265737360e81b606082015260800190565b60208082526024908201527f455243313135353a206275726e20616d6f756e7420657863656564732062616c604082015263616e636560e01b606082015260800190565b6001600160a01b0386811682528516602082015260a06040820181905260009061215390830186611be1565b82810360608401526121658186611be1565b9050828103608084015261217981856118be565b98975050505050505050565b60006020828403121561219757600080fd5b81516117ac81611779565b600060033d11156121bb5760046000803e5060005160e01c5b90565b600060443d10156121cc5790565b6040516003193d81016004833e81513d67ffffffffffffffff81602484011181841117156121fc57505050505090565b82850191508151818111156122145750505050505090565b843d870101602082850101111561222e5750505050505090565b61223d602082860101876117c9565b509095945050505050565b60208082526028908201527f455243313135353a204552433131353552656365697665722072656a656374656040820152676420746f6b656e7360c01b606082015260800190565b6001600160a01b03868116825285166020820152604081018490526060810183905260a0608082018190526000906122ca908301846118be565b97965050505050505056fea264697066735822122028e19798be15650e4f3d01408776a49f1f61be79b7fbd971de9d526b73f83f0a64736f6c63430008090033";

type GemConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: GemConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class Gem__factory extends ContractFactory {
  constructor(...args: GemConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  deploy(
    uri: string,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<Gem> {
    return super.deploy(uri, overrides || {}) as Promise<Gem>;
  }
  getDeployTransaction(
    uri: string,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(uri, overrides || {});
  }
  attach(address: string): Gem {
    return super.attach(address) as Gem;
  }
  connect(signer: Signer): Gem__factory {
    return super.connect(signer) as Gem__factory;
  }
  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): GemInterface {
    return new utils.Interface(_abi) as GemInterface;
  }
  static connect(address: string, signerOrProvider: Signer | Provider): Gem {
    return new Contract(address, _abi, signerOrProvider) as Gem;
  }
}
