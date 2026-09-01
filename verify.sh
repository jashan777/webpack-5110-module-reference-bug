#!/usr/bin/env bash
# Demonstrates the bug across webpack versions and the two require() styles.
set -u
cd "$(dirname "$0")"

TOKEN='__WEBPACK_MODULE_REFERENCE__'
bar() { printf '%s\n' "------------------------------------------------------------------------"; }

scenario() { # <version> <label> <use_fix> <concatenate>
  USE_FIX="$3" CONCATENATE="$4" npx --no-install webpack --config webpack.config.js >/dev/null 2>&1
  leaked=$(grep -c "$TOKEN" dist/main.js 2>/dev/null || true)
  leaked=${leaked:-0}
  out=$(node dist/main.js 2>&1 | head -1 | cut -c1-52)
  if [ "$leaked" -gt 0 ]; then verdict="BROKEN"; else verdict="ok"; fi
  printf '  %-38s leaked=%-3s %-6s %s\n' "$2" "$leaked" "$verdict" "$out"
}

for V in 5.109.2 5.110.2; do
  bar; echo "  webpack $V"; bar
  npm i --silent --no-audit --no-fund --no-save "webpack@$V" webpack-cli@5.1.4 >/dev/null 2>&1
  scenario "$V" "whole-namespace require()"        "0" "1"
  scenario "$V" "  + optimization fix (USE_FIX=1)" "1" "1"
  scenario "$V" "  + concatenateModules: false"    "0" "0"
  echo
done

bar
echo "  The leaked identifier, as shipped to the browser:"
bar
USE_FIX=0 CONCATENATE=1 npx --no-install webpack --config webpack.config.js >/dev/null 2>&1
grep -o "const [a-zA-Z]* = __webpack_require__${TOKEN}[A-Za-z0-9_]*" dist/main.js | sed 's/^/  /'
