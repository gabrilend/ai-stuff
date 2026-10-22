# Architecture

guide-feature lets a person watch what three computers are thinking, as one
page that keeps rewriting itself. Each computer reads the page, adds what it
has to say, keeps what it thinks still matters, and drops the rest. What
nobody carries forward fades out of the viewer's sight.

This document names the parts and says which machine each one runs on. How
data moves between them is in the datapath documents listed at the end.

## The core terms

These words mean one thing each, everywhere in the project.

| Term | What it is |
|---|---|
| **voice** | One of the three fg-sora machines, seen as a speaker. Its name is its hostname: `fg-sora-1`, `fg-sora-2`, `fg-sora-3`. |
| **thought** | One line of text written by a voice. The smallest thing that can fade. |
| **frame** | One voice's complete statement at one moment: every thought it currently stands behind. A new frame replaces that voice's previous frame entirely. The vision's rule is that a frame is "100% valid and real": the next frame must either include each thought again (perhaps reworded) or let it go. |
| **page** | What the viewer sees: the newest frame from each of the three voices, plus the thoughts from older frames that are still fading out, each with a relevance number. The page has a number that goes up by one every time it changes. |
| **relevance** | A number from 0.000 to 1.000 on each thought. 1.000 means the thought is in its voice's newest frame, or something very like it is. It falls each time a new page goes by without the thought being carried forward. At 0.000 the thought leaves the page. |
| **page keeper** | The long-running Lua program on kuvalu. It is the only part that decides anything: it receives frames, measures what was carried forward, computes relevance, builds the page, sends the page back to the voices, and publishes it to viewers. |
| **thinker** | The long-running Lua program on each fg-sora machine. It reads the newest page, gathers random context, asks the local language model for a new frame, and hands the frame to rmail. |
| **viewer** | Any program that shows the page to a person: the Lua window, the terminal view, the HTML page, the Android app, the Apple Watch app. Viewers only read; they never decide relevance. |
| **display box** | The size of the page in characters, width by height. Each voice gets a share of it, and every frame must fit its share. A frame that does not fit is sent back to the language model with an error report, like a compiler error, until it fits. See `docs/display-box.md`. |
| **inference backend** | Where a voice's language model actually runs: on the fg-sora itself, or on a remote machine with the fg-sora acting as a relay. See `docs/datapath-thinker.md`. |
| **page protocol** | The plain-text format and the two ways of getting it (files on kuvalu, HTTP from anywhere) that every viewer reads. "Protocols, not procedures": a viewer can be written in any language by reading `docs/page-protocol.md` alone. |

## The machines

| Machine | Address | rmail port | Runs |
|---|---|---|---|
| kuvalu (the desktop) | 192.168.1.100 | 1223 | rmail mailbox `guide`, the page keeper, the page server for viewers, the Lua window and terminal viewers |
| fg-sora-1 | 192.168.1.11 | 10101 | rmail mailbox, thinker, and either a local language model or a relay to a remote one |
| fg-sora-2 | 192.168.1.12 | 20202 | the same |
| fg-sora-3 | 192.168.1.13 | 30303 | the same |
| a remote model host (optional) | anywhere a voice can reach | none | a language model a voice relays its prompt to, such as a llama.cpp server on kuvalu's GTX 1080 Ti or a hosted model service |
| a phone, a watch, any browser | anywhere that can reach kuvalu | none | a viewer, reading the page server over HTTP |

What is known about the fg-sora hardware is recorded in the minimal-llm
project's cluster topology document
(`/home/ritz/programs/sora/minimal-llm/docs/005-cluster-topology.md`): each is
a six-core, six-thread Intel i5-8500T (a 35-watt part that slows its own clock
under sustained load), with 8 GB of memory and no graphics card, running a
BusyBox userland. Which C library they use (glibc or musl) has not been
checked, and it decides whether programs built on kuvalu run there; see
`docs/open-questions.md`.

Login credentials for the fg-sora machines are never written into this
repository. rmail's shared secrets live in each mailbox's `contacts` file,
outside the repository.

## Why rmail carries the messages, and why the page keeper does the thinking

rmail is the owner's file-based messenger (`/home/ritz/programs/r-mail/`).
A message is a plain file. Writing a file into `outbox/` sends it, and the
author editing that file later sends the edit to every recipient: a "living
message". rmail encrypts everything with AES-256-GCM and retries recipients
that are offline.

rmail sends an edit only when the author makes it (see
`docs/rmail-constraints.md`). So "one page everyone edits" is built from
pieces that each have one author:

- each voice authors exactly one living message, its **frame**, addressed to
  kuvalu, and edits it in place every time it thinks again;
- kuvalu authors exactly one living message, the **page**, addressed to all
  three voices, and edits it in place every time the page changes.

Every edit therefore has one author, which is the only kind of edit rmail
carries. rmail does the carrying and the page keeper does the deciding. That
was the owner's direction: "Let rmail handle the communication, and the logic
processing will happen with our running lua program."

## The rhythm

rmail sends to each contact at most once every 30 seconds (plus or minus 30
seconds of random spread), and a contact that fails backs off by 6 minutes per
failure. So a frame takes between a moment and about a minute to reach
kuvalu, and the page takes as long again to get back. The page is a slow
conversation, not a live feed. The thinkers write "as soon as they are able",
which on this hardware is bounded by how fast the language model produces
text, not by rmail.

## Separation of concerns

- **Generating data**: thinkers (frames), page keeper (relevance, page).
- **Viewing data**: viewers, which read only the page protocol.

A viewer that shows a wrong opacity is a viewer bug. A wrong relevance number
in the page protocol is a page keeper bug. The page protocol sits between
them so each side can be tested alone.

## Every program starts with input/ and ends with output/goodbye

The page keeper, the thinker and every desktop viewer read their settings
from the project's `input/` folder first, and write a goodbye receipt to
`output/goodbye` as their last act: when they stopped, the seed if any, and
the counts of their own units of work (frames received, pages published,
frames written, pages drawn). A missing or stale goodbye means the program
did not end cleanly.

## Related documents

- `docs/rmail-constraints.md` — what rmail does and does not provide.
- `docs/frame-format.md` — the frame, as written by a thinker.
- `docs/display-box.md` — the page's size in characters, and the fit check.
- `docs/page-protocol.md` — the page, as read by viewers.
- `docs/datapath-frame-to-page.md` — a frame's journey to the page.
- `docs/datapath-relevance.md` — how a thought fades.
- `docs/datapath-thinker.md` — how a voice writes its next frame.
- `docs/datapath-viewers.md` — how the page reaches eyes.
- `docs/roadmap.md` — the phases.
- `docs/open-questions.md` — what is not yet decided.
