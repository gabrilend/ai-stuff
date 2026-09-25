# build-patch-layer.lua

Builds patch layers from Warcraft III patch programs, without running them:
one at a time, or the whole stack in version order.

| Argument | Meaning |
|----------|---------|
| `--dir DIR` (optional, first) | project root |
| `<patch-program.exe> <version>` | build one layer on the disc install alone, e.g. `War3TFT_121b_English.exe 1.21b` |
| `--stack` | build every Frozen Throne program recorded in `wc3-installs/patch-programs/sources.tsv`, in the order of the versions they produce, each on the layers below |
| `--stack --up-to VERSION` | the same, stopping after that layer (e.g. `1.24e`) |
| `--install-layer VERSION` | for a version with no patch program (1.29.2): link the data archives the fetch script kept under `patch-programs/VERSION/` into an install layer; archive order and program names are in `INSTALL_LAYERS` in the script; a layer whose archives' checksums match is left alone |

Reads the install through `wc3-installs/frozen-throne` and writes to
`wc3-installs/patch-layers/<version>/`, which must be a link to a folder
beside the installs (the layer holds Blizzard's files). Prints each layer's
counts of archive and install files, diffs and whole files, and how many
diffs each base supplied.

In stack mode a layer whose manifest names the same program (by CRC32) and
the same layers beneath is reported `present` and left alone; otherwise it
is rebuilt, and every layer above it too. Running it twice changes nothing.
