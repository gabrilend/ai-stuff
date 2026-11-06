# Settings files and the goodbye receipt

Every distant-computer program starts by reading its own settings file from
`input/` and ends by writing `output/goodbye`.

## input/<program>

One file per program, named after it (`input/courier`, `input/watchdog`,
`input/gate`). Each line is one of:

    # a comment, to the end of the line
    name = 12              a whole number
    name = 0.5             a decimal
    name = "some text"     text, in double quotes
    name = word            text that is a single bare word (letters, digits, - _ . / :)
    name = a, b, c         a list of bare words

Blank lines are ignored. Each program declares every name it reads, along
with its type and whether it is required. The reader **refuses** (raises an
error naming the file and line) on:

- a missing file;
- a name the program did not declare (usually a typo);
- a required name that is missing;
- a value of the wrong type;
- a name given twice.

No program hides a default in its code. Every value it uses is visible in
its input file, so the input file is a complete description of how the
program will run. The house reason: a fallback is a warning, and a warning
is an error.

Shared files that several programs read (`input/link`, `input/placement`,
`input/crystallized`, `input/budget`) use the same format, except
`input/placement` and `input/crystallized`, whose formats are given in
`docs/datapath-placement.md` and `docs/datapath-link.md`.

## output/goodbye

The **receipt**. Written last, on every clean exit:

    program: courier
    ended: 2026-10-28T23:14:05Z
    seed: none
    rounds: 41
    requests-carried-in: 3
    answers-carried-out: 2

The first three lines are always `program`, `ended` (UTC) and `seed` (or
`none`). After them come the program's own counters, each a whole number,
sorted by name, so two receipts can be compared with `diff`. A crash writes
nothing, so a missing or stale goodbye is the crash report. A longer run log
goes beside it at `tmp/shared-memory/<program>.log`.

Several programs share one `output/` folder, so each also writes
`output/goodbye.<program>`. `output/goodbye` is always the most recent one to
finish.

Both are written to a temporary name and then renamed into place, so a
reader never sees half a receipt.
