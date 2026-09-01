const path = require("path");

// USE_FIX=1 swaps in the fixed route; everything else is identical.
const useFix = process.env.USE_FIX === "1";

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
  resolve: {
    alias: {
      TeacherRoute: path.resolve(
        __dirname,
        useFix ? "src/routes/Teacher/index.fixed.js" : "src/routes/Teacher/index.js"
      ),
    },
  },
  optimization: {
    // left readable so the leaked placeholder is visible in dist/main.js
    minimize: false,
    // set to false and the bug disappears -- that is the blunt workaround
    concatenateModules:
      process.env.CONCATENATE === "0"
        ? false
        : process.env.CONCATENATE === "nocjs"
          ? { commonjs: false }   // targeted: keeps ESM scope hoisting
          : true,
  },
  devtool: false,
  target: "node",
  stats: "errors-warnings",
};
