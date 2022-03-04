import { Wallet } from "ethers";
import { AbiCoder, solidityKeccak256, splitSignature, toUtf8Bytes } from "ethers/lib/utils";
import { ethers } from "hardhat";

export interface Configuration {
  IssuerPrivateKey: string;
  ContractAddress: string;
  DomainName?: string;
}

export interface Signature {
  v: number;
  r: string;
  s: string;
}

export interface SignedClaim {
  nonce: number;
  target: string;
  amount: number;
  signature: Signature;
}

export class ClaimsManager {
  config: Configuration;

  constructor(config: Configuration) {
    this.config = config;
  }

  async generate_claim(target: string, amount: number): Promise<SignedClaim> {
    const issuerWallet = new Wallet(this.config.IssuerPrivateKey);
    const nonce: number = Date.now();

    let hash = solidityKeccak256(["uint", "address", "uint"], [nonce, target, amount]);
    const signature = await issuerWallet.signMessage(ethers.utils.arrayify(hash));

    const { v, r, s } = splitSignature(signature);

    return {
      signature: { v, r, s },
      target,
      amount,
      nonce,
    };
  }
}
