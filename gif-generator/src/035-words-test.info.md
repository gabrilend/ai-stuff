# 035-words-test — proof for the word files

`luajit src/035-words-test.lua [DIR]`. Needs the RAM tiers (`./bootstrap`).

Checks: the shipped words (`ring`, `slowly`) load and pass their own check;
an alias reaches its pattern; a score using `ring` reads into two ordinary
strokes that compile, with an odd number of tenths kept in tenths; an
unknown pattern teaches the nearest; a pattern without word files, and a
plain word used as a pattern, are refused; a word file with the wrong name,
an unknown kind, no expand, or a reach for `io` is refused with its name.
Broken word files are written to RAM, never into the project.
