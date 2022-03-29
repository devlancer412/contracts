import { setTime, Time } from "../utils";

const main = async () => {
  const now = Time.fromNow().toSec();
  setTime(now);
};

main()
  .then(() => process.exit(0))
  .catch((err: Error) => {
    console.error(err);
    process.exit(1);
  });
