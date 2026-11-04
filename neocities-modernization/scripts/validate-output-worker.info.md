# validate-output-worker.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/validate-output-worker.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
validate-output-worker.lua -- checks one share of the site's pages.

WHAT IT DOES (for a CEO): the site is drawn out of fixed-width text; a line
one character too long breaks the frames around a poem, and a link to a
file that was never written is a page-not-found.  This reads a batch of
pages and writes down every over-wide line and every broken link it finds.
scripts/validate-output runs many of these at once, one per processor, and
merges what they found.  (Issue 9-006.)

project-dir: none -- an internal worker: scripts/validate-output hands it a
width, a findings file and a batch of page paths through xargs, so its
words are its data (a list thousands long), and it reads no project folder.

Usage: luajit scripts/validate-output-worker.lua MAX_WIDTH FINDINGS_FILE PAGE...
  MAX_WIDTH      widest allowed line inside a poem column, in visible
                 characters: the frame's width (84: a wall, a space, 80
                 characters of text, a space, a wall), which every frame
                 piece, regular or golden, must be exactly
  FINDINGS_FILE  where this worker writes its findings, one per line:
                 wide <TAB> page <TAB> line number <TAB> width <TAB> cause
                      <TAB> excerpt
                 shape <TAB> page <TAB> line number <TAB> width <TAB> frame
                      piece <TAB> what is wrong: excerpt
                 link <TAB> page <TAB> line number <TAB> target <TAB> count
                      <TAB> (empty)
                 An over-wide line is one row each.  A missing link target
                 is ONE row per target per worker, carrying how many times
                 it was seen and the first page/line it was seen on: a site
                 with its similar pages missing has millions of broken
                 links, and one row each filled 4 GB of RAM.
  PAGE...        the HTML files to check

--help: print the header above and exit, before any work (libs/script-help.lua)
```

## Inside (local to the file)

### `visible_width(text)`

```
Width as a reader sees it: tags removed, each entity (&amp; &#39;) one
character, each UTF-8 character one column, an emoji two (as the drawer
counts and draws it).
```

### `cause_of(plain)`
(No comment above it in the source.)

### `P(spelling)`

```
Readable names for the stand-ins, used to spell the patterns below as
"@" plus a letter (so the letters of "similar" are left alone):
  @H ═  @h ─  @J ╧  @j ┴  @K ╩  @k ╨  @L ╘  @M ╚  @R ┘  @r ┐
  @N ╔  @O ┌  @U └  @T ╠  @Q ╗  @t ┤  @V │  @W ║
```

### `spell_in_letters(plain)`

```
The line with each box character replaced by its letter (others kept).
Returns the spelling and the list of spelled characters, one per column.
```

### `shape_problem(plain, width)`

```
If the line is a frame piece, returns (shape name, what is wrong) when it
is the wrong width or has a junction out of place; nil when it is fine or
is not a frame piece.
```

### `file_exists(path)`
(No comment above it in the source.)

### `resolve(page_dir, href)`

```
A relative link resolved against the folder of the page it sits in, with
"." and ".." walked out, so the check asks the filesystem about the real
target.  Returns nil for links that are not files on this site.
```

### `record(kind, page, line_number, value, cause, excerpt)`

```
Over-wide lines: written as they are found.
```

### `record_missing_link(page, line_number, target)`
(No comment above it in the source.)
