const path = require("path");

// CONCATENATE=0     -> disable scope hoisting entirely
// CONCATENATE=nocjs -> disable it for CommonJS only, keeping ESM scope hoisting
const concat = process.env.CONCATENATE;

module.exports = {
  // mode "production" is what turns on optimization.concatenateModules
  // (scope hoisting). That is the only reason this bug is production-only.
  mode: "production",
  entry: "./src/index.js",
  output: {
    path: path.resolve(__dirname, "dist"),
    filename: "main.js",
    chunkFilename: "[name].chunk.js",
    clean: true,
  },
  optimization: {
    // left readable so the leaked placeholder is visible in dist/main.js
    minimize: false,
    concatenateModules:
      concat === "0" ? false : concat === "nocjs" ? { commonjs: false } : true,
  },
  devtool: false,
  target: "node",
  stats: "errors-warnings",
};
