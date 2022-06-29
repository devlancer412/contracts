import { expect } from "./chai-setup";
import { BigNumber, constants, utils, Wallet } from "ethers";
import hre, { deployments } from "hardhat";
import { ITournament } from "../types/contracts/tournament/Tournament";
import { MockUsdc__factory, Rooster__factory, Scholarship__factory, Tournament__factory } from "../types";
import { advanceTimeAndBlock, fromBN, getRandomNumberBetween, getTime, setTime, Ship, toWei } from "../utils";
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
        registrationStartTimestamp: time + 1000,
        registrationEndTimestamp: time + 2000,
        tournamentStartTimestamp: time + 3000,
        tournamentEndTimestamp: time + 4000,
        minRoosters: 10,
        maxRoosters: 110,
        entranceFee: toWei(100, 6),
        fee: 1000,
        distributions: [0, 5000, 3000, 1000, 1000],
      });
      await expect(promi).to.emit(tournament, "CreateGame").withArgs(0, scaffold.accounts.deployer.address);

      gameId = await currentGameId();
      const game = await tournament.games(gameId);
      expect(gameId).to.eq(0);
      expect(game.rankingRoot).to.eq(constants.HashZero);
      expect(game.balance).to.eq(0);
      expect(game.prizePool).to.eq(0);
      expect(game.state).to.eq(State.ONGOING);
      expect(await tournament.getDistributionsSum(gameId)).to.eq(10000);
      expect(await tournament.totalGames()).to.eq(1);
    });

    it("Adds sponsor funds", async () => {
      const fundAmount = toWei(100, 6);
      await scaffold.usdc.set(scaffold.accounts.deployer.address, fundAmount);
      await scaffold.usdc.approve(scaffold.tournament.address, constants.MaxUint256);
      await expect(scaffold.tournament.setGame(Action.FUND, gameId, fundAmount, zeroBytes32, []))
        .to.emit(scaffold.tournament, "SetGame")
        .withArgs(0, Action.FUND);

      const game = await scaffold.tournament.games(gameId);
      expect(game.prizePool).to.eq(fundAmount);
      expect(game.balance).to.eq(fundAmount);
      expect(await scaffold.usdc.balanceOf(scaffold.tournament.address)).to.eq(fundAmount);
    });

    it("Registers 3 roosters", async () => {
      const {
        tournament,
        usdc,
        accounts: { alice },
      } = scaffold;

      // Warp to check in time
      await warpTo(gameId, "RS");

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
      expect(game.balance).to.eq(game.entranceFee.mul(3).add(toWei(100, 6)));
      expect(game.prizePool).to.eq(game.entranceFee.mul(3).add(toWei(100, 6)));
      expect(await usdc.balanceOf(tournament.address)).to.eq(game.entranceFee.mul(3).add(toWei(100, 6)));
      expect(await tournament.batchQuery(gameId, roosterIds)).to.eql(new Array(3).fill(maxUint32));
    });

    it("Pauses game", async () => {
      const { tournament, accounts } = scaffold;

      const promi = tournament.connect(accounts.deployer).setGame(Action.PAUSE, gameId, 0, zeroBytes32, []);
      await expect(promi).to.emit(tournament, "SetGame").withArgs(gameId, Action.PAUSE);

      const game = await tournament.games(gameId);
      expect(game.state).to.eq(State.PAUSED);
    });

    it("Cannot pause if paused", async () => {
      await expect(scaffold.tournament.setGame(Action.PAUSE, gameId, 0, zeroBytes32, [])).to.be.revertedWith(
        "Not ongoing",
      );
    });

    it("Cannot register if paused", async () => {
      await expect(scaffold.tournament.register(gameId, [1], emptySig)).to.be.revertedWith(
        "Paused or Cancelled",
      );
    });

    it("Unpauses game", async () => {
      const { tournament } = scaffold;
      const promi = tournament.setGame(Action.UNPAUSE, gameId, 0, zeroBytes32, []);
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
      expect(game.balance).to.eq(game.entranceFee.mul(game.roosters).add(toWei(100, 6)));
      expect(game.prizePool).to.eq(game.entranceFee.mul(game.roosters).add(toWei(100, 6)));
      expect(await usdc.balanceOf(tournament.address)).to.eq(
        game.entranceFee.mul(game.roosters).add(toWei(100, 6)),
      );
      expect(await tournament.batchQuery(gameId, allRoosterIds)).to.eql(new Array(100).fill(maxUint32));
    });

    it("Ends game", async () => {
      const { tournament } = scaffold;

      await warpTo(gameId, "GE");

      const winners = [1, 3, 4, 5];
      rankingTree = new RankingTree(gameId, winners);

      const promi = tournament.setGame(Action.END, gameId, 0, rankingTree.root, []);
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
      expect(game.prizePool).to.eq(game.entranceFee.mul(game.roosters).add(toWei(100, 6)));
      expect(await usdc.balanceOf(accounts.alice.address)).to.eq(amount.sub(fee));
      expect(await usdc.balanceOf(accounts.vault.address)).to.eq(fee);
      expect(await usdc.balanceOf(tournament.address)).to.eq(amount);
      expect(await tournament.roosters(gameId, 1)).to.eq(1);
    });

    it("Cannot claim prize if already claimed", async () => {
      await expect(
        scaffold.tournament
          .connect(scaffold.accounts.alice)
          .claimReward(gameId, [1], [1], [rankingTree.getProof(1)], scaffold.accounts.alice.address),
      ).to.be.revertedWith("Already claimed or not registered");
    });

    it("Cannot claim prize if valid proof is not provided", async () => {
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

    it("Cannot be claimed by non-owner", async () => {
      await expect(
        scaffold.tournament
          .connect(scaffold.accounts.bob)
          .claimReward(gameId, [1], [1], [rankingTree.getProof(1)], scaffold.accounts.bob.address),
      ).to.be.revertedWith("Not owner");
    });

    it("Claims multiple prizes", async () => {
      const { tournament, usdc, accounts } = scaffold;
      let game = await tournament.games(gameId);

      const totalAmount = game.prizePool;
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

    it("Cannot withdraw expired rewards if not expired", async () => {
      await expect(scaffold.tournament.withdrawExpiredRewards(gameId)).to.be.revertedWith("Not expired");
    });

    it("Withdraws expired rewards", async () => {
      const { tournament, usdc, accounts } = scaffold;
      let game = await tournament.games(gameId);
      const gameBalanceBefore = game.balance;
      const vaultBalanceBefore = await usdc.balanceOf(accounts.vault.address);

      await warpTo(gameId, "EX");

      const promi = tournament.connect(accounts.deployer).withdrawExpiredRewards(gameId);
      await expect(promi).to.emit(tournament, "WithdrawExpiredRewards").withArgs(gameId, gameBalanceBefore);

      game = await tournament.games(gameId);
      expect(game.balance).to.eq(0);
      expect(await usdc.balanceOf(tournament.address)).to.eq(0);
      expect(await usdc.balanceOf(accounts.vault.address)).to.eq(vaultBalanceBefore.add(gameBalanceBefore));
    });

    it("Cannot claim reward if expired", async () => {
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
      gameId = await createBasicGame();
      await warpTo(gameId, "RS", 10);
    });

    it("Adds million dollar sponsor funds", async () => {
      const fundAmount = toWei(1_000_000, 6);
      await scaffold.usdc.set(scaffold.accounts.deployer.address, fundAmount);
      await scaffold.usdc.approve(scaffold.tournament.address, constants.MaxUint256);
      await expect(scaffold.tournament.setGame(Action.FUND, gameId, fundAmount, zeroBytes32, []))
        .to.emit(scaffold.tournament, "SetGame")
        .withArgs(0, Action.FUND);

      const game = await scaffold.tournament.games(gameId);
      expect(game.prizePool).to.eq(fundAmount);
      expect(game.balance).to.eq(fundAmount);
      expect(await scaffold.usdc.balanceOf(scaffold.tournament.address)).to.eq(fundAmount);
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
        expect(game.balance).to.eq(game.entranceFee.mul(game.roosters).add(toWei(1_000_000, 6)));
        expect(game.prizePool).to.eq(game.entranceFee.mul(game.roosters).add(toWei(1_000_000, 6)));
        expect(await usdc.balanceOf(tournament.address)).to.eq(
          game.entranceFee.mul(game.roosters).add(toWei(1_000_000, 6)),
        );
        expect(await tournament.batchQuery(gameId, allRoosterIds)).to.eql(new Array(100).fill(maxUint32));
      }
    });

    it("Cancels game", async () => {
      const { tournament, usdc, accounts } = scaffold;
      await usdc.set(accounts.vault.address, 0);

      const promi = tournament.setGame(Action.CANCEL, gameId, 0, zeroBytes32, []);
      await expect(promi).to.emit(tournament, "SetGame").withArgs(gameId, Action.CANCEL);

      const game = await tournament.games(gameId);
      expect(game.state).to.eq(State.CANCELLED);
      expect(game.balance).to.eq(game.entranceFee.mul(game.roosters));
      expect(game.prizePool).to.eq(game.entranceFee.mul(game.roosters).add(toWei(1_000_000, 6)));
      expect(await usdc.balanceOf(tournament.address)).to.eq(game.entranceFee.mul(game.roosters));
      expect(await usdc.balanceOf(accounts.vault.address)).to.eq(toWei(1_000_000, 6));
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

    it("Cannot claim refund if already claimed", async () => {
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
          await advanceTimeAndBlock(getRandomNumberBetween(0, 1000));

          const time = await getTime();
          await expect(
            tournament.createGame({
              registrationStartTimestamp: time + 1000,
              registrationEndTimestamp: time + 2000,
              tournamentStartTimestamp: time + 3000,
              tournamentEndTimestamp: time + 4000,
              minRoosters: 10,
              maxRoosters: 100,
              entranceFee: toWei(100, 6),
              fee: 1000,
              distributions: [0, 5000, 3000, 1000, 1000],
            }),
          )
            .to.emit(tournament, "CreateGame")
            .withArgs(i, scaffold.accounts.deployer.address);

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
            registrationStartTimestamp: time + 1000,
            registrationEndTimestamp: time + 2000,
            tournamentStartTimestamp: time + 3000,
            tournamentEndTimestamp: time + 4000,
            minRoosters: 10,
            maxRoosters: 110,
            entranceFee: toWei(100, 6),
            fee: 1000,
            distributions: [0, ...new Array(1000).fill(10)],
          }),
        )
          .to.emit(tournament, "CreateGame")
          .withArgs(0, scaffold.accounts.deployer.address);

        const gameId = await currentGameId();
        expect(await tournament.getDistributionsSum(gameId)).to.eq(10000);
        expect(await tournament.totalGames()).to.eq(1);
      });

      it("Cannot be executed by non manager", async () => {
        await expect(
          scaffold.tournament.connect(scaffold.accounts.alice).createGame({
            registrationStartTimestamp: 0,
            registrationEndTimestamp: 0,
            tournamentStartTimestamp: 0,
            tournamentEndTimestamp: 0,
            minRoosters: 10,
            maxRoosters: 110,
            entranceFee: toWei(100, 6),
            fee: 1000,
            distributions: [0, ...new Array(1000).fill(10)],
          }),
        ).to.be.reverted;
      });

      it("Cannot create game if invalid param is passed", async () => {
        const time = await getTime();
        const baseParam: ITournament.CreateGameParamStruct = {
          registrationStartTimestamp: time + 1000,
          registrationEndTimestamp: time + 2000,
          tournamentStartTimestamp: time + 3000,
          tournamentEndTimestamp: time + 4000,
          minRoosters: 10,
          maxRoosters: 100,
          entranceFee: toWei(100, 6),
          fee: 1000,
          distributions: [0, 5000, 3000, 1000, 1000],
        };
        await expect(
          scaffold.tournament.createGame({
            ...baseParam,
            registrationStartTimestamp: baseParam.registrationEndTimestamp,
          }),
        ).to.be.revertedWith("Invalid registeration time window");
        await expect(
          scaffold.tournament.createGame({ ...baseParam, registrationStartTimestamp: time - 1 }),
        ).to.be.revertedWith("Invalid registeration start time");
        await expect(
          scaffold.tournament.createGame({
            ...baseParam,
            tournamentStartTimestamp: baseParam.tournamentEndTimestamp,
          }),
        ).to.be.revertedWith("Invalid tournament time window");
        await expect(
          scaffold.tournament.createGame({
            ...baseParam,
            tournamentStartTimestamp: baseParam.registrationEndTimestamp,
          }),
        ).to.be.revertedWith("Invalid tournament start time");
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
          const gameId = await createBasicGame();
          const users = await User.createRandomUsers(5);

          const allRoosterIds: number[] = [];
          const amountPerUser = 7;

          await warpTo(gameId, "RS");

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

      it("Cannot register before/after registeration time", async () => {
        const id = await createBasicGame();
        await expect(scaffold.tournament.register(id, [], emptySig)).to.be.revertedWith("Not started");
        await warpTo(id, "RE", 1);
        await expect(scaffold.tournament.register(id, [], emptySig)).to.be.revertedWith("Ended");
      });

      it("Cannot register if number of roosters exceeds limit", async () => {
        const id = await createBasicGame();
        await warpTo(id, "RS");

        const [user] = await User.createRandomUsers(1);
        await scaffold.usdc.set(user.address, toWei(100, 6).mul(1000));
        await scaffold.usdc.connect(user.wallet).approve(scaffold.tournament.address, constants.MaxUint256);

        const roosterIds = await user.getRoosters(100);
        const sig = await sign(id, roosterIds);
        await expect(scaffold.tournament.connect(user.wallet).register(id, roosterIds, sig)).not.to.be
          .reverted;
        await expect(
          scaffold.tournament.connect(user.wallet).register(id, roosterIds, sig),
        ).to.be.revertedWith("Reached limit");
      });

      it("Cannot be registered by non-owner ", async () => {
        const id = await createBasicGame();
        await warpTo(id, "RS");

        const [user1, user2] = await User.createRandomUsers(2);
        await scaffold.usdc.set(user1.address, toWei(100, 6).mul(1000));
        await scaffold.usdc.connect(user1.wallet).approve(scaffold.tournament.address, constants.MaxUint256);

        const roosterIds = await user2.getRoosters(10);
        const sig = await sign(id, roosterIds);
        await expect(
          scaffold.tournament.connect(user1.wallet).register(id, roosterIds, sig),
        ).to.be.revertedWith("Not owner");
      });

      it("Cannot register same roosters", async () => {
        const id = await createBasicGame();
        await warpTo(id, "RS");

        const [user] = await User.createRandomUsers(1);
        await scaffold.usdc.set(user.address, toWei(100, 6).mul(1000));
        await scaffold.usdc.connect(user.wallet).approve(scaffold.tournament.address, constants.MaxUint256);

        const roosterIds = await user.getRoosters(50);
        const sig = await sign(id, roosterIds);
        await expect(scaffold.tournament.connect(user.wallet).register(id, roosterIds, sig)).not.to.be
          .reverted;
        await expect(
          scaffold.tournament.connect(user.wallet).register(id, roosterIds, sig),
        ).to.be.revertedWith("Already registered");
      });
    });

    describe("claimReward", () => {
      it("Cannot claim if roosterIds and rankings array length does not match", async () => {
        const gameId = await createBasicGame();
        await expect(
          scaffold.tournament.claimReward(gameId, [1], [], [[]], constants.AddressZero),
        ).to.be.revertedWith("Length mismatch");
      });

      it("Cannot claim if not ended", async () => {
        const gameId = await createBasicGame();
        await expect(
          scaffold.tournament.claimReward(gameId, [], [], [[]], constants.AddressZero),
        ).to.be.revertedWith("Not ended");
      });

      it("Cannot claim if expired", async () => {
        const gameId = await createBasicGame({ minRoosters: 0 });
        await warpTo(gameId, "GE");
        await scaffold.tournament.setGame(Action.END, gameId, 0, oneBytes32, []);
        await warpTo(gameId, "EX");

        await expect(
          scaffold.tournament.claimReward(gameId, [], [], [[]], constants.AddressZero),
        ).to.be.revertedWith("Expired");
      });

      it("Cannot be claimed by non owner", async () => {
        const gameId = await createBasicGame({ minRoosters: 0 });
        await warpTo(gameId, "GE");
        await scaffold.tournament.setGame(Action.END, gameId, 0, oneBytes32, []);
        const [user1, user2] = await User.createRandomUsers(2);
        const roosterIds = await user1.getRoosters(2);
        await expect(
          scaffold.tournament
            .connect(user2.wallet)
            .claimReward(gameId, roosterIds, [1, 2], [[]], constants.AddressZero),
        ).to.be.revertedWith("Not owner");
      });
    });

    describe("claimRefund", () => {
      it("Cannot claim if not cancelled", async () => {
        const gameId = await createBasicGame();
        await expect(scaffold.tournament.claimRefund(gameId, [1], constants.AddressZero)).to.be.revertedWith(
          "Not cancelled",
        );
      });

      it("Cannot be claimed by non owner", async () => {
        const gameId = await createBasicGame();
        await scaffold.tournament.setGame(Action.CANCEL, gameId, 0, oneBytes32, []);
        const [user1, user2] = await User.createRandomUsers(2);
        const roosterIds = await user1.getRoosters(2);
        await expect(
          scaffold.tournament.connect(user2.wallet).claimRefund(gameId, roosterIds, constants.AddressZero),
        ).to.be.revertedWith("Not owner");
      });
    });

    describe("withdrawExpiredReward", () => {
      it("Cannot be executed by non manager", async () => {
        await expect(scaffold.tournament.connect(scaffold.accounts.alice).withdrawExpiredRewards(0)).to.be
          .reverted;
      });

      it("Cannot withdraw before expiration time", async () => {
        const gameId = await createBasicGame();
        await expect(scaffold.tournament.withdrawExpiredRewards(gameId)).to.be.revertedWith("Not expired");
      });

      it("Cannot withdraw if not ended", async () => {
        const gameId = await createBasicGame({ minRoosters: 0 });
        await warpTo(gameId, "EX");
        await expect(scaffold.tournament.withdrawExpiredRewards(gameId)).to.be.revertedWith("Not ended");
      });

      it("Cannot withdraw if there is nothing to withdraw", async () => {
        const gameId = await createBasicGame({ minRoosters: 0 });
        await warpTo(gameId, "GE");
        await scaffold.tournament.setGame(Action.END, gameId, 0, oneBytes32, []);
        await warpTo(gameId, "EX");
        await expect(scaffold.tournament.withdrawExpiredRewards(gameId)).to.be.revertedWith(
          "Nothing to withdraw",
        );
      });
    });

    describe("setGame", () => {
      it("Adds distribution percentages", async () => {
        const gameId = await createBasicGame({ distributions: [0, 1000] });
        const toAdd = new Array(9).fill(1000);
        await expect(scaffold.tournament.setGame(Action.ADD, gameId, 0, zeroBytes32, toAdd))
          .to.emit(scaffold.tournament, "SetGame")
          .withArgs(gameId, Action.ADD);
        expect(await scaffold.tournament.getDistributionsSum(gameId)).to.eq(10000);
      });

      it("Adds 1000 distribution percentages", async () => {
        const gameId = await createBasicGame({ distributions: [0] });
        const toAdd = new Array(1000).fill(10);
        await expect(scaffold.tournament.setGame(Action.ADD, gameId, 0, zeroBytes32, toAdd))
          .to.emit(scaffold.tournament, "SetGame")
          .withArgs(gameId, Action.ADD);
        expect(await scaffold.tournament.getDistributionsSum(gameId)).to.eq(10000);
      });

      it("Cannot add distribtion pecentages after registeration begins", async () => {
        const gameId = await createBasicGame({ distributions: [0, 1000] });
        await warpTo(gameId, "RS");
        const toAdd = new Array(9).fill(1000);
        await expect(
          scaffold.tournament.setGame(Action.ADD, gameId, 0, zeroBytes32, toAdd),
        ).to.be.revertedWith("Registeration started");
      });

      it("Funds prize", async () => {
        const gameId = await createBasicGame();
        const amount = toWei(1_000_000, 6);
        await scaffold.usdc.set(scaffold.accounts.deployer.address, amount);
        await scaffold.usdc.approve(scaffold.tournament.address, constants.MaxUint256);
        await expect(scaffold.tournament.setGame(Action.FUND, gameId, amount, zeroBytes32, []))
          .to.emit(scaffold.tournament, "SetGame")
          .withArgs(gameId, Action.FUND);

        const game = await scaffold.tournament.games(gameId);
        expect(game.balance).to.eq(amount);
        expect(game.prizePool).to.eq(amount);
        expect(await scaffold.usdc.balanceOf(scaffold.tournament.address)).to.eq(amount);
      });

      it("Cannot fund prize if game is ended", async () => {
        const gameId = await createBasicGame({ minRoosters: 0 });
        await warpTo(gameId, "GE");
        await scaffold.tournament.setGame(Action.END, gameId, 0, oneBytes32, []);
        await expect(scaffold.tournament.setGame(Action.FUND, gameId, 1, zeroBytes32, [])).to.be.revertedWith(
          "Ended or cancelled",
        );
      });

      it("Cannot fund prize if game is cancelled", async () => {
        const gameId = await createBasicGame({ minRoosters: 0 });
        await scaffold.tournament.setGame(Action.CANCEL, gameId, 0, oneBytes32, []);
        await expect(scaffold.tournament.setGame(Action.FUND, gameId, 1, zeroBytes32, [])).to.be.revertedWith(
          "Ended or cancelled",
        );
      });

      it("Can only cancel if not enough roooster participated", async () => {
        const gameId = await createBasicGame({ minRoosters: 10 });
        await scaffold.usdc.set(scaffold.accounts.vault.address, 0);
        await warpTo(gameId, "RS");

        // Register
        {
          const [user] = await User.createRandomUsers(1);
          const roosterIds = await user.getRoosters(5);
          const sig = await sign(gameId, roosterIds);
          await scaffold.usdc.set(user.address, toWei(99999999, 6));
          await scaffold.usdc.connect(user.wallet).approve(scaffold.tournament.address, constants.MaxUint256);
          await scaffold.tournament.connect(user.wallet).register(gameId, roosterIds, sig);
        }

        // Fund
        {
          const amount = toWei(1_000_000, 6);
          await scaffold.usdc.set(scaffold.accounts.deployer.address, amount);
          await scaffold.usdc.approve(scaffold.tournament.address, constants.MaxUint256);
          await scaffold.tournament.setGame(Action.FUND, gameId, amount, zeroBytes32, []);
        }

        await warpTo(gameId, "GE");

        // Try end
        {
          await expect(scaffold.tournament.setGame(Action.END, gameId, 0, oneBytes32, [])).to.be.revertedWith(
            "Not enough roosters",
          );
        }

        // Cancel
        {
          await expect(scaffold.tournament.setGame(Action.CANCEL, gameId, 0, zeroBytes32, []))
            .to.emit(scaffold.tournament, "SetGame")
            .withArgs(gameId, Action.CANCEL);

          const game = await scaffold.tournament.games(gameId);
          expect(game.balance).to.eq(game.entranceFee.mul(game.roosters));
          expect(game.state).to.eq(State.CANCELLED);
          expect(await scaffold.usdc.balanceOf(scaffold.accounts.vault.address)).to.eq(toWei(1_000_000, 6));
        }
      });

      it("Cannot be executed by non-manager", async () => {
        await expect(
          scaffold.tournament.connect(scaffold.accounts.alice).setGame(Action.ADD, 0, 0, zeroBytes32, []),
        ).to.be.reverted;
      });
    });
  });
});

