import { Tournament__factory } from "../types";
import { getTime, Ship, Time, toWei } from "../utils";
import { ITournament } from "../types/contracts/tournament/Tournament";

const main = async () => {
  const ship = await Ship.init();
  const tournament = await ship.connect(Tournament__factory);

  // Create game
  const time = await getTime();

  // Small
  {
    const param: ITournament.CreateGameParamStruct = {
      registrationStartTimestamp: time + 1000,
      registrationEndTimestamp: time + 2000,
      tournamentStartTimestamp: time + 3000,
      tournamentEndTimestamp: time + 4000,
      minRoosters: 5,
      maxRoosters: 20,
      entranceFee: toWei(100, 6),
      fee: 1000,
      distributions: [0, 5000, 3000, 2000],
    };
    const gasLimit = await tournament.connect(ship.accounts.deployer).estimateGas.createGame(param);
    const gasPrice = await ship.provider.getGasPrice();
    await tournament
      .connect(ship.accounts.deployer)
      .createGame(param, { gasLimit: gasLimit.mul(3).div(2), gasPrice: gasPrice.mul(3).div(2) });
  }

  // Mid
  {
    const param: ITournament.CreateGameParamStruct = {
      registrationStartTimestamp: time + 2000,
      registrationEndTimestamp: time + 3000,
      tournamentStartTimestamp: time + 4000,
      tournamentEndTimestamp: time + 5000,
      minRoosters: 20,
      maxRoosters: 100,
      entranceFee: toWei(50, 6),
      fee: 1000,
      distributions: [0, 5000, 3000, 1000, 1000],
    };
    const gasLimit = await tournament.connect(ship.accounts.deployer).estimateGas.createGame(param);
    const gasPrice = await ship.provider.getGasPrice();
    await tournament
      .connect(ship.accounts.deployer)
      .createGame(param, { gasLimit: gasLimit.mul(3).div(2), gasPrice: gasPrice.mul(3).div(2) });
  }

  // Big
  {
    const param: ITournament.CreateGameParamStruct = {
      registrationStartTimestamp: time + 1000,
      registrationEndTimestamp: time + 10000,
      tournamentStartTimestamp: time + 20000,
      tournamentEndTimestamp: time + 50000,
      minRoosters: 100,
      maxRoosters: 1000,
      entranceFee: toWei(10, 6),
      fee: 1000,
      distributions: [0, 3000, 2000, 1000, 500, 500, ...new Array(30).fill(100)],
    };
    const gasLimit = await tournament.connect(ship.accounts.deployer).estimateGas.createGame(param);
    const gasPrice = await ship.provider.getGasPrice();
    await tournament
      .connect(ship.accounts.deployer)
      .createGame(param, { gasLimit: gasLimit.mul(3).div(2), gasPrice: gasPrice.mul(3).div(2) });
  }
};

main()
  .then(() => process.exit(0))
  .catch((err: Error) => {
    console.error(err);
    process.exit(1);
  });
