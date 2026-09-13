# The archive, and its two branches

Where fetched bytes go, how they are shaped, and how someone else gets them.

## The promise

Every byte fetched is kept exactly as it was received, forever, and nothing
downstream ever edits an archived file. When an extractor turns out to have been
wrong - and one will - the repair is to extract again, not to fetch again. This
matters because re-fetching does not return what was fetched before. A source
edits a page, a repository force-pushes, a spreadsheet owner revokes sharing,
and the thing you saw is gone. The archive is the only copy of what was true
when we looked.

Provenance travels with every archived file: what was asked, of whom, when, what
came back, and what the response claimed about itself.

## Two branches

The repository carries the project twice, at two weights.

**The minimal branch** holds the code and the documentation and no archive. It
is what someone clones when they intend to gather the history themselves. It is
small, it clones instantly, and running the harvester against it reproduces the
archive from the sources.

**The history branch** holds the same code plus the archived bytes. It is what
someone clones when they want the history without spending days politely asking
other people's servers for it. Cloning it is the considerate option, because
every clone of it is a fetch that nobody else's server has to serve.

That relationship is the point. The two branches are not a fast copy and a slow
copy - they are a choice between costing this project's owner disk and costing
strangers bandwidth.

## What may be rehosted, and what may not

Rehosting is only legitimate where the source's licence permits it, and that is
checked per source rather than assumed because the data is public. Public and
freely licensed are different claims.

Each source's registry entry therefore carries a licence field with three
possible states:

| State | Meaning | Where the bytes live |
|---|---|---|
| verified redistributable | licence read, and it permits rehosting | history branch |
| verified not redistributable | licence read, and it forbids or is silent on rehosting | gitignored, local only |
| unchecked | nobody has read it yet | gitignored, local only |

Unchecked behaves exactly like forbidden. That is deliberate: the failure of
omission and the failure of permission have the same consequence for someone
else's rights, so they get the same treatment until a person has actually read
the licence and written down what it said.

The extracted facts are a separate question from the archived bytes. A fact
derived from a source - "this ability had this coefficient in this build" - is
not the same artefact as the source's own file, and the two do not necessarily
carry the same permissions. The registry records both judgements separately.

## Small, specific files

The archive is stored as many small files rather than few large ones, capped at
roughly a megabyte, with the exact cap depending on what kind of file it is.

This is a git constraint before it is anything else. Git stores a changed file
by keeping a whole new copy of it, so one large file that is appended to
repeatedly costs its full size on every single change, while a thousand small
files that mostly do not change cost nothing at all. Clone time, garbage
collection time, and the memory a diff needs all follow the same rule.

There are two ways a file gets small, and both are used:

- **Fetched small.** Where a source can be asked for one narrow thing, it is
  asked for one narrow thing. This is also the polite way to ask.
- **Split afterwards.** Where a source only answers in bulk - a half-megabyte
  index of every build ever shipped, a multi-megabyte table dump - the bulk
  response is archived whole, and then a splitting pass at the end of gathering
  cuts it into the small specific files that everything downstream reads.

The word carrying the weight there is **specific**. A file is not split at an
arbitrary megabyte boundary; it is split along the seam the data already has, so
that each resulting file is one coherent thing that can be named for what it
contains. Builds split by product line and year. Table dumps split by table and
by build. A spreadsheet workbook splits into its individual sheets.

The test for whether a split was done right: the filename alone should tell you
what is inside, and nothing inside should belong under a different filename.

## Open sub-questions raised by this shape

- The exact cap per kind of file. A megabyte of plain text diffs well; a
  megabyte of dense numeric data does not compress or diff the same way.
- Branch names for the two branches.
- Whether the splitting pass runs at the tail of each gathering session or as a
  separate deliberate step, and what happens to an un-split bulk response that
  is sitting in the archive when someone clones.
