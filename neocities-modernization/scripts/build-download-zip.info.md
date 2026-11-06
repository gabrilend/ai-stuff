# build-download-zip.info.md

<!-- written by hand (Claude, Issue 10-077, 2026-11-03): what scripts/build-download-zip does and gives -->

Builds the site's "download everything": the whole rendered site plus the
published source, as a split zip in pieces of 92,159 KiB (just under 90 MB)
with a page that lists them. Neocities takes no file over 100 MB; the
archive is a few GB (Issue 10-077).

## Command

`scripts/build-download-zip [--dir PATH]`

- `--dir PATH` (string): the project folder. Without it, the path written at
  the top of the script. Any other word stops the script with an error naming
  it (Issue 10-076).
- `--help`: the script's header, and nothing else.

`run.sh` runs it after the word-cloud stage and before the page check, so it
packs the finished site.

## What it reads

- `git ls-files` of the project, filtered to the folders the source browser
  publishes (`src libs scripts issues docs notes demos archive`) and root
  files ending in `.lua .sh .md .c .h .json .css .html .txt`. The list must
  match `src/generate-source-browser.lua`'s.
- `LICENSE`, if present (committed or not).
- `output/`, the built site, minus `output/download/` (the last build's
  pieces).
- `config.lua` `html_theme`, through `src/page-theme.lua`, for the page's
  colours.

## What it writes

| path | what |
|---|---|
| `output/download/similar-different.z01` ... `.zNN` | the numbered pieces, each exactly 94,370,816 bytes (92,159 KiB) |
| `output/download/similar-different.zip` | the last piece, the one a reader opens; up to 94,370,816 bytes |
| `output/download/index.html` | the page: how many pieces, their total size, how to open them, one numbered link per piece |

Along the way, in `tmp/shared-memory/` (RAM): the whole archive
(`similar-different.zip.building`, removed once split) and the building
folder (`similar-different-download.building`, renamed into the site when
done). It removes the single archive and its link from before Issue 10-077
(`tmp/shared-memory/similar-different.zip`, `output/similar-different.zip`).

## The piece size, and why it is not a round 90 MiB

Info-ZIP zip 3.0 joins split pieces with `zip -s 0 pieces.zip --out whole.zip`,
and that join drops data when a piece is a whole number of zip's copy buffers.
Its copy loop (`bfcopy`, `fileio.c`) moves to the next piece only after a read
comes up short. Every piece after the first is nothing but continuing data,
so when its size divides evenly into buffers, every read is full, the last
one ends exactly at the piece's end, the next read returns nothing, and the
loop stops with no error. Every byte of a file after its second piece is
lost -- so only a file bigger than one piece is hit. The buffer is 16,384
bytes on Linux (2,048 or 8,192 on some builds, `tailor.h`); exactly 90 MiB is
5,760 of them. An odd number of KiB is never a multiple of 2,048, so it is
safe on every build. The script stops before any work if `PIECE_BYTES` is a
multiple of 2,048.

Measured 2026-11-03, a 25 MB file in three pieces: 10,240 KiB and 10,000 KiB
pieces (multiples of 16,384 bytes) lost data; 10,239 KiB and 10,241 KiB
joined whole. The site's largest file at the time was 81 MB, under one
piece, so the round-90-MiB download would have joined whole anyway; the
size is chosen so that stays true whatever the site holds.

## Stops with an error when

- `PIECE_BYTES` is a multiple of 2,048, or `PIECE_SIZE` and `PIECE_BYTES`
  disagree;
- `output/` does not exist (build the site first);
- a piece comes out over `PIECE_BYTES`;
- any step fails (`set -euo pipefail`).

## Opening the pieces

The page gives the way that is on nearly every machine first:
`zip -s 0 similar-different.zip --out similar-different-whole.zip`, then
`unzip similar-different-whole.zip` (plain `unzip` does not read a split
archive, so zip joins it first). Second: 7-Zip, which opens the `.zip` piece
and finds the rest.

## Test

`scripts/build-download-zip.test.sh`: a scratch project in RAM with a 200 MB
random file, which spans all three pieces, a whole middle one included -- the
case that lost data. Three pieces, none over 94,370,816 bytes, a page linking
each once; `zip -s 0` and `unzip` bring the file back byte for byte, and so
does 7-Zip; the archive does not pack its own pieces; a bare word is refused.
Run by `scripts/run-tests` (the 7-Zip part says SKIP when 7-Zip is not
installed).
