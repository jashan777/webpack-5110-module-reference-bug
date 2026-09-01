const path = require("path");
module.exports = {
  mode: "production", // turns on optimization.concatenateModules
  entry: "./src/index.js",
  output: { path: path.resolve(__dirname, "dist"), filename: "main.js", clean: true },
  optimization: { minimize: false },
  devtool: false,
  target: "node",
  stats: "errors-warnings",
};
