import { load } from "./route.js";

load()
  .then(r => console.log("OK   --", JSON.stringify(r)))
  .catch(e => {
    console.error("FAIL --", e.message);
    process.exitCode = 1;
  });
