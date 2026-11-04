# install-fonts.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/install-fonts: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```

install-fonts -- put the site's monospace font where the generated pages expect
to find it.

In one line: copies fonts/*.ttf into output/fonts/ so that every poem
page renders its box-drawing grid from a font we shipped, rather than from
whatever the visitor's device happens to own.

Why this exists at all: the poem pages draw their frames, bars and navigation
boxes entirely out of Unicode box-drawing characters, and a phone's default
monospace font does not contain them -- Android's contains none of the twenty
the layout uses. The browser then borrows those glyphs from a proportional
font whose characters are a different width, and every frame tears out of
alignment. Shipping the font removes the guesswork.

Usage:
  scripts/install-fonts            # uses the DIR below
  scripts/install-fonts /some/path # treat /some/path as the project root

Exit status is non-zero if a font is missing, because a page that references a
font that is not there falls silently back to the broken rendering -- the
failure looks like nothing at all, so the build must be the thing that notices.

--help: print the header above and exit, before any work (libs/script-help.sh)
```
