# update-toc

Checks that every document under a project's `docs/` is linked from its
`docs/table-of-contents.md`, and lists the ones that are not. The house rule
says a new document is added to that file when it is written; this is what
notices when one was not.

## Commands

    update-toc [DIR]
        Report, one line each: documents no link in the table reaches, and
        links in the table that reach no file (with their line number).
        Exit 1 if there are any, so it can sit at the end of a build.

    update-toc [DIR] --write
        List the unreached documents in the table's unfiled block (see below).
        A project with no table of contents gets a whole one instead.

    update-toc [DIR] --write --dry-run
        Print what --write would leave in the file, and change nothing.

    update-toc [DIR] --tree
        Print a whole table built from docs/'s folders, whether or not one
        exists. Useful for seeing what a project has before filing it.

    update-toc [DIR] --ignore PATTERN
        Leave out documents whose path from the project (`docs/history/x.md`)
        matches the Lua pattern. May be given more than once.

DIR defaults to the scripts project. Exit status: 0 nothing to report (or
--write / --tree did its work), 1 findings printed, 2 bad arguments or no
`docs/` folder.

## What it will and will not change

The tables on disk are written by hand -- grouped under headings, each entry
with a sentence saying what the document is for, some with status marks. So
`--write` never rewrites the table. It owns one block, between these two
lines, at the end of the file:

    <!-- update-toc: unfiled documents start -->
    ## Not Yet Filed
    ...
    - [W3E Terrain](formats/w3e.md)
    <!-- update-toc: unfiled documents end -->

Each run rebuilds that block from the documents nothing *outside* it links
to. Move a line from the block into its proper place above, and it leaves
the block on the next run; once everything is filed, the block disappears.
A start marker without its end marker stops `--write` with an error, because
guessing where the block ends could swallow the owner's text.

Dead links are reported and left alone, by `--write` too. Whether a link is
dead because its document moved, was renamed, or is planned is the owner's
call.

## How it reads a table

- Links are followed the way a viewer follows them: relative to `docs/`; a
  link starting with `/` from the project root.
- Inline links, `<angle-bracketed>` targets and `[name]: target` definitions
  count. Links inside code blocks or `inline code` do not -- they do not
  render as links -- so a tree drawn in a code block lists nothing.
- Web addresses, `mailto:` and bare `#anchors` are not files.
- A document's title is its first `# ` heading outside a code block, or its
  file name when it has none.
- Hidden files and folders are skipped; symbolic links to files are
  documents (the house links one guide into every project); a link to
  nothing is skipped.

## A whole table

For a project with none, the table is a nested list following the folders
under `docs/`, folders first in bold with a trailing slash, files by title.
A list rather than the box-drawn tree in a code block that issue A05 sketched,
because a link inside a code block is not a link. It carries no "last
updated" date: a stamp of when a tool ran is not a fact about the documents,
and would make an unchanged table differ on every run (the transcript
exporter learned this the hard way).

## Relationship to other tools

- `libs/table-of-contents.lua` -- the reading half; this is the CLI over it.
- `validate-issues` -- the same kind of check for `issues/`.
