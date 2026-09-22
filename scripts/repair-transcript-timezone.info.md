# repair-transcript-timezone

Puts the archive of saved conversations back onto the days they happened.

## What it is for

Every conversation is saved as a markdown file named after its date. Those
names were computed in the wrong timezone, so anything held after about five
in the evening was filed under the following day, and every file's modified
time sat several hours ahead of itself. The exporter that writes new
transcripts has been corrected. This corrects the ones already written.

Most of the original session logs have been deleted, so the files cannot
simply be recomputed. This works from whatever evidence each one still has.

## The one design decision worth knowing

**A timestamp is evidence that can be disproved, not a fact.**

A bulk copy or a restore rewrites every file's modified time to the moment of
that operation. One folder here holds 299 transcripts of which 297 carry the
identical second. Treating those as conversation dates produced names
claiming three-week conversations that never happened.

Counting files per timestamp does not catch it, because a conversation and
its sidechains honestly do share a last message — a hundred files on one
second can be perfectly truthful. The test that works is a second witness:
where the prompt history knows roughly when a session ended, a timestamp
sitting a day or more past that is recording something that happened *to* the
file rather than *in* it. One such disproof condemns that timestamp for every
file sharing it, because one event wrote them all.

Where every witness fails, the file is reported and left alone. An archive
that quietly invents dates is worse than one with acknowledged gaps.

## The second design decision worth knowing

**Running it twice would corrupt the archive, so it refuses to.**

Undoing the fault means converting a timestamp twice over, and that operation
cannot tell whether it has already been done. Applied to an already-corrected
time it simply subtracts the offset again. Measured on a real evening
conversation dated this way: `02:49` becomes the correct `19:49`, then
`12:49`, then `05:49`, and given enough runs it crosses midnight and starts
renaming the file into the wrong day.

This applies only to files dated from their own timestamp. A file dated from
the prompt history takes both of its ends from counts of milliseconds since
the epoch — instants named outright, with no dependence on the file's current
state — so deciding it twice gives the same answer twice, and no note is
needed to protect it.

For the rest, nothing inside a transcript distinguishes a corrected timestamp
from an uncorrected one, so the fact has to be written down. Each folder gets
a `.timezone-repaired` note once its files are in place, and folders holding
one are skipped.

The note lives beside the transcripts rather than in a central ledger on
purpose: restoring a folder from a snapshot taken before the repair also
removes its note, which is exactly right, because that folder does need
repairing again.

## If a run is interrupted

Renames go through a temporary name so that a cycle of files swapping names
cannot clobber. An interruption therefore leaves a folder mid-step: every
file present and unharmed, every name wrong.

    repair-transcript-timezone --recover

puts them back. The temporary name carries the original inside it and a move
never alters a modification time, so the reversal is exact. The tool refuses
to plan anything while parked files exist, rather than reading half a folder
and concluding the other half was never there.

## The five verdicts

    rebuild        The session log still exists. Not touched here — the
                   exporter rebuilds it from source, which recovers both
                   ends properly. Run rederive-transcripts afterwards.

    history        Log gone, session in the prompt history. Both ends come
                   from it and the file's timestamp is ignored, so the
                   verdict is repeatable. The end is the last prompt, not
                   the assistant's closing reply — a distinction that moves
                   the calendar day for one file in sixty-eight.

    stamp          No history, but a sound timestamp. The fault is inverted
                   back out of it, which is exact.

    no-evidence    Timestamp disproved and no history. Left untouched and
                   reported.

## Commands

    repair-transcript-timezone
        Report what would change. Writes nothing.

    repair-transcript-timezone --verbose
        As above, listing every rename and every file left for want of
        evidence.

    repair-transcript-timezone --write
        Perform the renames and correct the timestamps. Folders already
        carrying a repair note are skipped.

    repair-transcript-timezone --recover
        Undo a run that stopped part-way, putting any parked files back
        under their own names.

    repair-transcript-timezone --commit
        As --write, then one commit per repository. Staging and commit are
        both limited to transcript paths, so unrelated work in progress in
        those repositories is neither committed nor disturbed.

    repair-transcript-timezone --only <path>    restrict to one subtree
    repair-transcript-timezone --dir <path>     where the scripts live
    repair-transcript-timezone --help

## Run order

This tool first, `rederive-transcripts --write` second. The exporter is the
naming authority and is idempotent, so it settles last and claims whatever
name slots remain.

## How the fault is inverted

The stored timestamp was built by taking a UTC clock reading and constructing
an instant from it as though the reading were local. So rendering the stored
value back in local time returns that original UTC reading verbatim, and
reading those same characters as UTC gives the true instant. The error
cancels exactly, daylight saving included, because each half consults the
rules in force on its own date.

## Where the work happens

Planning is `libs/transcript-repair-plan.lua`, which decides and changes
nothing. This script finds the folders, supplies each file's stored timestamp
(Lua cannot ask the filesystem for one), and carries the plan out. Deciding
and acting are kept apart so a wrong answer can be read before it becomes a
wrong rename.

Scratch files live in `/dev/shm/transcript-timezone-repair`, created on each
run.

## Related

- `issues/018-date-range-transcript-naming.md` — the ticket, including the
  measurements and the open questions
- `libs/transcript-repair-plan.lua` — the planner
- `libs/conversation-parser.lua` — the exporter's parser, which exports the
  UTC-to-instant helper this tool reuses rather than copying
- `tests/test-transcript-repair-plan.sh` — the planner's tests
