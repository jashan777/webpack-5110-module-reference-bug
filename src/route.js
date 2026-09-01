export function load() {
  return new Promise(resolve => {
    require.ensure(
      [],
      require => {
        // Capturing the WHOLE module object is what breaks.
        // `require("./mod.js").NAME` on its own would be fine.
        const whole = require("./mod.js");
        resolve([whole.NAME, whole.default]);
      },
      "chunk"
    );
  });
}
