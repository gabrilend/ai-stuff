# build.sh

End-to-end build orchestrator. Walks the patch surfaces from
`docs/005-patch-conventions.md` with the apply / build / revert
discipline: each stage applies only its layer's patches, runs that
layer's tool, then reverts. Upstream trees in `libs/` stay pristine
between stages.

## stages

| stage         | input                                | output                              |
|---------------|--------------------------------------|-------------------------------------|
| `gsplus`      | `libs/gsplus/` + `patches/*.gsplus.patch` | `tmp/build/gsplus` (aarch64 binary) |
| `gsos-addons` | `src/gsos-addons/*/`                 | `tmp/build/addons/*`                |
| `disk-image`  | `assets/disks/gsos-boot.2mg` + `patches/*.gsos.bin.patch` + addons | `tmp/build/gsos-boot.2mg` (patched copy) |
| `broker`      | `src/broker/`                        | `tmp/build/broker/`                 |
| `luajit`      | `libs/luajit/`                       | `tmp/build/luajit/`                 |
| `bundle`      | everything above                     | `tmp/build/manifest.txt`            |

## invocation

| invocation                         | effect                              |
|------------------------------------|-------------------------------------|
| `./build.sh`                       | run every stage in order            |
| `./build.sh --stage gsplus`        | run just one stage                  |
| `./build.sh --clean`               | wipe `tmp/build/` and rebuild       |
| `./build.sh /custom/dir`           | override the project DIR            |

## sentinel

`tmp/.applied` lists every patch currently applied to an upstream
tree. A crashed build leaves it behind; the next invocation detects
the inconsistent state and reverts everything before starting.

## what it does not do

- Does not fetch dependencies (use `scripts/build-deps.sh`).
- Does not deploy to the device (use `deploy.sh`).
- Does not keep patches applied across invocations — that's `develop.sh`.
