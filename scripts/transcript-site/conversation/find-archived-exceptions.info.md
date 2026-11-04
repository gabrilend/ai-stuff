# find-archived-exceptions (and make-default-palette)

Two generators, so neither of the files they write is ever edited by hand.

## find-archived-exceptions [scripts-dir]

Reads every transcript on the machine (the same places and depth
`rederive-transcripts` searches, worktrees and backups left out) under the
exporter's current rules with no exceptions, and writes
`archived-exceptions.lua`: the session ids of transcripts whose only fault
is a missing "Generated on" line AND whose session log is gone. Prints how
many read, how many were listed, how many files were not transcripts, and
every other refusal as a problem (exit 1). A problem is a transcript that can
still be rebuilt, or a shape the reader does not know.

## make-default-palette [scripts-dir] [balance-table]

Writes `default-palette.lua` from double-diaper-dungeon's balance table:
the seven colours in `site-palette.lua`'s `WANTED` list. Run again after
the game's colours are tuned.
