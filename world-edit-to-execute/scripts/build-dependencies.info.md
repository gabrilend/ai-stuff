# build-dependencies.sh

Compiles the project's third-party libraries from source, one by one, into
the project-local `deps/` folder. Nothing is installed system-wide.

## Options

| Option | Does |
|--------|------|
| (none) | builds every dependency at its pinned version; skips those already built |
| `--only NAME` | builds one dependency |
| `--force` | rebuilds even if already built |
| `--list` | shows each dependency, its pin, and whether it's built |
| `--list-tags NAME` | lists upstream's release tags, newest last |
| `--latest NAME` | pins NAME to its newest release tag and rebuilds it |
| `--pin NAME TAG` | pins NAME to TAG and rebuilds it |

A first argument not starting with `-` overrides the project root.

## What it produces

| Path | Tracked in git | Holds |
|------|----------------|-------|
| `deps/versions` | yes | one `name tag` line per dependency |
| `deps/<name>/` | no | the built library, plus `.built-from` (the tag it was built from) |
| `deps/licenses/<name>/` | no | every licence, copying and notice file from the dependency's source |
| `.build-tmp/<name>/` | no | source clone, build folder, configure and build logs |

## Dependencies today

| Name | Source | Licence | Output |
|------|--------|---------|--------|
| stormlib | github.com/ladislav-zezula/StormLib | MIT (bundles libtomcrypt, which carries no notice in StormLib's copy; upstream is public domain) | `deps/stormlib/lib/libstorm.so`, linked to the system's zlib and bzip2 |

Issue: `issues/completed/112a-stormlib-build-and-update-script.md`
