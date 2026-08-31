# 149-the-documentation-site — info

Every document this project has, as one cross-linked site you can open in a browser with nothing running.

The writing here is spread over five directories and about two hundred files, and the most valuable thing about it is that the files refer to each other constantly. A ticket names the documents it depends on. A source page names the tests that check it. A design note names the ticket that proved it wrong. On disk those references are bare numbers you have to go and look up by hand. This turns every one of them into something you click, puts a list of everything down the left, and -- the part that does not exist on disk at all -- shows every page the things that point AT it.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `149-the-documentation-site.lua` and run the sweep again.*

## Invocation

```
luajit 149-the-documentation-site.lua               build into docs/HTML/
luajit 149-the-documentation-site.lua --to PATH     build somewhere else
luajit 149-the-documentation-site.lua --quiet       build without the report
```

## What it offers

| | What it is |
|---|---|
| `M.collect(dir)` | Every document in the project, as a list of pages. |
| `M.resolver(pages)` | Builds the function that turns the text of a code span into a destination. |
| `M.references(pages, resolve)` | Which pages point at which. Walks every code span in every document before anything is rendered, so that by the time a page is written it already k... |
| `M.build(dir, out_dir, quiet)` | The whole site. Returns a report: how many pages, which references collided, and everything pointed at that does not exist. |

### In more detail

**`M.collect(dir)`**

```
Every document in the project, as a list of pages. Each page is:

  kind     "document" | "note" | "strategem" | "issue" | "source" | "index"
  key      the leading number if it has one -- "011", "107a", "502"
  name     the filename without its extension
  title    the first heading in the file, or the name
  file     the html file it becomes, prefixed by kind so nothing collides
  source   where it came from, shown at the foot of every page
  text     the markdown itself
  phase    for tickets, the first digit -- which is the phase it belongs to
  status   for tickets, "open" or "completed"

The kind prefix on the filename is not decoration: there is a document `102`
and a ticket `102`, and without the prefix one would overwrite the other.
```

**`M.resolver(pages)`**

```
Builds the function that turns the text of a code span into a destination.
Returns that function, the list of collisions it had to settle, and a table
it fills in as it goes with every reference that pointed at nothing.

What it will follow:

  `502`                     a bare number -- ticket, then document, then source
  `144-assemble-a-machine`  a full name, which is never ambiguous
  `018-launch-board.lua`    the same, with the extension people actually type
  `docs/011-roadmap.md`     a path, as written in a table of contents

Precedence on a bare number is ticket, document, source, and it is only ever
exercised by the first-phase tickets. It is settled this way because the prose
that writes `105` means the ticket every time it was checked, and the program
of the same number is always written out in full where it is meant.
```

**`M.references(pages, resolve)`**

Which pages point at which. Walks every code span in every document before
anything is rendered, so that by the time a page is written it already knows
what points at it.

This is the one thing the site has that the files do not. On disk a reference
runs one way and the only way to find what mentions a document is to search
the whole project; here it is at the foot of the page.

**`M.build(dir, out_dir, quiet)`**

The whole site. Returns a report: how many pages, which references collided,
and everything pointed at that does not exist.

## What it reads, and what it never writes

Everything in docs/, notes/ and strategems/, every ticket open and completed, and the companion page beside every source file. It writes only into the output directory. If a page is wrong on this site it is wrong in the file, and the file is where it gets fixed -- which is why nothing here is editable and every page says where it came from.

## The hard part is the bare numbers

This project cites things as `502` and `029`, three digits either way, and a number alone does not say whether it means a ticket, a design document or a source file. Most do not collide, because the ticket numbers mostly start above the file indices -- but the first-phase tickets sit exactly on top of real source files, so `105` is both a ticket and a program. The ticket wins there, because that is how the prose uses it, and the full-name form `105-the-watchdog` still reaches the program. Every collision is printed at the end of a build. A wrong link that announces itself is a different thing from one that does not.

## References to things that are not there are left alone and counted

They come out as plain text, and the build ends by listing them, so the last thing this prints is an inventory of everything the project points at and does not have.

## When that list is not empty, the documents are wrong and that is the fix

The first build reported eight, all of them pointing at things deliberately removed -- a deleted status system, an old filename, sub-issue names reserved and never used. The temptation is to write the explanations down somewhere and have this forgive them. That would be a second copy of the history, kept by hand, beside the one git already keeps perfectly. The documents were corrected instead, and an empty list means what it says.

## Where it sits

**Checked by** `151-test-the-documentation-site`.

