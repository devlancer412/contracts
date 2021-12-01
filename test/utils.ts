import { BigNumber, utils } from "ethers";
import { SignerWithAddress } from "hardhat-deploy-ethers/dist/src/signers";

export const signERC3009Transfer = async (from: SignerWithAddress, to: string, value: BigNumber) => {
  const data = {
    domain: {
      name: "USD Coin (PoS)",
      version: "1",
      chainId: 137,
      verifyingContract: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    },
    types: {
      TransferWithAuthorization: [
        { name: "from", type: "address" },
        { name: "to", type: "address" },
        { name: "value", type: "uint256" },
        { name: "validAfter", type: "uint256" },
        { name: "validBefore", type: "uint256" },
        { name: "nonce", type: "bytes32" },
      ],
    },
    message: {
      from: from.address,
      to,
      value,
      validAfter: 0,
      validBefore: 1838354613,
      nonce: "0xeba1203047861cb0b425b7036a153d414127b37d018e6472a9efc3daa9a045bb",
    },
  };

  const rawSig = await from._signTypedData(data.domain, data.types, data.message);
  const sig = utils.splitSignature(rawSig);

  return {
    msg: data.message,
    sig,
  };
};