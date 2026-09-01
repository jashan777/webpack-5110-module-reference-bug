// Stand-in for the app's redux store helper.
const reducers = {};

export function injectReducer(store, { key, reducer }) {
  if (key === undefined) {
    throw new Error("injectReducer called with key === undefined");
  }
  reducers[key] = reducer;
  return reducers;
}

export function getReducers() {
  return Object.keys(reducers);
}
