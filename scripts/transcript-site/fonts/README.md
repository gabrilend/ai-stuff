# Fonts

`HackNerdFont-Regular.ttf` and `HackNerdFont-Bold.ttf`: the monospace font the
transcript pages ask for, under the name `PoemGrid` (see
`libs/page-head.lua`). Copied on 2026-09-26 from double-diaper-dungeon's
`assets/fonts/`, which copied them from `neocities-modernization`.

`build-site.lua` writes them into a project's `llm-transcripts/HTML/fonts/`
whenever a file is missing there, so every project's pages render from the
same font file rather than whatever monospace the reader has installed. The
pages are not committed, so the copies cost disk space only.

Hack is released under the MIT License (its glyphs descend from Bitstream Vera
and DejaVu, whose licence travels with Hack); the Nerd Fonts patch that adds
the extra symbols is also MIT-licensed. Check the upstream projects for the
full texts before redistributing these files on their own.
