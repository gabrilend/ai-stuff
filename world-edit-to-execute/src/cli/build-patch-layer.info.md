# build-patch-layer.lua

Builds a patch layer from a Warcraft III patch program, without running it.

| Argument | Meaning |
|----------|---------|
| `--dir DIR` (optional, first) | project root |
| `<patch-program.exe>` | the patch program, e.g. `War3TFT_121b_English.exe` |
| `<version>` | the layer's name, e.g. `1.21b` |

Reads the install through `wc3-installs/frozen-throne` and writes to
`wc3-installs/patch-layers/<version>/`, which must be a link to a folder
beside the installs (the layer holds Blizzard's files). Prints the counts of
archive and install files, diffs and whole files, and the version limit the
patch declares.
