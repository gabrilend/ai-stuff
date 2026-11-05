# 002-goodbye — info

How every guide-feature program keeps its run log and leaves its goodbye
receipt. Issue 101 is the blueprint.

## The receipt

`output/goodbye-<program>`, written as the last act of a clean exit:

    program: blitter
    ended: 2026-11-05T10:03:00Z
    seed: 1234
    arrivals-taken: 2
    words-blanked: 0
    words-written: 7

The head lines (`program`, `ended` in UTC, `seed` only when the program has
one) come first, then the counters sorted by name, one `name: value` line
each, so two receipts compare with `diff`. A counter is a whole number of
zero or more, and only grows.

## Why a missing receipt is the crash report

Starting a run moves the last receipt to `output/goodbye-<program>.previous`.
So while a program runs, and after it dies, it has no receipt; the last good
one is still there to compare against. The receipt is written to a `.partial`
file beside it and renamed into place, so a crash while writing leaves no
receipt rather than a cut one.

## Why one receipt per program

The blitter, the canvas server and the desktop viewers all run on kuvalu at
the same time. A single `output/goodbye` would hold only whichever ended
last, and a crashed program would hide behind another's receipt.

## The log

`tmp/shared-memory/<program>.log`, appended to run after run, each line
starting with the UTC time. Every run starts with a `started` line and a clean
one ends with `ended`, so a start with no end after it is a run that died.

## What it exports

| Name | Type | Meaning |
|---|---|---|
| `start(program, opts)` | function | a run: makes the RAM tiers, moves the last receipt aside, opens the log. `opts.root`, `opts.seed` (whole), `opts.clock` (tests) |
| `run:log(text)` | method | one timed line in the log |
| `run:count(name, by)` | method | adds `by` (default 1) to a counter; returns its new value |
| `run:finish()` | method | writes the receipt and closes the log; returns the receipt's path. Once only |
| `format(receipt)`, `parse(text)`, `read(path)` | functions | a receipt to text and back; `read` is nil when there is none |
| `path(root, program)` | function | where a program's receipt lives |
| `HEAD` | list | the head lines' names, which no counter may take |

Tests: `004-test-goodbye.lua`.
