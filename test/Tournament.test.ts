import { expect } from "./chai-setup";
import { BigNumber, constants, utils, Wallet } from "ethers";
import hre, { deployments } from "hardhat";
import { MockUsdc__factory, Rooster__factory, Scholarship__factory, Tournament__factory } from "../types";
import {
  advanceTime,
  advanceTimeAndBlock,
  fromBN,
  getRandomNumberBetween,
  getTime,
  setTime,
  Ship,
  toWei,
} from "../utils";
import { arrayify, keccak256, solidityKeccak256, splitSignature } from "ethers/lib/utils";
import MerkleTree from "merkletreejs";

let scaffold: Awaited<ReturnType<typeof setup>>;

describe("Tournament test 🏆", () => {
  before(async () => {
    // Create initial fixture here
    await setup();
  });

  describe("A typical tournament flow", () => {
    let users: User[];
    let rankingTree: RankingTree;
    let gameId: number;

    before(async () => {
      scaffold = await setup();
    });

    it("Creates game", async () => {
      const { tournament } = scaffold;
      const time = await getTime();

      const promi = tournament.createGame({
        checkinStartTime: time + 1000,
        checkinEndTime: time + 2000,
        gameStartTime: time + 3000,
        gameEndTime: time + 4000,
        minRoosters: 10,
        maxRoosters: 110,
        roosters: 0,
        entranceFee: toWei(100, 6),
        balance: 0,
        rankingRoot: constants.HashZero,
        distributions: [0, 5000, 3000, 1000, 1000],
        fee: 1000,
        requirementId: 0,
        state: 0,
      });
      await expect(promi)
        .to.emit(tournament, "CreateGame")
        .withArgs(0, 0, scaffold.accounts.deployer.address);

      gameId = await currentGameId();
      const game = await tournament.games(gameId);
      expect(gameId).to.eq(0);
      expect(game.rankingRoot).to.eq(constants.HashZero);
      expect(game.balance).to.eq(0);
      expect(game.state).to.eq(State.ONGOING);
      expect(await tournament.getDistributionsSum(gameId)).to.eq(10000);
      expect(await tournament.totalGames()).to.eq(1);
    });

    it("Registers 3 roosters", async () => {
      const {
        tournament,
        usdc,
        accounts: { alice },
      } = scaffold;

      // Warp to check in time
      await warpTo(gameId, "CS");

      // Mint roosters and usdc
      const roosterIds = await mintRoosters(alice.address, 3);
      const sig = await sign(gameId, roosterIds);
      await usdc.set(alice.address, toWei(100, 6).mul(3));
      await usdc.connect(alice).approve(tournament.address, constants.MaxUint256);

      // Register
      const promi = tournament.connect(alice).register(gameId, roosterIds, sig);
      await expect(promi).to.emit(tournament, "RegisterGame").withArgs(gameId, roosterIds, alice.address);

      // Assert
      const game = await tournament.games(gameId);
      expect(game.roosters).to.eq(3);
      expect(game.balance).to.eq(toWei(100, 6).mul(3));
      expect(await usdc.balanceOf(tournament.address)).to.eq(toWei(100, 6).mul(3));
      expect(await tournament.batchQuery(gameId, roosterIds)).to.eql(new Array(3).fill(maxUint32));
    });

    it("Pauses game", async () => {
      const { tournament, accounts } = scaffold;

      const promi = tournament.connect(accounts.deployer).setGame(Action.PAUSE, gameId, zeroBytes32, []);
      await expect(promi).to.emit(tournament, "SetGame").withArgs(gameId, Action.PAUSE);

      const game = await tournament.games(gameId);
      expect(game.state).to.eq(State.PAUSED);
    });

    it("Reverts if paused again", async () => {
      await expect(scaffold.tournament.setGame(Action.PAUSE, gameId, zeroBytes32, [])).to.be.revertedWith(
        "Not ongoing",
      );
    });

    it("Reverts on register when paused", async () => {
      await expect(scaffold.tournament.register(gameId, [1], emptySig)).to.be.revertedWith(
        "Paused or Cancelled",
      );
    });

    it("Unpauses game", async () => {
      const { tournament } = scaffold;
      const promi = tournament.setGame(Action.UNPAUSE, gameId, zeroBytes32, []);
      await expect(promi).to.emit(tournament, "SetGame").withArgs(gameId, Action.UNPAUSE);

      const game = await tournament.games(gameId);
      expect(game.state).to.eq(State.ONGOING);
    });

    it("Registers 100 roosters", async () => {
      const { tournament, usdc } = scaffold;

      const allRoosterIds: number[] = [];
      const amountPerUser = 2;
      users = await User.createRandomUsers(100 / amountPerUser);

      for (const user of users) {
        // Mint roosters and usdc
        const roosterIds = await user.getRoosters(amountPerUser);
        const sig = await sign(gameId, roosterIds);
        await scaffold.rooster.connect(user.wallet).setApprovalForAll(tournament.address, true);
        await usdc.set(user.address, toWei(100, 6).mul(amountPerUser));
        await usdc.connect(user.wallet).approve(tournament.address, constants.MaxUint256);
        allRoosterIds.push(...roosterIds);

        // Register
        const promi = tournament.connect(user.wallet).register(gameId, roosterIds, sig);
        await expect(promi).to.emit(tournament, "RegisterGame").withArgs(gameId, roosterIds, user.address);
      }

      // Assert
      const game = await tournament.games(gameId);
      expect(game.roosters).to.eq(103);
      expect(game.balance).to.eq(toWei(100, 6).mul(game.roosters));
      expect(await usdc.balanceOf(tournament.address)).to.eq(toWei(100, 6).mul(game.roosters));
      expect(await tournament.batchQuery(gameId, allRoosterIds)).to.eql(new Array(100).fill(maxUint32));
    });

    it("Ends game", async () => {
      const { tournament } = scaffold;

      await warpTo(gameId, "GE");

      const winners = [1, 3, 4, 5];
      rankingTree = new RankingTree(gameId, winners);

      const promi = tournament.setGame(Action.END, gameId, rankingTree.root, []);
      await expect(promi).to.emit(tournament, "SetGame").withArgs(gameId, Action.END);

      const game = await tournament.games(gameId);
      expect(game.rankingRoot).to.eq(rankingTree.root);
    });

    it("Claims prize", async () => {
      const { tournament, usdc, accounts } = scaffold;

      const amount = (await usdc.balanceOf(tournament.address)).div(2); // 50%
      const fee = amount.div(10); // 10%

      const promi = tournament
        .connect(accounts.alice)
        .claimReward(gameId, [1], [1], [rankingTree.getProof(1)], accounts.alice.address);
      await expect(promi)
        .to.emit(tournament, "ClaimReward")
        .withArgs(gameId, [1], amount, accounts.alice.address);

      const game = await tournament.games(gameId);
      expect(game.balance).to.eq(amount);
      expect(await usdc.balanceOf(accounts.alice.address)).to.eq(amount.sub(fee));
      expect(await usdc.balanceOf(accounts.vault.address)).to.eq(fee);
      expect(await usdc.balanceOf(tournament.address)).to.eq(amount);
      expect(await tournament.roosters(gameId, 1)).to.eq(1);
    });

    it("Fails to claim if already claimed", async () => {
      await expect(
        scaffold.tournament
          .connect(scaffold.accounts.alice)
          .claimReward(gameId, [1], [1], [rankingTree.getProof(1)], scaffold.accounts.alice.address),
      ).to.be.revertedWith("Already claimed or not registered");
    });

    it("Fails to claim without valid proof", async () => {
      await expect(
        scaffold.tournament
          .connect(scaffold.accounts.alice)
          .claimReward(gameId, [2], [1], [rankingTree.getProof(1)], scaffold.accounts.alice.address),
      ).to.be.revertedWith("Invalid proof");
      await expect(
        scaffold.tournament
          .connect(scaffold.accounts.alice)
          .claimReward(gameId, [1], [1], [rankingTree.getProof(3)], scaffold.accounts.alice.address),
      ).to.be.revertedWith("Invalid proof");
    });

    it("Fails to claim if non-owner claims", async () => {
      await expect(
        scaffold.tournament
          .connect(scaffold.accounts.bob)
          .claimReward(gameId, [1], [1], [rankingTree.getProof(1)], scaffold.accounts.bob.address),
      ).to.be.revertedWith("Not owner");
    });

    it("Claims multiple prizes", async () => {
      const { tournament, usdc, accounts } = scaffold;
      let game = await tournament.games(gameId);

      const totalAmount = game.entranceFee.mul(game.roosters);
      const amount = totalAmount.mul(3).div(10).add(totalAmount.mul(1).div(10)); // 30% + 10%
      const fee = amount.div(10); // 10%

      const gameBalanceBefore = game.balance;
      const vaultBalanceBefore = await usdc.balanceOf(accounts.vault.address);

      const promi = tournament
        .connect(users[0].wallet)
        .claimReward(
          gameId,
          [3, 4],
          [2, 3],
          [rankingTree.getProof(3), rankingTree.getProof(4)],
          users[0].address,
        );
      await expect(promi)
        .to.emit(tournament, "ClaimReward")
        .withArgs(gameId, [3, 4], amount, users[0].address);

      game = await tournament.games(gameId);
      expect(game.balance).to.eq(gameBalanceBefore.sub(amount));
      expect(await usdc.balanceOf(users[0].address)).to.eq(amount.sub(fee));
      expect(await usdc.balanceOf(accounts.vault.address)).to.eq(vaultBalanceBefore.add(fee));
      expect(await tournament.batchQuery(gameId, [3, 4])).to.eql([2, 3]);
    });

    it("Reverts to collect expired reward before expiration", async () => {
      await expect(scaffold.tournament.withdrawExpiredRewards(gameId)).to.be.revertedWith("Not expired");
    });

    it("Collects expired rewards", async () => {
      const { tournament, usdc, accounts } = scaffold;
      let game = await tournament.games(gameId);
      const gameBalanceBefore = game.balance;
      const vaultBalanceBefore = await usdc.balanceOf(accounts.vault.address);

      await warpTo(gameId, "ET");

      const promi = tournament.connect(accounts.deployer).withdrawExpiredRewards(gameId);
      await expect(promi).to.emit(tournament, "WithdrawExpiredRewards").withArgs(gameId, gameBalanceBefore);

      game = await tournament.games(gameId);
      expect(game.balance).to.eq(0);
      expect(await usdc.balanceOf(tournament.address)).to.eq(0);
      expect(await usdc.balanceOf(accounts.vault.address)).to.eq(vaultBalanceBefore.add(gameBalanceBefore));
    });

    it("Fails to claim after expiration", async () => {
      await expect(
        scaffold.tournament
          .connect(users[1].wallet)
          .claimReward(gameId, [5], [4], [rankingTree.getProof(5)], users[1].address),
      ).to.be.revertedWith("Expired");
    });
  });

  describe("A cancelled tournament flow", () => {
    let users: User[];
    let gameId: number;

    before(async () => {
      scaffold = await setup();
      users = await User.createRandomUsers(10);
    });

    before(async () => {
      const { tournament } = scaffold;
      const time = await getTime();

      await tournament.createGame({
        checkinStartTime: time + 1000,
        checkinEndTime: time + 2000,
        gameStartTime: time + 3000,
        gameEndTime: time + 4000,
        minRoosters: 10,
        maxRoosters: 100,
        roosters: 0,
        entranceFee: toWei(100, 6),
        balance: 0,
        rankingRoot: constants.HashZero,
        distributions: [0, 5000, 3000, 1000, 1000],
        fee: 1000,
        requirementId: 0,
        state: 0,
      });
      gameId = await currentGameId();

      await warpTo(gameId, "CS", 10);
    });

    it("Registers 100 roosters", async () => {
      const { tournament, usdc } = scaffold;
      const allRoosterIds: number[] = [];
      const amountPerUser = 10;

      {
        const game = await tournament.games(gameId);
        for (const [index, user] of users.entries()) {
          const roosterIds = await user.getRoosters(amountPerUser);
          const sig = await sign(gameId, roosterIds);
          allRoosterIds.push(...roosterIds);

          // Some users have their roosters lended
          if (index % 3 == 0) {
            const roostersToLend = roosterIds.slice(0, amountPerUser / 2);
            const scholars = (await User.createRandomUsers(roostersToLend.length, false)).map(
              (wallet) => wallet.address,
            );
            await scaffold.rooster.connect(user.wallet).setApprovalForAll(scaffold.scholarship.address, true);
            await scaffold.scholarship.connect(user.wallet).bulkLendNFT(roostersToLend, scholars);
          }

          await usdc.set(user.address, game.entranceFee.mul(amountPerUser));
          await usdc.connect(user.wallet).approve(tournament.address, constants.MaxUint256);
          await expect(tournament.connect(user.wallet).register(gameId, roosterIds, sig))
            .to.emit(tournament, "RegisterGame")
            .withArgs(gameId, roosterIds, user.address);
        }
      }

      {
        const game = await tournament.games(gameId);
        expect(game.roosters).to.eq(100);
        expect(game.balance).to.eq(game.entranceFee.mul(game.roosters));
        expect(await usdc.balanceOf(tournament.address)).to.eq(game.entranceFee.mul(game.roosters));
        expect(await tournament.batchQuery(gameId, allRoosterIds)).to.eql(new Array(100).fill(maxUint32));
      }
    });

    it("Cancels game", async () => {
      const { tournament } = scaffold;
      const promi = tournament.setGame(Action.CANCEL, gameId, zeroBytes32, []);
      await expect(promi).to.emit(tournament, "SetGame").withArgs(gameId, Action.CANCEL);

      const game = await tournament.games(gameId);
      expect(game.state).to.eq(State.CANCELLED);
    });

    it("Claims refund", async () => {
      const { tournament } = scaffold;

      const allRoosters: number[] = [];
      const { entranceFee } = await tournament.games(gameId);
      for (const user of users) {
        const amount = entranceFee.mul(user.roosters.length);
        allRoosters.push(...user.roosters);

        await expect(tournament.connect(user.wallet).claimRefund(gameId, user.roosters, user.address))
          .to.emit(tournament, "ClaimRefund")
          .withArgs(gameId, user.roosters, amount, user.address);

        expect(await scaffold.usdc.balanceOf(user.address)).to.eq(amount);
      }

      const game = await tournament.games(gameId);
      expect(game.roosters).to.eq(allRoosters.length);
      expect(game.balance).to.eq(0);
      expect(await scaffold.usdc.balanceOf(tournament.address)).to.eq(0);
      expect(await tournament.batchQuery(gameId, allRoosters)).to.eql(new Array(100).fill(maxUint32 - 1));
    });

    it("Reverts if refund is already claimed", async () => {
      const user = users[0];
      await expect(
        scaffold.tournament.connect(user.wallet).claimRefund(gameId, user.roosters, user.address),
      ).to.be.revertedWith("Already claimed");
    });
  });

  describe("Function tests", () => {
    // Resets at every `it`
    beforeEach(async () => {
      scaffold = await setup();
    });

    describe("createGame", async () => {
      it("Creates multiple tournaments", async () => {
        const { tournament } = scaffold;
        const count = 10;
        for (let i = 0; i < count; i++) {
          await advanceTime(getRandomNumberBetween(0, 1000));

          const time = await getTime();
          await expect(
            tournament.createGame({
              checkinStartTime: time + 1000,
              checkinEndTime: time + 2000,
              gameStartTime: time + 3000,
              gameEndTime: time + 4000,
              minRoosters: 10,
              maxRoosters: 100,
              roosters: 0,
              entranceFee: toWei(100, 6),
              balance: 0,
              rankingRoot: constants.HashZero,
              distributions: [0, 5000, 3000, 1000, 1000],
              fee: 1000,
              requirementId: 0,
              state: 0,
            }),
          )
            .to.emit(tournament, "CreateGame")
            .withArgs(i, 0, scaffold.accounts.deployer.address);

          const gameId = await currentGameId();
          const game = await tournament.games(gameId);
          expect(gameId).to.eq(i);
          expect(game.rankingRoot).to.eq(constants.HashZero);
          expect(game.balance).to.eq(0);
          expect(game.state).to.eq(State.ONGOING);
          expect(await tournament.getDistributionsSum(gameId)).to.eq(10000);
          expect(await tournament.totalGames()).to.eq(i + 1);
        }
      });

      it("Creates game with 1000 winners", async () => {
        const { tournament } = scaffold;
        const time = await getTime();

        await expect(
          tournament.createGame({
            checkinStartTime: time + 1000,
            checkinEndTime: time + 2000,
            gameStartTime: time + 3000,
            gameEndTime: time + 4000,
            minRoosters: 10,
            maxRoosters: 110,
            roosters: 0,
            entranceFee: toWei(100, 6),
            balance: 0,
            rankingRoot: constants.HashZero,
            distributions: [0, ...new Array(1000).fill(10)],
            fee: 1000,
            requirementId: 0,
            state: 0,
          }),
        )
          .to.emit(tournament, "CreateGame")
          .withArgs(0, 0, scaffold.accounts.deployer.address);

        const gameId = await currentGameId();
        expect(await tournament.getDistributionsSum(gameId)).to.eq(10000);
        expect(await tournament.totalGames()).to.eq(1);
      });

      it("Reverts if invalid param is passed", async () => {
        const time = await getTime();
        const baseParam = {
          checkinStartTime: time + 1000,
          checkinEndTime: time + 2000,
          gameStartTime: time + 3000,
          gameEndTime: time + 4000,
          minRoosters: 10,
          maxRoosters: 100,
          roosters: 0,
          entranceFee: toWei(100, 6),
          balance: 0,
          rankingRoot: constants.HashZero,
          distributions: [0, 5000, 3000, 1000, 1000],
          fee: 1000,
          requirementId: 0,
          state: 0,
        };
        await expect(
          scaffold.tournament.createGame({
            ...baseParam,
            checkinStartTime: baseParam.checkinEndTime,
          }),
        ).to.be.revertedWith("Invalid checkin time window");
        await expect(
          scaffold.tournament.createGame({ ...baseParam, checkinStartTime: time - 1 }),
        ).to.be.revertedWith("Invalid checkin start time");
        await expect(
          scaffold.tournament.createGame({ ...baseParam, gameStartTime: baseParam.gameEndTime }),
        ).to.be.revertedWith("Invalid game time window");
        await expect(
          scaffold.tournament.createGame({ ...baseParam, gameStartTime: baseParam.checkinEndTime }),
        ).to.be.revertedWith("Invalid game start time");
        await expect(scaffold.tournament.createGame({ ...baseParam, distributions: [1] })).to.be.revertedWith(
          "0th index must be 0",
        );
        await expect(scaffold.tournament.createGame({ ...baseParam, fee: 10001 })).to.be.revertedWith(
          "Invalid fee",
        );
        expect(await scaffold.tournament.totalGames()).to.eq(0);
      });
    });

    describe("register", async () => {
      it("Registers to multiple tournaments", async () => {
        const { tournament, usdc } = scaffold;
        for (let i = 0; i < 5; i++) {
          await advanceTimeAndBlock(getRandomNumberBetween(0, 1000));
          const time = await getTime();
          await tournament.createGame({
            checkinStartTime: time + 10,
            checkinEndTime: time + 2000,
            gameStartTime: time + 3000,
            gameEndTime: time + 4000,
            minRoosters: 10,
            maxRoosters: 100,
            roosters: 0,
            entranceFee: toWei(100, 6),
            balance: 0,
            rankingRoot: constants.HashZero,
            distributions: [0, 5000, 3000, 1000, 1000],
            fee: 1000,
            requirementId: 0,
            state: 0,
          });

          const allRoosterIds: number[] = [];
          const amountPerUser = 7;
          const gameId = await currentGameId();
          const users = await User.createRandomUsers(5);

          await warpTo(gameId, "CS");

          {
            const game = await tournament.games(gameId);
            for (const user of users) {
              const roosterIds = await user.getRoosters(amountPerUser);
              const sig = await sign(gameId, roosterIds);
              allRoosterIds.push(...roosterIds);

              await usdc.set(user.address, game.entranceFee.mul(amountPerUser));
              await usdc.connect(user.wallet).approve(tournament.address, constants.MaxUint256);
              await expect(tournament.connect(user.wallet).register(gameId, roosterIds, sig))
                .to.emit(tournament, "RegisterGame")
                .withArgs(gameId, roosterIds, user.address);
            }
          }

          {
            const game = await tournament.games(gameId);
            expect(game.roosters).to.eq(35);
            expect(game.balance).to.eq(game.entranceFee.mul(game.roosters));
            expect(await tournament.batchQuery(gameId, allRoosterIds)).to.eql(new Array(35).fill(maxUint32));
          }
        }
      });
    });
  });
});

