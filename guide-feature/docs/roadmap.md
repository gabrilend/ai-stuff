# Roadmap

The phases group the work by what it is, not by when it is done. Lower
phases are what higher ones stand on. It is normal for the last issue
finished to belong to phase 1. Every phase ends with a demo in
`issues/completed/demos/phase-N-demo`, run from `run-phase-demo` in the
project root.

## Phase 1 — The canvas and the blit

The shared grid of characters and the rule for writing onto it, with no
network: read and write the canvas text, find its words, work out what a
voice changed against its base, and blit those changes, blanking any word
that loses part of itself. Fed by dropping canvases into a folder.

Ends with: a scripted series of edits by three voices, some made from stale
bases and some overlapping, played onto one canvas, with the count of words
written, blanked and in conflict after each version.

## Phase 2 — The canvas for viewers

Marks for skimming (changed words and their sentences, aging), the
viewer-side reader, the canvas files in RAM with history, the HTTP canvas
server, and how the canvas size changes.

Ends with: two readers, one on files and one on HTTP, receiving identical
versions, and a text rendering of the marks aging over a replay.

## Phase 3 — The relay through rmail

kuvalu's mailbox on port 1223, the arrival hook, the canvas mailed to the
voices as a living message, and the turn hook on each voice that keeps only
the newest canvas and runs one turn at a time. Rehearsed on kuvalu with three
extra mailboxes posing as the mini-computers and stand-in turns.

Ends with: the round trip through real rmail, measured.

## Phase 4 — The turn

The endpoints file and runtime selection, the llama.cpp client, the turn's
prompt, and the ask-until-it-fits loop with compiler-style reports. Running
on kuvalu's llama.cpp server.

Ends with: three real turns per version on kuvalu, showing fit retries,
change counts against the budget, and the canvas changing.

## Phase 5 — Looking into the project

The project clone (in RAM if it fits), the embedding index contract and the
guide for building an index for a project, and the look tool with its
focused-to-broad setting.

Ends with: the same question asked at several focus levels, showing which
pieces came back and how similar each was. Then a turn that used the look
tool.

## Phase 6 — Distill mode

kuvalu's second merge mode: a language model combines the voices' newest
canvases into one edit before it is blitted.

Ends with: the same scripted rounds in both modes, side by side, with words
changed per version and conflicts per mode.

## Phase 7 — Bringing up the mini-computers

Survey (C library, curl, free memory), rmail on each, reaching the endpoints
from each, deploying the turn hook, the network rules checked from each
machine, and one health check across all four.

Ends with: the whole system running on four machines.

## Phase 8 — Viewers for the desk and the browser

Terminal view, Lua window, HTML page.

Ends with: all three showing the same versions side by side, with
screenshots.

## Phase 9 — Viewers for the pocket and the wrist

Android app, Apple Watch app.

Ends with: the canvas on a phone and a watch, captured beside the Lua
window.
