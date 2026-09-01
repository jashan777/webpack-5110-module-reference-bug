# webpack ≥ 5.110.0 leaks an internal placeholder into production output

`webpack` emits its own unsubstituted internal token,
`__WEBPACK_MODULE_REFERENCE__…__`, into the shipped bundle. The file parses
fine, so the build succeeds — it throws only when that line runs:

```
ReferenceError: __webpack_require____WEBPACK_MODULE_REFERENCE__1024_ns_moduleExportsAccess_asiSafe1__ is not defined
```

**Status:** webpack regression, first appearing in **5.110.0**. Not a bug in
application code — the pattern below is ordinary and unchanged.

## Run it

```bash
./verify.sh     # builds both cases on 5.109.2 and 5.110.2, colour-coded
```

Eight builds, and only the 5.110.2 whole-namespace rows go red:

```
                                        5.109.2      5.110.2
    01-minimal   whole-namespace        works        BREAKS
    02-app-like  whole-namespace        works        BREAKS
    02-app-like  fix at require site    works        works
    02-app-like  concatenateModules:0   works        works
```

## The reproduction

24 lines of source, no framework and no application code:

```js
// src/route.js
export function load() {
  return new Promise(resolve => {
    require.ensure([], require => {
      const whole = require("./mod.js");        // whole module object captured
      resolve([whole.NAME, whole.default]);
    }, "chunk");
  });
}
```

`src/mod.js` is an ordinary ESM module exporting `NAME` and a `default`.
`src/route.fixed.js` sits beside it with the one-line fix, so the diff is a
single file open.

## What triggers it

Three ingredients. Remove any one and the bug disappears:

1. a `require.ensure` boundary
2. `require()` of an **ESM** module where the **whole module object** is captured
3. `optimization.concatenateModules` (scope hoisting) — **on by default in `mode: "production"`, off in development**

Point 3 is why this is invisible on a dev server and only bites in production.

```js
require.ensure([], require => {
  // fine — a property is taken AT the require site
  const teacherReducer = require("./modules/TeacherModule.js").default;

  // BREAKS — the whole module object is captured, properties read later
  const worksheetModule = require("./modules/WorksheetModules.js");
  injectReducer(store, {
    key: worksheetModule.NAME,
    reducer: worksheetModule.default,
  });
}, err => reject(err), "teacher");
```

Emitted output (`dist/main.js`, unminified):

```js
const worksheetModule = __webpack_require____WEBPACK_MODULE_REFERENCE__4_ns_moduleExportsAccess_asiSafe1__._;
```

## Why it is a webpack bug, not a config problem

- The pattern is valid and works on 5.109.2 with an identical config.
- Webpack must either handle the case or fail the build. Emitting a
  syntactically valid but undefined identifier is an invariant violation:
  the placeholder is internal and should never survive code generation.

## Where it comes from

`_moduleExportsAccess` is a flag added in 5.110.0 by
[#21519](https://github.com/webpack/webpack/pull/21519) — *"Wrap concatenated
modules in lazy `__webpack_require__.cw` accessors and inline `require()`"*.

| file | 5.109.2 | 5.110.2 |
|------|---------|---------|
| `lib/ConcatenationScope.js` | flag absent | `(_moduleExportsAccess)?` added to the placeholder regex |

`lib/optimize/ConcatenatedModule.js` takes the
`moduleExportsAccess && info.type === "concatenated"` branch, calls
`neededNamespaceObjects.add(info)`, then immediately reads
`info.namespaceObjectName` behind a non-null cast. When that name is not yet
assigned, nothing replaces the placeholder and it reaches the output.

## Fixes

**Take the property at the require site** (recommended — keeps scope hoisting):

```js
injectReducer(store, {
  key:     require("./modules/WorksheetModules.js").NAME,
  reducer: require("./modules/WorksheetModules.js").default,
});
```

**Destructuring does _not_ work** — verified, still leaks:

```js
const { NAME, default: reducer } = require("./modules/WorksheetModules.js"); // ❌
```

**Targeted workaround** (verified here) — disables only CommonJS concatenation,
keeps ESM scope hoisting:

```js
optimization: { concatenateModules: { commonjs: false } }
```

**Blunt workaround:** `optimization.concatenateModules: false`. Also fixes it,
but disables scope hoisting bundle-wide. Measured on the real app: **+4.8 MB,
+2.6%** across 564 assets.

## Related, but not the same bug

A cluster of `#21519` regressions was filed and fixed in the same window. All
are *interop wrapping* faults (a value becomes `{ default: … }`); none is this
placeholder leak:

| issue | symptom | status |
|-------|---------|--------|
| [#21882](https://github.com/webpack/webpack/issues/21882) | `require()` of CJS returns `{default: exports}` | fixed by [#21884](https://github.com/webpack/webpack/pull/21884), **unreleased** |
| [#21899](https://github.com/webpack/webpack/issues/21899) | asset module becomes `{default: …}` via `.cw` wrapper | closed |
| [#21873](https://github.com/webpack/webpack/issues/21873) | `X_namespaceFn is not a constructor` | closed |

As of webpack **5.110.2** (latest release) this reproduction still fails.

## Layout

```
02-app-like/src/store.js               injectReducer stand-in
src/modules/*.js                      ESM modules exporting NAME + default
src/routes/Teacher/index.js           the failing pattern
src/routes/Teacher/index.fixed.js     the fix
webpack.config.js                     USE_FIX=1 / CONCATENATE=0 toggles
verify.sh                             builds every combination
```
