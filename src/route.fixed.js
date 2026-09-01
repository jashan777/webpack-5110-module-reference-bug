export function load() {
  return new Promise(resolve => {
    require.ensure(
      [],
      require => {
        // THE FIX: take each property AT the require site, so webpack never
        // needs a reference to the whole module object.
        //
        // Destructuring is NOT a fix -- this still leaks the placeholder:
        //   const { NAME, default: d } = require("./mod.js");
        resolve([
          require("./mod.js").NAME,
          require("./mod.js").default,
        ]);
      },
      "chunk"
    );
  });
}
