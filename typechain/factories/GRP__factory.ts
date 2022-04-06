/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import type { GRP, GRPInterface } from "../GRP";

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "_signer",
        type: "address",
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
        internalType: "uint256",
        name: "nonce",
        type: "uint256",
      },
      {
        indexed: true,
        internalType: "address",
        name: "target",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "Claimed",
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
        indexed: true,
        internalType: "address",
        name: "signer",
        type: "address",
      },
    ],
    name: "UpdateSigner",
    type: "event",
  },
  {
    inputs: [
      {
        components: [
          {
            internalType: "uint256",
            name: "nonce",
            type: "uint256",
          },
          {
            internalType: "address",
            name: "target",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "amount",
            type: "uint256",
          },
          {
            components: [
              {
                internalType: "bytes32",
                name: "r",
                type: "bytes32",
              },
              {
                internalType: "bytes32",
                name: "s",
                type: "bytes32",
              },
              {
                internalType: "uint8",
                name: "v",
                type: "uint8",
              },
            ],
            internalType: "struct GRP.Sig",
            name: "signature",
            type: "tuple",
          },
        ],
        internalType: "struct GRP.Claim",
        name: "claimData",
        type: "tuple",
      },
    ],
    name: "claim",
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
    name: "claimed",
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
    name: "renounceOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "reserves",
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
        internalType: "address",
        name: "newSigner",
        type: "address",
      },
    ],
    name: "setSigner",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "addr",
        type: "address",
      },
    ],
    name: "set_token_addr",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "signer",
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
    name: "token_addr",
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
];

