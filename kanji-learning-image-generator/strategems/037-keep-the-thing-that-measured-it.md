# 037 — Keep the thing that measured it

**Pattern.** When a constant in a program is really a claim about a dataset,
make the thing that measured it a mode of the file it configures, not a script
you delete afterwards.

## Where it came from

`021` sorts strokes into five directions. The boundaries between those
directions are numbers. Written by hand they would have been guesses that looked
like engineering; measured off the archive, three of them came out somewhere
nobody would have put them:

- the range that catches horizontal strokes is **not centred on level**, because
  a Japanese horizontal is written with a deliberate slight rise
- size had to be pulled apart from direction, because a dot and a long sweeping
  stroke travel the same way
- a hook, which the plan said could not be seen by measurement at all, turned out
  to be the most cleanly separated thing in the whole distribution

The measuring was going to be a throwaway script. Keeping it as
`--calibrate` costs about forty lines and changes what those numbers *are*: not
settings somebody once chose, but the current answer to a question that can be
asked again.

## Why the throwaway version is worse than no version

A boundary drifting into the middle of a cluster produces output that is wrong
and looks fine. Nothing downstream reports it. The only symptom is that somebody
eventually notices the pictures are a bit off, and by then the script that would
have shown why is three months gone.

## Where else it applies

Anywhere a number in the source is downstream of data that gets new releases.
Thresholds derived from a corpus. Timeouts derived from a benchmark. Cache sizes
derived from a workload. Every one of them is a claim with an expiry date, and
the difference between a guess and a measurement is invisible unless the
measurement is still runnable.

## The shape of it

    luajit src/021-the-shape-of-a-stroke.lua --calibrate

The file that holds the constants holds the tool that produced them, and the
comment beside each constant says which line of that tool's output it came from.
