# carry-back.sh

Moves commits out of a RAM sandbox and onto the disk.

## What it is for

A sandbox built by `init-project.sh` lives in tmpfs, so a power cut erases it.
This is the thing that stops that mattering: it watches the sandbox's branch and
copies each commit into the real repository the moment it appears. Committing
becomes the act that makes work permanent, and the volatility of RAM stops being
a risk and becomes just a property of the workspace.

## The one design decision worth knowing

**The real repository pulls from the sandbox. The sandbox never pushes.**

Had the sandbox pushed, it would need a writable handle on the real repository —
and that handle is a hole through the wall the sandbox exists to provide.
Anything running inside could reach through it. By inverting the direction,
every operation that touches the real repository runs outside the sandbox, and
the thing being read has no idea it is being read.

The same commits arrive either way. Only the direction of trust differs, and the
direction of trust is the entire security argument.

## Commands

    carry-back.sh <project>
        Watch continuously. Runs until interrupted. Started automatically by
        the project's launcher, so you rarely invoke this yourself.

    carry-back.sh --once <project>
        Carry whatever is pending, then exit. Run this before shutting down,
        or after tidying a dirty working tree.

    carry-back.sh --status <project>
        Report what is pending and whether it could land right now.
        Changes nothing.

    carry-back.sh --interval <seconds> <project>     default 5
    carry-back.sh --dir <path> <project>             different monorepo, for testing
    carry-back.sh --help

## How a commit lands

Three steps, and their separation is the safety property.

| Step | What happens | Can it be blocked? |
|---|---|---|
| 1 | Fetch the sandbox branch into `refs/carried/<project>` | No. Always succeeds. |
| 2 | Clear untracked files that duplicate incoming ones | Yes, if content differs |
| 3 | Fast-forward the real branch, updating the working tree | Yes, if the tree is dirty |

**Work becomes durable at step one.** Steps two and three only decide whether
you can see it yet. A dirty working tree, a divergent history, a conflicting
untracked file — none of these can lose a commit, because the commit reached
the disk before any of them were consulted. The script says so explicitly every
time it declines, because a refusal that sounds like a failure would send
someone hunting for work that was never in danger.

## Why each step is shaped the way it is

**Step 1 fetches into a staging ref rather than the branch.** Git flatly
refuses to fetch into a branch that is checked out somewhere, and the real
repository always has its branch checked out. A staging ref sidesteps that.
It also happens to be the safer ordering, since it puts the commit on disk
before anything about the working tree has been decided.

**Step 2 compares content, not names.** Git will not fast-forward over an
untracked file, because it cannot know whether that file is precious. Content
answers the question git cannot ask: identical bytes mean the file duplicates
what is arriving and deleting it loses nothing, different bytes mean two
writers chose the same filename with different intent — a real conflict, left
untouched and reported.

**Step 3 is `--ff-only`, never a merge.** If the histories have diverged,
something happened that a background script should not paper over — somebody
committed on both sides, or history was rewritten. Quietly synthesising a merge
commit would hide a situation a person needs to look at.

**Pending work is measured against the real repository, read live.** Not
against the sandbox's `origin` ref, which was captured when the sandbox was
cloned and does not move when a carry advances the real branch. Reading the
stale ref reports work as uncarried immediately after carrying it, and a safety
check that cries wolf is a safety check nobody reads.

**It polls rather than watching with inotify.** The check costs two ref reads
and a revision walk, so five-second polling is free, and polling recovers by
itself when the sandbox is destroyed and rebuilt underneath it — which a watch
on a vanished directory does not.

## Relationship to init-project.sh

`init-project.sh` builds the sandbox and generates a launcher that starts this
script in the background, then runs it once more on the way out. That final
catch-up matters: a commit made in the last seconds of a session might not have
been polled yet, and the end of a session is exactly when the last commit tends
to get made.

The real project directory has **exactly one writer, and it is this script.**
`init-project.sh` writes tracked content into the sandbox only. That rule is
what keeps untracked duplicates from accumulating on disk and blocking carries.
