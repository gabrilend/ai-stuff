# 057-the-relinker

Repairs every relative link after an issue moves between directories.

Read this page rather than the source.

## What it is for

An issue lives in `issues/` while it is open and in `issues/completed/` once it
is done. That move breaks links in both directions and in complete silence:

- A link **inside** the issue that said `../docs/002-the-stone.md` now means
  `issues/docs/002-the-stone.md`, which is nowhere.
- A link **to** the issue, from the roadmap or from another issue, points at a
  gap.

Nothing warns. The links simply stop working and stay broken until somebody
clicks one. The first run of `./validate-documentation` found a hundred and nine
of them.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `relink(root)` | project root | how many files were changed, and what changed in each |

## How it decides

It works out where every issue **actually is** by listing both directories, then
rewrites every reference to match. It does not remember what moved and it does
not need to be told.

**It is idempotent.** Running it when nothing has moved changes nothing, which is
what makes it safe to run from `./complete-issue` every time and safe to run by
hand whenever something looks wrong.

## Use it through `./complete-issue`

    ./complete-issue 101        move that issue and repair the links
    ./complete-issue --relink   repair the links, move nothing

The move is a tool rather than a `mv` precisely so that the repair cannot be
forgotten. That is the same argument as `new-source-file` stamping the licence:
bookkeeping that rots the moment a person is asked to do it by hand should not be
asked of a person.
