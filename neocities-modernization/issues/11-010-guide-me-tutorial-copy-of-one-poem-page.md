# 11-010: Guide-Me — a Marker-Annotated Tutorial Copy of One Poem Page

## Status
- **Phase**: 11 (Advanced Exploration)
- **Priority**: Medium
- **Type**: Feature
- **Status**: Open -- design; four open questions at the bottom must be answered
  before building
- **Created**: 2026-10-04, from a design conversation kept until now in a
  scratch file at the project root (`TODO-guide-me-tutorial-page.md`, removed
  when this issue was written; it remains in git history)
- **Related**: 11-006 (an editable splash/gateway page in front of the word
  cloud -- the likely home for the three-button picker; see open question 4),
  16-005 (the HTTPS trust-warning page, which already uses the words
  "trust me" for something else)

## Current Behavior

There is no tutorial. A first-time reader lands on a similar/different page
with no explanation of what "similar", "different" and "chronological" do, or
that moving back and forth between them is the point.

Facts the design depends on:
- **The home page.** Every generated page links to `wordcloud.html` as "Menu";
  it is the de-facto hub (11-006). When this design was first discussed the
  home page was taken to be `chronological.html`; that page no longer exists at
  the top of `output/` (the chronological pages live in `output/chronological/`).
- **Per-poem pages.** Each poem has a similar page and a different page,
  `output/similar/NNNN-01.html` and `output/different/NNNN-01.html`, written by
  `src/flat-html-generator.lua`.
- **"trust-me" is taken.** 16-005 uses it on the HTTPS self-signed-certificate
  intermediate page (a per-link click-through, not a mode picker).
- **Flags.** `run.sh` takes every per-build value as a required flag (10-065);
  a new flag joins the requirement table there and is recorded in
  `output/generation-metadata.json` like the others.

## Intended Behavior

### What the owner asked for

A command-line flag that stores a number: the "index", or initial view page,
for a reader approaching the similar/different pages from the home page. The
home page offers three choices: **trust-me**, **guide-me** and **think-me**.
Tapping guide-me leads to a tutorial version of a similar/different page. The
page's structure stays the same, but bright yellow arrows and text, each with a
thin black-and-white border, point at things and say how to navigate. Example
hints: "similar takes you to poems that are similar", "different takes you to
poems that are different", "try scrolling a bit and tapping chronological, then
similar/different, then chronological, then back and forth again."

The owner's clarification: the yellow markings look as if someone drew on the
page with a marker, **in the margins only**, pointing inward at the parts of
the page. The tutorial is **just one page**: a second copy of one chosen
record, with the inner record untouched. It is reached only from the home page
by tapping guide-me. Every regular per-poem page stays clean.

### The design as it stands

- The flag's integer picks **which record is duplicated** as the tutorial copy
  (the working reading; open question 1).
- The home page gains a three-button picker. All three buttons land on that
  same record; guide-me's destination is the annotated copy.
- The copy is the record's real page, byte-for-byte in its centre, with the
  annotations added only in the margins: bright yellow, thin black-and-white
  border, felt-tip-marker look, arrows pointing inward. Suggested copy:
  "these are poems near to this one", "scroll a bit & watch the list shift",
  "tap me, scroll a bit, tap back here, then to different, then back & forth!"
- Because the inner record is untouched, a reader who already knows the layout
  sees exactly the shape they know, with notes crowding the edges. The
  tutorial teaches the real surface, not a practice copy of it.