/** Utility functions **/

const setup = deployments.createFixture(async (hre) => {
  await deployments.fixture(["tournament"]);
  const { connect, accounts } = await Ship.init(hre);

  const tournament = await connect(Tournament__factory);
  const rooster = await connect(Rooster__factory);
  const usdc = await connect(MockUsdc__factory);
  const scholarship = await connect(Scholarship__factory);

  await rooster.grantRole("MINTER", accounts.deployer.address);
  await tournament.grantRole("MANAGER", accounts.deployer.address);
  await tournament.grantRole("PAUSER", accounts.deployer.address);
  await tournament.grantRole("SIGNER", accounts.signer.address);
  await usdc.set(accounts.vault.address, 0);

  return {
    accounts,
    rooster,
    usdc,
    scholarship,
    tournament,
  };
});

const currentGameId = async () => {
  const gameId = (await scaffold.tournament.totalGames()).toNumber() - 1;
  return gameId;
};

class User {
  wallet: Wallet;
  address: string;
  roosters: number[];

  constructor(wallet: Wallet) {
    this.wallet = wallet;
    this.address = wallet.address;
    this.roosters = [];
  }

  static createRandomUsers = async (num: number, fundGas = true) => {
    const keys = Array.from({ length: num }, () => Wallet.createRandom());
    const wallets = keys.map((key) => new Wallet(key.privateKey, hre.ethers.provider));
    const users = wallets.map((wallet) => new User(wallet));
    if (fundGas) {
      await Promise.all(users.map(async (user) => await user.setBalance(toWei(1, 18))));
    }
    return users;
  };

