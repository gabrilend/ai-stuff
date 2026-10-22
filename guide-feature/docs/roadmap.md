# Roadmap

The phases group the work by what it is, not by when it is done. Lower
phases are the pieces higher phases stand on. It is normal for the last issue
finished to belong to phase 1. Every phase ends with a demo in
`issues/completed/demos/`, run by `run-phase-demo` in the project root.

## Phase 1 — The fit and the fade

The page keeper's thinking, with no network at all: read a frame, check that
it fits the display box, recognise thoughts carried forward by the angle
between their word counts, fade the rest, and lay out the page. It is fed by
dropping frame files into a folder by hand or from a script.

Builds: the frame reader, the word-space similarity measure, the fit checker
(shared later with the thinkers), the relevance rules, the page layout, and
the page keeper's main loop over the arrivals folder.

Ends with: a demo that replays a scripted conversation of three voices into
the arrivals folder and shows, page by page, which thoughts survived, which
faded, and how long each lasted. It also shows the fit checker's error report
for a frame that is too wide.

## Phase 2 — The page protocol

The page leaves the page keeper: written as files on kuvalu and served over
HTTP, in the one plain-text format every viewer reads. Includes the box rules
that let viewers say their size.

Builds: the page writer, the Lua page reader, the RAM page folder with
history, the HTTP page server with waiting requests, the box rules.

Ends with: a demo that runs the phase-1 replay while two readers watch, one
on the files and one over HTTP, and shows that both received every page,
byte for byte the same. It then changes the box mid-run and shows the page
reshaping.

## Phase 3 — The relay through rmail

Frames and pages travel as living rmail messages: kuvalu's mailbox on port
1223, the arrival hooks, and the page sent back to the voices. Rehearsed
entirely on kuvalu with three extra mailboxes posing as the fg-sora
machines.

Builds: the kuvalu mailbox setup, the arrival hook, the page as a living
message, the loopback rehearsal with scripted stand-in voices.

Ends with: a demo of three stand-in voices on kuvalu sending frames through
real rmail. It measures how long each frame took to reach the page and how
long the page took to come back.

## Phase 4 — The thinkers

The program that is a voice: reads the page, gathers random context, asks a
language model, sends the misfits back like compiler errors, writes the
frame. The model can be local or remote, with the voice acting as a relay.
Built and tested on kuvalu before any fg-sora is touched.

Builds: the context gatherer, the prompt builder, the table of inference
backends (local llama.cpp, remote llama.cpp, remote hosted service), the
retry-on-misfit loop, the thinker's main loop.

Ends with: a demo where three thinkers on kuvalu, using different backends,
talk on one page. It shows fit retries per backend, give-ups, and how many
frames each thought survived.

## Phase 5 — Bringing up the fg-sora machines

The three mini-computers become the voices: check their C library and tools,
install rmail, install llama.cpp built for their processor (or set them up
as relays), deploy the thinker, and run the whole system for real.

Builds: the survey script, the rmail install, the model install, the
thinker deployment, and a health check that reports on all three.

Ends with: the full system running across four machines, with a demo that
shows each voice's turn time, its rmail delay, and its backend.

## Phase 6 — Viewers for the desk and the browser

Builds: the terminal view, the Lua window, the HTML page.

Ends with: a demo that opens all three on the same live (or replayed) page,
screenshots each, and shows pages drawn and fade timings side by side.

## Phase 7 — Viewers for the pocket and the wrist

Builds: the Android app and the Apple Watch app, both reading the page
server over HTTP and telling it their size.

Ends with: a demo that shows the page at watch size and phone size, captured
from each device or its emulator.