const _bytecode =
  "0x608060405234801561001057600080fd5b50604051610c93380380610c9383398101604081905261002f9161013f565b61003833610047565b61004181610097565b5061016f565b600080546001600160a01b038381166001600160a01b0319831681178455604051919092169283917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a35050565b6000546001600160a01b031633146100f55760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604482015260640160405180910390fd5b600380546001600160a01b0319166001600160a01b0383169081179091556040517fc58fcf255cfb5f40bd578a618869378f650ef76609640fa0818a31e0c6e7102a90600090a250565b60006020828403121561015157600080fd5b81516001600160a01b038116811461016857600080fd5b9392505050565b610b158061017e6000396000f3fe608060405234801561001057600080fd5b506004361061009e5760003560e01c8063861798681161006657806386179868146101195780638b56b77a1461012c5780638da5cb5b1461013d578063dbe7e3bd1461014e578063f2fde38b1461018157600080fd5b8063238ac933146100a35780636c19e783146100d3578063715018a6146100e857806375172a8b146100f05780637991dbb214610106575b600080fd5b6003546100b6906001600160a01b031681565b6040516001600160a01b0390911681526020015b60405180910390f35b6100e66100e136600461095d565b610194565b005b6100e6610211565b6100f8610247565b6040519081526020016100ca565b6100e661011436600461095d565b6102cb565b6100e6610127366004610986565b610330565b6001546001600160a01b03166100b6565b6000546001600160a01b03166100b6565b61017161015c36600461099e565b60026020526000908152604090205460ff1681565b60405190151581526020016100ca565b6100e661018f36600461095d565b6104ed565b6000546001600160a01b031633146101c75760405162461bcd60e51b81526004016101be906109b7565b60405180910390fd5b600380546001600160a01b0319166001600160a01b0383169081179091556040517fc58fcf255cfb5f40bd578a618869378f650ef76609640fa0818a31e0c6e7102a90600090a250565b6000546001600160a01b0316331461023b5760405162461bcd60e51b81526004016101be906109b7565b6102456000610588565b565b6001546040516370a0823160e01b81523060048201526000916001600160a01b03169081906370a082319060240160206040518083038186803b15801561028d57600080fd5b505afa1580156102a1573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906102c591906109ec565b91505090565b6000546001600160a01b031633146102f55760405162461bcd60e51b81526004016101be906109b7565b6001546001600160a01b03161561030e5761030e610a05565b600180546001600160a01b0319166001600160a01b0392909216919091179055565b803560009081526002602052604090205460ff16156103895760405162461bcd60e51b815260206004820152601560248201527418db185a5b48185b1c9958591e4818db185a5b5959605a1b60448201526064016101be565b6000813561039d604084016020850161095d565b83604001356040516020016103d79392919092835260609190911b6bffffffffffffffffffffffff19166020830152603482015260540190565b6040516020818303038152906040528051906020012090506103fc82606001826105d8565b61043c5760405162461bcd60e51b8152602060048201526011602482015270696e76616c6964207369676e617475726560781b60448201526064016101be565b6001546001600160a01b031661047061045b604085016020860161095d565b6001600160a01b0383169060408601356106ba565b8235600090815260026020908152604091829020805460ff1916600117905561049d91850190850161095d565b6001600160a01b031683600001357f4ec90e965519d92681267467f775ada5bd214aa92c0dc93d90a5e880ce9ed02685604001356040516104e091815260200190565b60405180910390a3505050565b6000546001600160a01b031633146105175760405162461bcd60e51b81526004016101be906109b7565b6001600160a01b03811661057c5760405162461bcd60e51b815260206004820152602660248201527f4f776e61626c653a206e6577206f776e657220697320746865207a65726f206160448201526564647265737360d01b60648201526084016101be565b61058581610588565b50565b600080546001600160a01b038381166001600160a01b0319831681178455604051919092169283917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a35050565b604080517f19457468657265756d205369676e6564204d6573736167653a0a333200000000602080830191909152603c80830185905283518084039091018152605c909201835281519101206003546000926001600160a01b0390911690600190839061064b9060608901908901610a1b565b604080516000815260208181018084529490945260ff909216908201528735606082015290870135608082015260a0016020604051602081039080840390855afa15801561069d573d6000803e3d6000fd5b505050602060405103516001600160a01b03161491505092915050565b604080516001600160a01b038416602482015260448082018490528251808303909101815260649091019091526020810180516001600160e01b031663a9059cbb60e01b17905261070c908490610711565b505050565b6000610766826040518060400160405280602081526020017f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564815250856001600160a01b03166107e39092919063ffffffff16565b80519091501561070c57808060200190518101906107849190610a3e565b61070c5760405162461bcd60e51b815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e6044820152691bdd081cdd58d8d9595960b21b60648201526084016101be565b60606107f284846000856107fc565b90505b9392505050565b60608247101561085d5760405162461bcd60e51b815260206004820152602660248201527f416464726573733a20696e73756666696369656e742062616c616e636520666f6044820152651c8818d85b1b60d21b60648201526084016101be565b843b6108ab5760405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e747261637400000060448201526064016101be565b600080866001600160a01b031685876040516108c79190610a90565b60006040518083038185875af1925050503d8060008114610904576040519150601f19603f3d011682016040523d82523d6000602084013e610909565b606091505b5091509150610919828286610924565b979650505050505050565b606083156109335750816107f5565b8251156109435782518084602001fd5b8160405162461bcd60e51b81526004016101be9190610aac565b60006020828403121561096f57600080fd5b81356001600160a01b03811681146107f557600080fd5b600060c0828403121561099857600080fd5b50919050565b6000602082840312156109b057600080fd5b5035919050565b6020808252818101527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572604082015260600190565b6000602082840312156109fe57600080fd5b5051919050565b634e487b7160e01b600052600160045260246000fd5b600060208284031215610a2d57600080fd5b813560ff811681146107f557600080fd5b600060208284031215610a5057600080fd5b815180151581146107f557600080fd5b60005b83811015610a7b578181015183820152602001610a63565b83811115610a8a576000848401525b50505050565b60008251610aa2818460208701610a60565b9190910192915050565b6020815260008251806020840152610acb816040850160208701610a60565b601f01601f1916919091016040019291505056fea2646970667358221220e0e9e4265f9b22ad47998574993ebb154dc5d5d2802b312022d63373f029984864736f6c63430008090033";

type GRPConstructorParams = [signer?: Signer] | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (xs: GRPConstructorParams): xs is ConstructorParameters<typeof ContractFactory> =>
  xs.length > 1;

export class GRP__factory extends ContractFactory {
  constructor(...args: GRPConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  deploy(_signer: string, overrides?: Overrides & { from?: string | Promise<string> }): Promise<GRP> {
    return super.deploy(_signer, overrides || {}) as Promise<GRP>;
  }
  getDeployTransaction(
    _signer: string,
    overrides?: Overrides & { from?: string | Promise<string> },
  ): TransactionRequest {
    return super.getDeployTransaction(_signer, overrides || {});
  }
  attach(address: string): GRP {
    return super.attach(address) as GRP;
  }
  connect(signer: Signer): GRP__factory {
    return super.connect(signer) as GRP__factory;
  }
  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): GRPInterface {
    return new utils.Interface(_abi) as GRPInterface;
  }
  static connect(address: string, signerOrProvider: Signer | Provider): GRP {
    return new Contract(address, _abi, signerOrProvider) as GRP;
  }
}
