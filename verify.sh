#!/usr/bin/env bash
# Builds the reproduction on webpack 5.109.2 and 5.110.2 and reports.
set -u
cd "$(dirname "$0")"

T='__WEBPACK_MODULE_REFERENCE__'
if [ -t 1 ]; then
  R=$'\033[31m'; G=$'\033[32m'; D=$'\033[2m'; B=$'\033[1m'; X=$'\033[0m'
else R=; G=; D=; B=; X=; fi

rule(){ printf "${D}%s${X}\n" "──────────────────────────────────────────────────────────────────────"; }

report(){ # <label>
  local leaked out
  leaked=$(grep -c "$T" dist/main.js 2>/dev/null || true); leaked=${leaked:-0}
  out=$(node dist/main.js 2>&1 | grep -m1 -E "ReferenceError|^OK|^FAIL" || node dist/main.js 2>&1 | head -1)
  out=$(echo "$out" | sed 's/^ *//')
  if [ "$leaked" -gt 0 ]; then
    printf "    %-32s ${R}${B}%-8s${X} ${R}%s leaked${X}\n" "$1" "BREAKS" "$leaked"
    printf "      ${R}%s${X}\n" "$(echo "$out" | cut -c1-88)"
  else
    printf "    %-32s ${G}${B}%-8s${X} ${D}%s leaked   %s${X}\n" "$1" "works" "$leaked" "$(echo "$out" | cut -c1-40)"
  fi
}

build(){ npx --no-install webpack --config webpack.config.js >/dev/null 2>&1; }

printf "\n${B}  webpack >= 5.110.0 leaks an internal placeholder into production output${X}\n"
printf "${D}  24 lines of source. No framework, no application code.${X}\n"

for V in 5.109.2 5.110.2; do
  npm i --silent --no-audit --no-fund --no-save "webpack@$V" webpack-cli@5.1.4 >/dev/null 2>&1
  echo; rule; printf "  ${B}webpack %s${X}\n" "$V"; rule
  CONCATENATE=1     build; report "whole-module require()"
  CONCATENATE=nocjs build; report "  + concatenateModules{commonjs:0}"
  CONCATENATE=0     build; report "  + concatenateModules:false"
done

echo; rule; printf "  ${B}What actually shipped (webpack 5.110.2)${X}\n"; rule
CONCATENATE=1 build
grep -o "const [a-zA-Z]* = __webpack_require__${T}[A-Za-z0-9_]*" dist/main.js | sed "s/^/    ${R}/;s/\$/${X}/"
printf "\n    ${D}%s${X}\n" "A valid JS identifier that was never declared: the file parses and the"
printf "    ${D}%s${X}\n\n" "build passes, so it throws only when that line actually runs."