/** Utility functions **/

const setup = deployments.createFixture(async (hre) => {
  await deployments.fixture(["mocks", "nfts", "scholarship", "tournament"]);
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

const createBasicGame = async (override?: Partial<ITournament.CreateGameParamStruct>) => {
  const time = await getTime();
  await scaffold.tournament.createGame({
    registrationStartTimestamp: time + 1000,
    registrationEndTimestamp: time + 2000,
    tournamentStartTimestamp: time + 3000,
    tournamentEndTimestamp: time + 4000,
    minRoosters: 10,
    maxRoosters: 100,
    entranceFee: toWei(100, 6),
    fee: 1000,
    distributions: [0, 5000, 3000, 1000, 1000],
    ...override,
  });
  return await currentGameId();
};

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

const warpTo = async (gameId: number, dst: "RS" | "RE" | "GS" | "GE" | "EX", offset = 0) => {
  switch (dst) {
    case "RS":
      await setTime((await scaffold.tournament.games(gameId)).registrationStartTimestamp + offset);
      break;
    case "RE":
      await setTime((await scaffold.tournament.games(gameId)).registrationEndTimestamp + offset);
      break;
    case "GS":
      await setTime((await scaffold.tournament.games(gameId)).tournamentStartTimestamp + offset);
      break;
    case "GE":
      await setTime((await scaffold.tournament.games(gameId)).tournamentEndTimestamp + offset);
      break;
    case "EX":
      await setTime((await scaffold.tournament.games(gameId)).tournamentEndTimestamp + 604800 + offset);
      break;
  }
};

const sign = async (gameId: number, roosterIds: number[]) => {
  const hash = solidityKeccak256(["uint256", "uint256[]"], [gameId, roosterIds]);
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
  FUND,
  END,
  PAUSE,
  UNPAUSE,
  CANCEL,
}

const maxUint32 = 2 ** 32 - 1;
const zeroBytes32 = constants.HashZero;
const oneBytes32 = "0x0000000000000000000000000000000000000000000000000000000000000001";
const emptySig = {
  r: zeroBytes32,
  s: zeroBytes32,
  v: 0,
};