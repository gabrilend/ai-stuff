# 051-shape-docs — the vocabulary's documentation, printed from its lists

Writes `docs/shape-format.md` from `048-shape-words.lua`, with the names
the runtime owns listed from the modules themselves, so a word cannot be
legal and undocumented, or documented and refused.

CLI: `luajit src/051-shape-docs.lua DIR [--check]`. `--check` writes
nothing and exits 1 when the file is missing or out of date;
`./test-shape-films` runs it.
