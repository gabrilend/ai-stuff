# 205 - The splitting pass

| | |
|---|---|
| Phase | 2 - the harvester |
| Blocked by | 204 |
| Blocks | committing the archive to the history branch |

## Current behaviour

Nothing splits anything. A bulk response would sit in the archive whole.

## Intended behaviour

Bulk responses get cut into small specific files, capped at roughly a megabyte,
with the cap depending on what kind of file it is.

This is a git constraint before it is anything else. Git stores a changed file
by keeping a complete new copy of it, so one large file appended to repeatedly
costs its full size every single time, while a thousand small files that mostly
do not change cost nothing. Clone time, garbage collection and diff memory all
follow the same rule.

The important word is **specific**. A file is not cut at an arbitrary megabyte
boundary - it is cut along a seam the data already has, so each piece is one
coherent thing that can be named for what it holds. The build history splits by
product line and then by year. A table dump splits by table and by build. A
spreadsheet workbook splits into its individual sheets.

The test for a correct split: the filename alone tells you what is inside, and
nothing inside belongs under a different filename.

The original bulk response is not deleted. It stays in the archive as the thing
that was actually received, and the split pieces are derived files stored
alongside it. Deleting the original to save space would trade the archive's one
promise for disk.

## Suggested implementation steps

1. Each registry entry declares its split seam; each seam has a splitter that
   knows the format.
2. Run the pass at the end of a gathering session rather than during it, so a
   harvest that is interrupted leaves whole responses rather than half-split
   ones.
3. Decide the cap per kind of file. Plain text and delimited data diff well at a
   megabyte; dense numeric data does not compress or diff the same way and
   likely wants a smaller cap. This is unresolved - see the archive document's
   open sub-questions.
4. Make an un-split bulk response detectable, so that committing to the history
   branch can refuse while one is outstanding rather than committing a file that
   will make every future clone slower.