  public setBalance = async (amount: BigNumber) => {
    await hre.ethers.provider.send("hardhat_setBalance", [
      this.address,
      utils.hexStripZeros(amount.toHexString()),
    ]);
  };

  public getRoosters = async (amount: number) => {
    const firstRoosterId = fromBN(await scaffold.rooster.totalSupply());
    const breeds = Array.from({ length: amount }, () => getRandomNumberBetween(1, 10));
    const roosterIds = Array.from({ length: amount }, (_, i) => firstRoosterId + i);
    this.roosters.push(...roosterIds);

    await scaffold.rooster.batchMint(this.address, breeds);

    return roosterIds;
  };
}

const mintRoosters = async (to: string, amount: number) => {
  const firstRoosterId = fromBN(await scaffold.rooster.totalSupply());
  const breeds = Array.from({ length: amount }, () => getRandomNumberBetween(1, 10));
  await scaffold.rooster.batchMint(to, breeds);
  return Array.from({ length: amount }, (_, i) => firstRoosterId + i);
};

const warpTo = async (gameId: number, dst: "CS" | "CE" | "GS" | "GE" | "ET", offset = 0) => {
  switch (dst) {
    case "CS":
      await setTime((await scaffold.tournament.games(gameId)).checkinStartTime + offset);
      break;
    case "CE":
      await setTime((await scaffold.tournament.games(gameId)).checkinEndTime + offset);
      break;
    case "GS":
      await setTime((await scaffold.tournament.games(gameId)).gameStartTime + offset);
      break;
    case "GE":
      await setTime((await scaffold.tournament.games(gameId)).gameEndTime + offset);
      break;
    case "ET":
      await setTime((await scaffold.tournament.games(gameId)).gameEndTime + 604800 + offset);
      break;
  }
};

