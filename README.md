# webpack ≥ 5.110.0 leaks an internal placeholder into production output

webpack emits one of its own internal placeholders,
`__WEBPACK_MODULE_REFERENCE__…__`, unsubstituted into the production bundle.

The result is a valid JavaScript identifier that was never declared, so the
build succeeds with no error or warning and it fails only at runtime:

```
ReferenceError: __webpack_require____WEBPACK_MODULE_REFERENCE__0_ns_moduleExportsAccess_asiSafe1__ is not defined
```

Works on 5.109.2. Breaks from 5.110.0 through 5.110.2 (latest).

## Reproduce

```bash
npm install
npx webpack        # succeeds
node dist/main.js  # ReferenceError
```

`dist/main.js` is left unminified, so the leaked token is visible:

```js
const whole = __webpack_require____WEBPACK_MODULE_REFERENCE__0_ns_moduleExportsAccess_asiSafe1__._;
```

Install `webpack@5.109.2` instead, with the same source and config, and it works.

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

If the call sites cannot change, set `optimization.concatenateModules` to
`{ commonjs: false }` to keep ESM scope hoisting, or `false` to disable it
bundle-wide. Both avoid the bug; `CONCATENATE=nocjs` and `CONCATENATE=0` select
them in `webpack.config.js`.

## Cause

`_moduleExportsAccess` is a flag added in 5.110.0 by
[#21519](https://github.com/webpack/webpack/pull/21519). In
`lib/optimize/ConcatenatedModule.js` the
`moduleExportsAccess && info.type === "concatenated"` branch calls
`neededNamespaceObjects.add(info)`, then reads `info.namespaceObjectName` behind
a non-null cast. When that name is not yet assigned, nothing replaces the
placeholder and it reaches the output.
