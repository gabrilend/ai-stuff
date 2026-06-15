# develop.sh

Interactive companion to `build.sh`. Where `build.sh` applies and
immediately reverts within a single invocation, `develop.sh` applies
patches and *leaves them applied* so a developer can edit the patched
source for hours. `freeze` captures the changes back into the
project's `patches/` directory; `revert` returns the tree to pristine.

This is the only place where upstream trees in `libs/` are allowed to
carry our modifications across a tool invocation.

## commands

| command                  | effect                                                |
|--------------------------|-------------------------------------------------------|
| `./develop.sh gsplus`    | apply every `*.gsplus.patch`, leave applied           |
| `./develop.sh status`    | show what's currently applied                         |
| `./develop.sh freeze`    | diff the current dirty tree → `tmp/freeze-*.patch`    |
| `./develop.sh revert`    | un-apply every patch from the sentinel; restore tree  |

## sentinel

`tmp/.develop-applied` (separate from `build.sh`'s `tmp/.applied`)
records which trees are currently dirty. Distinct sentinel files mean
running a build while interactive edits are live raises a clear error
instead of silently mixing patch states.

## no gsos mode

There is no `develop.sh gsos`. GS/OS modifications are byte-level
patches against a binary disk image; there is no text-editor workflow.
See `docs/005-patch-conventions.md`.
