# Issue 10-077: The Download Comes In Pieces Neocities Will Take

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: High (it stops every deploy)
- **Type**: Bug / Enhancement
- **Status**: In progress -- built and tested; waiting on one deploy that
  uploads the 90 MB pieces
- **Created**: 2026-11-03
- **Related**: 10-052 (the source browser, whose every page carries the
  download link), 10-072 (the built site lives in RAM; its step 5 said the
  download could then live directly in the RAM site), 10-076 (folders named
  by flags; this script takes `--dir` the same way)

## Current Behavior

**Built, 2026-11-03; waiting on a deploy.** `scripts/build-download-zip
--dir PATH` builds the whole archive in RAM, copies it into pieces of
92,159 KiB (`zip -s 92159k --out`), checks each piece's size, writes
`index.html` (site colours from `src/page-theme.lua`), and renames the
building folder into the site as `output/download/`; it removes the old
single archive and link. The page gives zip and unzip first (`zip -s 0`
joins the pieces, `unzip` opens the result) and 7-Zip second. The source
browser links to `download/index.html`; `run.sh` calls the builder with
`--dir`. Run on the real site: 26 pieces, 2,257 MB; joined with `zip -s 0`
they make one 2,367,061,717-byte archive of 44,772 files that `unzip -t`
passes; the page check over all 25,466 pages finds no broken link. Notes:
`scripts/build-download-zip.info.md`. Test:
`scripts/build-download-zip.test.sh` (19 checks).

The piece size, and the zip bug behind it (found 2026-11-03; owner: "if you
can't find a report on the bug, then it's a problem on our end. .zip is too
common of a format, and the zip utility is too ubiquitous for us to request
our users use a different type. Find out why it's a problem."): Info-ZIP
zip 3.0's join (`zip -s 0`) loses data when a piece is a whole number of
its copy buffers. Its copy loop (`bfcopy`, `fileio.c`) moves to the next
piece only after a read comes up short; a piece after the first holds only
continuing data, so when it divides evenly into buffers every read is full,
the next read returns nothing, and the loop stops with no error -- every
byte of a file after its second piece is lost. The buffer is 16,384 bytes
on Linux (2,048 or 8,192 on some builds); the first plan's round 90 MiB is
5,760 of them. Measured: 10,240 KiB and 10,000 KiB pieces lost data, 10,239
and 10,241 KiB joined whole. An odd number of KiB is never a multiple of
2,048, so 92,159 KiB is safe on every build, and the builder stops if the
size ever becomes a multiple of 2,048. Only a file larger than one piece
is hit (the site's largest is 81 MB, so its round-90-MiB download would
have joined whole); the size keeps that true whatever the site holds. No
report of the bug was found; Info-ZIP has made no release since 2008.

Left before closing: one deploy that uploads the pieces. Each is one
upload request of about 90 MB; the older 90 MB archives went up by an
unknown route, so whether the upload API takes a request that large is not
yet known.

Before this issue, `scripts/build-download-zip` packed the published source and the whole built
site into one archive, `similar-different.zip`, kept in RAM
(`tmp/shared-memory/`) and linked from `output/`. Every source-browser page
links to it ("download everything (site + source)",
`src/generate-source-browser.lua`).

The archive is 2.37 GB (2026-11-02 build). Neocities takes no file over
100 MB, so the 2026-11-02 deploy stopped at about 30,000 of 42,850 files
with `request failed at minimum batch size (status 413) on
similar-different/similar-different.zip`. The deploy shuffles its upload
order each run, so a re-run stops again wherever the archive lands, and the
prune step after the upload is never reached. The largest file ever on the
live site is 94,371,840 bytes (90 MB): the owner's older archives,
`conversation-starters/conversation-starts.z01`..`.z11` + `.zip`, split for
this reason.

## Intended Behavior

Owner, 2026-11-03: "oh, yes, we should do that. See this page for examples:
https://ritz-menardi.neocities.org/conversation-starters/conversation-starters".
That page, in the owner's words: "you need to download all 11 files, sorry.
neocities won't let me put up files larger than 100mb." / "put them in the
same place and then extract the .zip file like normal and it'll figure
itself out." -- then one numbered link per piece, the `.zip` last.

- The archive is published as a split zip in pieces just under 90 MB
  (zip's own split format: `similar-different.z01`, `.z02`, ..., and the
  last piece `similar-different.zip`) -- 92,159 KiB, not the older archives'
  round 90 MiB, so zip's own join works (see Current Behavior).
- The pieces and a small page listing them live in `output/download/`; the
  page is plain, in the site's colours, and says how many pieces there are,
  that all of them go in one folder, and how to open them with the tools on
  nearly every machine: `zip -s 0` joins the pieces (`unzip` alone does not
  read a split archive), then `unzip`; 7-Zip as the other way.
- Every source-browser page's download link goes to that page.
- The archive never contains itself: `output/download/` is left out when the
  site is packed.
- No piece is over 92,159 KiB; the script stops if one is.
- The script takes its project folder as `--dir PATH` and refuses bare
  words (Issue 10-076's rule), and `run.sh` calls it that way.

## Suggested Implementation Steps

1. `scripts/build-download-zip`: build the whole archive in RAM as now
   (outside the site, so it cannot pack itself), then copy it into a split
   archive of 90 MB pieces in a building folder, remove the whole one, write
   the listing page, and swap the building folder in as `output/download/`
   only when complete. Remove the old `output/similar-different.zip` link and
   RAM file. Check every piece's size.
2. `src/generate-source-browser.lua`: the download link points at
   `download/index.html` (no `download` attribute: it is a page now).
3. `run.sh`: call `build-download-zip --dir "$DIR"`; update the comment that
   says the zip is moved into `output/`.
4. Test (`scripts/build-download-zip.test.sh`): a scratch project in RAM with
   git, a few source files and a 200 MB incompressible file in its site;
   expect three pieces, each no bigger than 90 MB, a page linking each piece
   once, a joined archive that tests clean and holds the big file, no
   `download/` inside the archive, and a bare word refused.
5. `.info.md` beside the script; docs that name `similar-different.zip`.

## Open questions

- None yet.
