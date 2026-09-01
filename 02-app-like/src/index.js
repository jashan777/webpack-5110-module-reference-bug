import makeTeacherRoute from "TeacherRoute";
import { getReducers } from "./store.js";

const store = {};

makeTeacherRoute(store)
  .load()
  .then(msg => {
    console.log("OK  --", msg);
    console.log("OK  -- reducers injected:", getReducers().join(", "));
  })
  .catch(err => {
    console.error("FAIL --", err && err.message ? err.message : err);
    process.exitCode = 1;
  });
