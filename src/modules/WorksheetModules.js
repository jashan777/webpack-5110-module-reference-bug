// An ESM module exporting BOTH a named export and a default export.
// The route reads both of these off a single `require()` call.
export const NAME = "worksheet";

export default function reducer(state = {}, action) {
  return state;
}
