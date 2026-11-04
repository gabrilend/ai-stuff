# 007 — Roadmap

Five phases. They are clusters of functionality, not a schedule: each can be
built and tested with only the phases below it, and the issue numbers inside a
phase run from foundation to capstone. Reading a phase's issues in order should
explain how that part of the machine is built.

## Phase 1 — The Reading

*Text and geometry into a quantity and a weighted paragraph. No browser, no network.*

Everything here runs under LuaJIT from the command line, fed hover records
saved as JSON files. It ends with a machine that, given a paragraph and where
the pointer was, says which quantity is meant (or that a bare number is a
count), what it is in SI, and how much each other word in the paragraph
matters.

| | |
|---|---|
| `101` | The units a page speaks — the unit lexicon and conversion into SI |
| `102` | Finding a quantity in a sentence — numbers, bare counts, ranges, ambiguous separators, units |
| `103` | The shape of a hover — the hover record, and a test page that captures real ones |
| `104` | How near each word is — the proximity spectrum |
| `105` | How much the paragraph may say — the context policy and the settings file it lives in |
| `106` | Phase 1 demo — captured hovers painted as heat over their paragraphs |

**Demo:** an HTML page, opened in Firefox, showing several captured paragraphs
with each word tinted by its weight under both policies side by side, the found
quantity outlined, and its SI value beneath — plus counts of quantities found
versus missed across the fixture set.

## Phase 2 — The Bridges

*The host's two connections: to Firefox, and to ComfyUI.*

| | |
|---|---|
| `201` | A messenger in Lua — the native messaging host, its framing, its dispatch table, its log |
| `202` | The extension's body — manifest, content script that sends hover records, background script |
| `203` | The settings page — reached from the Extensions menu, read and written through the host |
| `204` | Talking to ComfyUI — submit, watch, fetch pictures and text, cancel |
| `205` | Phase 2 demo — a live page where hovering prints the host's answer, and ComfyUI answers too |

The ComfyUI client sits here, not with the pictures, because the language model
in phase 3 runs on ComfyUI too.

**Demo:** the extension installed temporarily; hovering a quantity makes the
host answer with the quantity record in a plain box; round-trip times in
milliseconds; the ComfyUI server's state and one test picture.

## Phase 3 — The Reasoning

*A quantity into an analogy. Arithmetic in Lua, judgement in the language model.*

| | |
|---|---|
| `301` | Things whose size is known — the reference catalogue |
| `302` | Kinds of subject — families of reference objects, and the memory of which were shown |
| `303` | Asking the language model — in ComfyUI or on the reader's machine; the analogy record |
| `304` | "I didn't understand" — the re-roll |
| `305` | Phase 3 demo — every fixture quantity, every kind, as sentences |

**Demo:** a table of fixture quantities against kinds, each cell the analogy
sentence, with how often the model picked each candidate and how many re-rolls
it took to exhaust each hover.

## Phase 4 — The Pictures

*An analogy into an image holding exactly the right number of things.*

| | |
|---|---|
| `401` | Every one in its place — the cell layout: grid or hex, fractions off the edge |
| `402` | A workflow for one comparison — one area prompt per cell, built with the kanji project's graph writer |
| `403` | Pictures kept — the two caches, in RAM or on disk |
| `404` | Phase 4 demo — a gallery of fixture quantities and their pictures, with a count check |

## Phase 5 — The Showing

*The panel beside the pointer, and the whole thing working.*

| | |
|---|---|
| `501` | The panel by the pointer — placement, the sentence first, the picture when it comes |
| `502` | Asking for another — middle-click |
| `503` | Keeping a picture — recent pictures in the Extensions menu, saved through downloads |
| `504` | Hover to picture — the capstone: everything above, in one motion, and the phase 5 demo |