```
                          ┌────────────────────────────┐
                          │         home page          │
                          │                            │
                          │   ┌────┐ ┌────┐ ┌────┐    │
                          │   │trust│ │guide│ │think│   │
                          │   │ me │ │ me │ │ me │    │
                          │   └─┬──┘ └──┬─┘ └─┬──┘    │
                          └─────┼───────┼─────┼────────┘
                                │       │     │
                       ╭────────╯       │     ╰─────────╮
                      ╱                 │                ╲
                     ╱           tap "guide-me"           ╲
                    ╱                   │                  ╲
                   ╱                  ╱╱╱  ◢◤               ╲
                  ╱                ╱╱╱   ◢◤  3D curve        ╲
                 ▼              ╱╱╱    ◢◤                     ▼
       ┌─────────┐            ▼▼▼     ▼                 ┌──────────┐
       │ similar/│                                      │ similar/ │
       │different│  ┌──────────────────────────────────┐│different │
       │ /N.html │  │       similar/N-guide.html       ││ /N.html  │
       │         │  │   (a SECOND copy of record N)    ││          │
       │  plain  │  │                                  ││  plain   │
       │ record  │  │   ╲╮"these are                   ││ record   │
       │   N     │  │    ╲╲  poems near             ▒ ││    N     │
       └─────────┘  │     ╲╲  to this one"          ▒ │└──────────┘
                    │      ╲▶                       ▒ │
                    │   ┌──────────────────────┐    ▒ │
                    │   │   poem text          │    ▒ │
                    │   │   (UNTOUCHED, same   │    ▒ │
                    │   │    as N.html)        │    ▒ │
                    │   │   similar │ different│    ▒ │
                    │   │   ───────────────────│    ▒ │
                    │   │   · poem A           │    ▒ │
                    │   │   · poem B           │ ◀──╮▒│ ╲ "scroll a bit
                    │   │   · poem C           │    │▒│  ╲  & watch the
                    │   │   [chronological]    │    │▒│   ▶ list shift"
                    │   └──┬───────────────────┘    │▒│
                    │      ╲ "tap me, scroll        │▒│
                    │       ╲  a bit, tap           │▒│
                    │        ▶ back here, then to   │▒│
                    │          different, then      │▒│
                    │          back & forth!"       │▒│
                    │   (yellow felt-tip arrows,    │▒│
                    │    thin black-and-white       │▒│
                    │    border, margins only)      │▒│
                    └───────────────────────────────┴─┘
```

## Suggested Implementation Steps

1. Answer the open questions below; rewrite this section if the answers change
   the design.
2. **The flag.** Add it to `run.sh`'s requirement table (10-065) for the stage
   that writes the per-poem pages, pass it to the HTML generator, and record it
   in `output/generation-metadata.json`.
3. **The tutorial copy.** In `src/flat-html-generator.lua`, after the chosen
   record's similar and different pages are written, write a second copy of
   each with the margin annotations added around the unchanged page body. The
   annotations are their own small rendering step, kept separate from the page
   body, so the record inside stays byte-identical to the plain page (a test
   can check exactly that).
4. **The picker.** Add the three buttons to the home page (open question 4
   decides which page that is), linking to the chosen record's pages.
5. **Test.** The copy's centre equals the plain page; the annotations appear
   only in the margins; the picker's links resolve; the build fails if the
   chosen record does not exist.

## Open Questions

Carried over unanswered from the design conversation, plus one found when this
issue was written.

1. **Is the integer the poem id of the record that becomes the tutorial?**
   That is the working reading: for example, `--guide-record 4625` picks poem
   4625 as the duplicated record. The alternative is that the integer is the
   mode (1 = trust, 2 = guide, 3 = think) and the tutorial record is set
   somewhere else. The first reading matches the phrase "the number that will
   be the index or initial viewpage" more closely.

2. **Naming and URL for the copy.** Does `similar/N-guide.html` and
   `different/N-guide.html` feel right, or was a different layout intended (a
   separate `guide/` directory, a query string, something else)? A distinct
   filename is the cheapest and survives bookmarking, but adds two files per
   build rather than one.

3. **What does think-me do?** It has not been described. Leave it as a button
   that links to the plain record for now, or hold the work until think-me is
   described?

4. **Which page is "home"?** The conversation assumed `chronological.html`.
   Today the word cloud (`wordcloud.html`) is the menu every page links to, and
   11-006 plans an editable splash page in front of it. Does the three-button
   picker go on that splash page, on the word cloud, or somewhere else?
