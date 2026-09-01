# webpack ≥ 5.110.0 leaks an internal placeholder into production output

webpack emits its own unsubstituted internal token,
`__WEBPACK_MODULE_REFERENCE__…__`, into the shipped bundle. The file parses, so
the build succeeds — it throws only when that line runs:

```
ReferenceError: __webpack_require____WEBPACK_MODULE_REFERENCE__0_ns_moduleExportsAccess_asiSafe1__ is not defined
```

Regression introduced in **5.110.0**. Still present in **5.110.2** (latest).

## Run it

```bash
./verify.sh
```

Builds the reproduction on 5.109.2 and 5.110.2. Six builds; only one goes red:

```
                                     5.109.2      5.110.2
  whole-module require()             works        BREAKS
    + concatenateModules{commonjs:0} works        works
    + concatenateModules:false       works        works
```

## The reproduction

```js
// src/route.js
export function load() {
  return new Promise(resolve => {
    require.ensure([], require => {
      const whole = require("./mod.js");      // whole module object captured
      resolve([whole.NAME, whole.default]);
    }, "chunk");
  });
}
```

`src/mod.js` is an ordinary ESM module exporting `NAME` and a `default`.

What lands in `dist/main.js` (left unminified on purpose):

```js
const whole = __webpack_require____WEBPACK_MODULE_REFERENCE__0_ns_moduleExportsAccess_asiSafe1__._;
```

A valid JavaScript identifier that was never declared.

## What triggers it

Three ingredients. Remove any one and the bug disappears:

1. a `require.ensure` boundary
2. `require()` of an **ESM** module where the **whole module object** is captured
3. `optimization.concatenateModules` (scope hoisting) — on by default in
   `mode: "production"`, off in development

Point 3 is why this never appears on a dev server and only bites in production.

## Fix

Take the property **at the require site**, so webpack never needs a reference to
the whole module object:

```js
resolve([
  require("./mod.js").NAME,
  require("./mod.js").default,
]);
```

Destructuring is **not** a fix — it still leaks the placeholder:

```js
const { NAME, default: d } = require("./mod.js");   // still broken
```

If the call sites cannot change, `optimization.concatenateModules:
{ commonjs: false }` avoids it while keeping ESM scope hoisting.
`concatenateModules: false` also works, but disables scope hoisting bundle-wide.

## Cause

`_moduleExportsAccess` is a flag added in 5.110.0 by
[#21519](https://github.com/webpack/webpack/pull/21519). In
`lib/optimize/ConcatenatedModule.js` the
`moduleExportsAccess && info.type === "concatenated"` branch calls
`neededNamespaceObjects.add(info)`, then reads `info.namespaceObjectName` behind
a non-null cast. When that name is not yet assigned, nothing replaces the
placeholder and it reaches the output.

## Layout

```
src/index.js       entry
src/route.js       the failing pattern
src/mod.js         an ESM module exporting NAME + default
webpack.config.js  CONCATENATE=0 / CONCATENATE=nocjs toggles
verify.sh          builds every combination on both webpack versions
```
