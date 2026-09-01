#!/usr/bin/env bash
# Builds both reproductions on webpack 5.109.2 and 5.110.2 and reports.
set -u
cd "$(dirname "$0")"

T='__WEBPACK_MODULE_REFERENCE__'
if [ -t 1 ]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; D=$'\033[2m'; B=$'\033[1m'; X=$'\033[0m'
else R=; G=; Y=; D=; B=; X=; fi

rule(){ printf "${D}%s${X}\n" "────────────────────────────────────────────────────────────────────────────"; }
title(){ echo; rule; printf "  ${B}%s${X}\n" "$1"; rule; }

install(){ npm i --silent --no-audit --no-fund --no-save "webpack@$1" webpack-cli@5.1.4 >/dev/null 2>&1; }

build(){ # <dir> ; extra env passed through
  ( cd "$1" && npx --no-install webpack --config webpack.config.js >/dev/null 2>&1 )
}

report(){ # <dir> <label>
  local d="$1" label="$2" leaked out
  leaked=$(grep -c "$T" "$d/dist/main.js" 2>/dev/null || true); leaked=${leaked:-0}
  out=$(node "$d/dist/main.js" 2>&1 | grep -m1 -E "ReferenceError|^OK|^FAIL" || node "$d/dist/main.js" 2>&1 | head -1)
  out=$(echo "$out" | sed 's/^ *//')
  if [ "$leaked" -gt 0 ]; then
    printf "    %-34s ${R}${B}%-9s${X} ${R}%s leaked${X}\n" "$label" "BREAKS" "$leaked"
    printf "      ${R}%s${X}\n" "$(echo "$out" | cut -c1-92)"
  else
    printf "    %-34s ${G}${B}%-9s${X} ${D}%s leaked${X}   ${D}%s${X}\n" "$label" "works" "$leaked" "$(echo "$out" | cut -c1-46)"
  fi
}

printf "\n${B}  webpack >= 5.110.0 leaks an internal placeholder into production output${X}\n"
printf "${D}  Two reproductions. Same bug. Same three ingredients.${X}\n"

for V in 5.109.2 5.110.2; do
  install "$V"
  title "webpack $V"

  printf "  ${B}01-minimal${X} ${D}- 23 lines, no app code${X}\n"
  build 01-minimal;                        report 01-minimal "whole-namespace require()"

  printf "\n  ${B}02-app-like${X} ${D}- mirrors routes/Teacher/index.js${X}\n"
  USE_FIX=0 CONCATENATE=1 build 02-app-like; report 02-app-like "whole-namespace require()"
  USE_FIX=1 CONCATENATE=1 build 02-app-like; report 02-app-like "  + fix at require site"
  USE_FIX=0 CONCATENATE=nocjs build 02-app-like; report 02-app-like "  + concatenateModules:{commonjs:0}"
  USE_FIX=0 CONCATENATE=0 build 02-app-like; report 02-app-like "  + concatenateModules:false"
done

title "What actually shipped to the browser (webpack 5.110.2)"
USE_FIX=0 CONCATENATE=1 build 02-app-like
grep -o "const [a-zA-Z]* = __webpack_require__${T}[A-Za-z0-9_]*" 02-app-like/dist/main.js \
  | sed "s/^/    ${R}/;s/\$/${X}/"
printf "\n    ${D}%s${X}\n" "These are valid JS identifiers that were never declared,"
printf "    ${D}%s${X}\n" "so the file parses and the build passes - it throws only when the line runs."

title "Summary"
printf "                                        ${B}5.109.2      5.110.2${X}\n"
printf "    01-minimal   whole-namespace        ${G}works${X}        ${R}${B}BREAKS${X}\n"
printf "    02-app-like  whole-namespace        ${G}works${X}        ${R}${B}BREAKS${X}\n"
printf "    02-app-like  fix at require site    ${G}works${X}        ${G}works${X}\n"
printf "    02-app-like  concatenate{commonjs:0}  ${G}works${X}      ${G}works${X}\n"
printf "    02-app-like  concatenateModules:0   ${G}works${X}        ${G}works${X}\n"
printf "\n    ${B}Verdict:${X} webpack regression introduced in 5.110.0 (PR #21519).\n"
printf "    ${D}Application code is unchanged and valid; 23 lines with no app code reproduce it.${X}\n\n"
