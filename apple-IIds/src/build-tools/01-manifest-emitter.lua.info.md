# src/build-tools/01-manifest-emitter.lua

Writes `tmp/build/manifest.txt` — the deliverable's table of contents.
One line per file under the build root, sorted by path:

    <relative-path>  <size-in-bytes>  <sha256>

The manifest exists so a reader (developer, future-us, `deploy.sh`)
can answer "what is in this build, and is it the same bytes as last
time?" without scanning the bundle by hand. Sorting makes the manifest
reproducible: same files in same bytes → byte-identical manifest.

## external surface

| function          | input            | output                                |
|-------------------|------------------|---------------------------------------|
| `M.emit(root)`    | path to a dir    | writes `<root>/manifest.txt`          |

## invocation

    luajit src/build-tools/01-manifest-emitter.lua tmp/build

The bundle stage of `build.sh` calls this script.

## host dependencies

- `find` (POSIX)
- `sha256sum` (coreutils) — if missing, hashes record as `unknown` and
  a warning prints
- a host Lua (LuaJIT preferred, plain Lua 5.x acceptable)