const sign = async (gameId: number, roosterIds: number[]) => {
  const requirementId = (await scaffold.tournament.games(gameId)).requirementId;
  const hash = solidityKeccak256(["uint256", "uint16", "uint256[]"], [gameId, requirementId, roosterIds]);
  const sig = await scaffold.accounts.signer.signMessage(arrayify(hash));
  const { r, s, v } = splitSignature(sig);
  return {
    r,
    s,
    v,
  };
};

class RankingTree {
  private tree: MerkleTree;
  public winners: number[];
  public gameId: number;

  constructor(gameId: number, winners: number[]) {
    this.gameId = gameId;
    this.winners = winners;
    const leaves = winners.map((winner, index) => this.getLeaf(winner, index + 1));
    this.tree = new MerkleTree(leaves, keccak256, { sort: true });
  }

  public get root() {
    return this.tree.getHexRoot();
  }

  public getProof = (winner: number) => {
    const ranking = this.winners.indexOf(winner) + 1;
    const leaf = this.getLeaf(winner, ranking);
    return this.tree.getHexProof(leaf);
  };

  public getProofByRanking = (ranking: number) => {
    const winner = this.winners[ranking - 1];
    const leaf = this.getLeaf(winner, ranking);
    return this.tree.getHexProof(leaf);
  };

  public verify = (winner: number, ranking: number) => {
    const proof = this.getProof(winner);
    const leaf = this.getLeaf(winner, ranking);
    return this.tree.verify(proof, leaf, this.root);
  };

  private getLeaf = (winner: number, ranking: number) => {
    return solidityKeccak256(["uint256", "uint256", "uint32"], [this.gameId, winner, ranking]);
  };
}

enum State {
  ONGOING,
  ENDED,
  PAUSED,
  CANCELLED,
}

enum Action {
  ADD,
  END,
  PAUSE,
  UNPAUSE,
  CANCEL,
}

const maxUint32 = 2 ** 32 - 1;
const zeroBytes32 = constants.HashZero;
const emptySig = {
  r: zeroBytes32,
  s: zeroBytes32,
  v: 0,
};
