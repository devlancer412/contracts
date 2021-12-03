import { JsonRpcProvider, JsonRpcSigner } from "@ethersproject/providers";
import { BigNumber, providers, Signer, utils, Wallet } from "ethers";
import { _TypedDataEncoder } from "ethers/lib/utils";
import { ethers } from "hardhat";
import { SignerWithAddress } from "hardhat-deploy-ethers/dist/src/signers";
import Web3 from "web3";
import { ecsign } from "ethereumjs-util";

// export const signERC3009Transfer = async (from: SignerWithAddress, to: string, value: BigNumber) => {
//   const data = {
//     domain: {
//       name: "USD Coin (PoS)",
//       version: "1",
//       chainId: 137,
//       verifyingContract: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
//       salt: "0x"
//     },
//     types: {
//       TransferWithAuthorization: [
//         { name: "from", type: "address" },
//         { name: "to", type: "address" },
//         { name: "value", type: "uint256" },
//         { name: "validAfter", type: "uint256" },
//         { name: "validBefore", type: "uint256" },
//         { name: "nonce", type: "bytes32" },
//       ],
//     },
//     message: {
//       from: from.address,
//       to,
//       value,
//       validAfter: 0,
//       validBefore: 1838354613,
//       nonce: "0xeba1203047861cb0b425b7036a153d414127b37d018e6472a9efc3daa9a045bb",
//     },
//   };

//   const rawSig = await from._signTypedData(data.domain, data.types, data.message);
//   const sig = utils.splitSignature(rawSig);

//   const hash = _TypedDataEncoder.hash(data.domain, data.types, data.message);
//   const domainSeperator = _TypedDataEncoder.hashDomain(data.domain);
//   console.log("hash: " + hash);
//   console.log("domainSeperator: " + domainSeperator);

//   return {
//     msg: data.message,
//     sig,
//     data
//   };
// };

interface Signature {
  v: number;
  r: string;
  s: string;
}

function strip0x(v: string): string {
  return v.replace(/^0x/, "");
}

function hexStringFromBuffer(buf: Buffer): string {
  return "0x" + buf.toString("hex");
}

function bufferFromHexString(hex: string): Buffer {
  return Buffer.from(strip0x(hex), "hex");
}

function ecSign(digest: string, privateKey: string): Signature {
  const { v, r, s } = ecsign(bufferFromHexString(digest), bufferFromHexString(privateKey));

  return { v, r: hexStringFromBuffer(r), s: hexStringFromBuffer(s) };
}

function getDigest(
  domainSeparator: string,
  typeHash: string,
  types: string[],
  parameters: (string | number)[],
): string {
  const web3 = new Web3();
  const digest = web3.utils.keccak256(
    "0x1901" +
      strip0x(domainSeparator) +
      strip0x(web3.utils.keccak256(web3.eth.abi.encodeParameters(["bytes32", ...types], [typeHash, ...parameters]))),
  );
  return digest;
}

function signEIP712(
  domainSeparator: string,
  typeHash: string,
  types: string[],
  parameters: (string | number)[],
  privateKey: string,
): Signature {
  const digest = getDigest(domainSeparator, typeHash, types, parameters);
  return ecSign(digest, privateKey);
}

function signTransferAuthorization(
  from: string,
  to: string,
  value: number | string,
  validAfter: number | string,
  validBefore: number | string,
  nonce: string,
  privateKey: string,
): Signature {
  return signEIP712(
    "0x294369e003769a2d4d625e8a9ebebffa09ff70dd7c708497d8b56d2c2d199a19",
    "0x7c7c6cdb67a18743f49ec6fa9b35f50d52ed05cbed4cc592e13b44501c1a2267",
    ["address", "address", "uint256", "uint256", "uint256", "bytes32"],
    [from, to, value, validAfter, validBefore, nonce],
    privateKey,
  );
}

export const signERC3009Transfer = async (from: SignerWithAddress, to: string, value: BigNumber) => {
  const msg = {
    from: from.address,
    to,
    value,
    validAfter: 0,
    validBefore: 1838354613,
    nonce: "0xeba1203047861cb0b425b7036a153d414127b37d018e6472a9efc3daa9a045bb",
  };

  // const digest = getDigest(
  //   "0x294369e003769a2d4d625e8a9ebebffa09ff70dd7c708497d8b56d2c2d199a19",
  //   "0x7c7c6cdb67a18743f49ec6fa9b35f50d52ed05cbed4cc592e13b44501c1a2267",
  //   ["address", "address", "uint256", "uint256", "uint256", "bytes32"],
  //   [msg.from, msg.to, msg.value.toString(), msg.validAfter, msg.validBefore, msg.nonce],
  // );

  // const rawSig = await ethers.provider.send("eth_signTypedData_v4", [from.address, JSON.stringify(digest)]);

  // const rawSig = await ethers.provider.send("eth_sign", [
  //   from.address.toLowerCase(),
  //   utils.hexlify(utils.toUtf8Bytes(digest)),
  // ]);
  // const sig = utils.splitSignature(rawSig);

  // const digest = getDigest(
  //   "0x294369e003769a2d4d625e8a9ebebffa09ff70dd7c708497d8b56d2c2d199a19",
  //   "0x7c7c6cdb67a18743f49ec6fa9b35f50d52ed05cbed4cc592e13b44501c1a2267",
  //   ["address", "address", "uint256", "uint256", "uint256", "bytes32"],
  //   [msg.from, msg.to, msg.value.toString(), msg.validAfter, msg.validBefore, msg.nonce],
  // );

  // const web3 = new Web3(Web3.givenProvider || "http://localhost:8545");
  // const rawSig = await web3.eth.sign(digest, from.address);

  const sig = signTransferAuthorization(msg.from, msg.to, msg.value.toString(), msg.validAfter, msg.validBefore, msg.nonce, "69180802f8bf437e4c84246cb64979fd3f95e226d17c4496e9d826d38efbaf98")

  return {
    msg,
    sig,
  };
};
