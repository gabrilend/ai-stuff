# TODO — guide-me tutorial page + CLI flag for landing record

This is an in-progress design conversation. No code has been written yet.
The next step is to answer the two open clarifying questions, then draft
a proper issue file in `issues/` describing the build, and only then
touch any source. This file is a working scratchpad, not a record of
completed work.

---

## Diagrams from the conversation

### Diagram 1 — first sketch (three home-page modes, before the marker-on-margin clarification)

This is the first picture I drew, showing the three home-page buttons
branching out to three different downstream surfaces. At this point in
the conversation I was still under the impression that the tutorial
might be applied to *every* similar-different page rather than a single
duplicate, so this diagram shows the tutorial as a whole separate
column of similar-different pages.

```
                ┌──────────────────────────────────────┐
                │       chronological.html (home)      │
                │                                      │
                │     ╔═════════╗ ╔═════════╗ ╔══════╗ │
                │     ║ trust-me║ ║ guide-me║ ║think-║ │
                │     ║   (1)   ║ ║   (2)   ║ ║ me(3)║ │
                │     ╚════╤════╝ ╚════╤════╝ ╚══╤═══╝ │
                └──────────┼───────────┼─────────┼─────┘
                           │           │         │
              ╭────────────╯           │         ╰────────────╮
             ╱              cli flag stores N ∈ {1, 2, 3}      ╲
            ╱                 → bakes that button as the         ╲
           ╱                    initial highlighted view          ╲
          ╱                                                        ╲
         ╱        ╭──────╮          ╭──────╮         ╭──────╮       ╲
        ╱        ╱╱      ╲╲        ╱╱      ╲╲       ╱╱      ╲╲       ╲
       ╱       ╱╱╱        ╲╲      ╱╱        ╲╲     ╱╱        ╲╲       ╲
      ╱      ╱╱╱            ╲╲  ╱╱            ╲╲  ╱╱            ╲╲     ╲
     ╱     ╱╱╱      3D       ╲╲╱╱     curved   ╲╲╱╱    arrows    ╲╲    ╲
    ▼   ╱╱╱╱                 ▼╳▼               ▼╳▼               ╲╲╲▼
        ◤◤                     ╳                 ╳                 ◥◥
   ┌──────────┐         ┌──────────────┐    ┌──────────────┐
   │ plain    │         │ TUTORIAL     │    │ (think-me —  │
   │ similar/ │         │ OVERLAY on   │    │  intent TBD; │
   │ different│         │ similar/diff │    │  contemplate?│
   │ pages    │         │  layout      │    │  pause?      │
   └──────────┘         │              │    │  longread?)  │
                        │ ⬇ bright     │    └──────────────┘
                        │   YELLOW     │
                        │   arrows w/  │
                        │ ▒ thin black │
                        │ ░ + white    │
                        │   border     │
                        │              │
                        │ → "similar = │
                        │   closer     │
                        │   poems"     │
                        │ → "different │
                        │   = far      │
                        │   poems"     │
                        │ → "scroll a  │
                        │   bit, then  │
                        │   tap chrono │
                        │   ↔ sim/diff │
                        │   back &     │
                        │   forth!"    │
                        └──────────────┘
```

### Diagram 2 — revised after the marker-on-margin clarification

After the clarification that the tutorial is a **single duplicate** of
one chosen record, with marker-style annotations in the margins
pointing inward at the otherwise-untouched record, the picture
collapses to two siblings (a clean per-poem page on the left and right,
and one annotated duplicate in the middle that only the guide-me
button can reach).

```
                          ┌────────────────────────────┐
                          │    chronological.html      │
                          │       (home page)          │
                          │                            │
                          │   ┌────┐ ┌────┐ ┌────┐    │
                          │   │trust│ │guide│ │think│   │
                          │   │ me │ │ me │ │ me │    │
                          │   └─┬──┘ └──┬─┘ └─┬──┘    │
                          └─────┼───────┼─────┼────────┘
                                │       │     │
                                │       │     │
                       ╭────────╯       │     ╰─────────╮
                      ╱                 │                ╲
                     ╱                  │                 ╲
                    ╱            tap "guide-me"            ╲
                   ╱                    │                   ╲
                  ╱                    ╱╱                    ╲
                 ╱                  ╱╱╱  ◢◤                   ╲
                ╱                ╱╱╱   ◢◤  3D curve            ╲
               ╱              ╱╱╱    ◢◤                         ╲
              ╱            ╱╱╱     ◢◤                            ╲
             ▼          ╱╱╱      ◢◤                               ▼
       ┌─────────┐    ▼▼▼      ▼                          ┌──────────┐
       │ similar/│                                        │ similar/ │
       │different│  ┌──────────────────────────────────┐  │different │
       │ /N.html │  │       similar/N-guide.html       │  │ /N.html  │
       │         │  │   (a SECOND copy of record N)    │  │          │
       │  plain  │  │                                  │  │  plain   │
       │ record  │  │                                  │  │ record   │
       │   N     │  │   ╲╮"these are                   │  │    N     │
       └─────────┘  │    ╲╲  poems near             ▒ │  └──────────┘
                    │     ╲╲  to this one"          ▒ │
                    │      ╲▶                       ▒ │
                    │   ┌──────────────────────┐    ▒ │
                    │   │                      │    ▒ │
                    │   │   poem text          │    ▒ │
                    │   │   (UNTOUCHED, same   │    ▒ │
                    │   │    as N.html)        │    ▒ │
                    │   │                      │    ▒ │
                    │   │   similar │ different│    ▒ │
                    │   │   ───────────────────│    ▒ │
                    │   │   · poem A           │    ▒ │
                    │   │   · poem B           │ ◀──╮▒│ ╲ "scroll a bit
                    │   │   · poem C           │    │▒│  ╲  & watch the
                    │   │                      │    │▒│   ▶ list shift"
                    │   │   [chronological]    │    │▒│
                    │   └──┬───────────────────┘    │▒│
                    │      │                        │▒│
                    │      ╲                        │▒│
                    │       ╲ "tap me, scroll       │▒│
                    │        ╲  a bit, tap          │▒│
                    │         ▶ back here,          │▒│
                    │            then to            │▒│
                    │            different,         │▒│
                    │            then back &        │▒│
                    │            forth!"            │▒│
                    │                               │▒│
                    │   (yellow felt-tip arrows, thin│▒│
                    │    black-and-white border,    │▒│
                    │    only in the page margins)  │▒│
                    └───────────────────────────────┴─┘
```

---

## Conversation summary

**User's original request.** Add a command-line flag that stores a
number — the "index" or initial viewpage — for the reader approaching
the similar-different pages from the home main page. The home page is
to offer three options: **trust-me**, **guide-me**, and **think-me**.
If the reader taps guide-me, they reach a similar-different tutorial
version of a page. The main structure of the page stays the same, but
bright yellow arrows and text, each with a thin black-and-white border
highlight, point at things and describe how to navigate. Example
navigation hints: "similar takes you to poems that are similar,
different takes you to poems that are different, try scrolling a bit
and tapping chronological, then similar/different, then chronological,
then back and forth again." The user asked for a little diagram drawn
with curved 3D arrow graphics.

**What I found in the codebase.** The phrase "trust-me" already exists
in the project, but for a different purpose — it sits on the HTTPS
self-signed certificate trust-warning intermediate page that bridges
the chronological view and a phone-served photo. That is a per-link
click-through, not a mode selector. The chronological home page does
not currently carry the trust / guide / think three-way picker, so
that picker is part of the new work too. The existing CLI argument
parser already handles flag names like `--threads`, `--pages`,
`--poems-per-page`, and `--chrono-per-page`, so a new flag would slot
in naturally beside those.

**User's clarification.** The yellow markings should look as if someone
drew on the page with marker, off in the margins, pointing inward at
the parts of the inner text. The tutorial page is **just one page** —
the inner record is untouched, and the marker-style annotations live
only in the margins. To reach it again, the reader must approach from
the main home page and tap guide-me. Doing so brings them to a
**second copy** of the chosen similar-different record — the one we
specified as the tutorial stage, the one with the pointers. The
regular per-poem similar/different page stays clean.

**Current design reading.** The integer flag picks **which similar-
different record gets duplicated as the tutorial copy**. The three
home-page buttons (trust / guide / think) all land on that same
record; guide-me's variant is the duplicate that carries the marker-
style margin annotations. trust-me and think-me's behavior on the
landing record is not yet specified — think-me especially is
undefined.

---

## Open questions to the user (must answer before issue file is drafted)

1. **Is the integer the poem id of the record that becomes the
   tutorial?** That is the reading I am running with — for example,
   `--guide-record 4625` picks poem 4625 as the duplicated record. The
   alternative is that the integer is the mode (1 = trust, 2 = guide,
   3 = think) and the tutorial-record is configured elsewhere. The
   first reading matches the phrase "the number that will be the
   *index* or initial viewpage" more closely.

2. **Naming and URL for the duplicate.** Does a filename shape like
   `similar/N-guide.html` and `different/N-guide.html` feel right, or
   was a different layout intended (a separate `guide/` directory? a
   query-string? something else)? A distinct filename is the cheapest
   path and survives bookmarking, but adds two extra files per
   generation run rather than one.

3. **think-me behavior.** The conversation has not specified what
   think-me does. Leave it as a stub button that links to the plain
   similar-different record for now, or hold the work until think-me
   is described?

---

## Tasks queued (in order)

1. Receive answers to the three open questions above.
2. Search the issues directory for any existing in-flight issue file
   that already covers a home-page mode selector or a tutorial overlay,
   to avoid creating a duplicate. If one exists, re-open and extend it
   rather than starting a fresh one.
3. Draft a proper issue file in `issues/` with the standard sections —
   current behavior, intended behavior, suggested implementation
   steps — describing:
   - the new CLI flag (name, integer payload, where it is read in the
     argument parser, where it is consumed in the HTML generation
     pipeline);
   - the home-page three-way picker (trust / guide / think), including
     the layout addition to the chronological index;
   - the duplicate tutorial page generation step (which record is
     duplicated, the URL/filename of the duplicate, and where the
     generator hooks in);
   - the marker-style margin annotation design — bright yellow with
     thin black-and-white border, sitting in the page margins only,
     pointing inward at the existing layout, with the suggested copy
     ("similar = closer poems", "different = far poems", "scroll a
     bit, tap chronological, then similar / different, then back and
     forth").
4. Confirm the issue file with the user, then implement the flag, the
   home-page picker, and the duplicate-page generation in that order.
5. Update the relevant phase progress file once the work is in.

---

## Previous assistant message (verbatim)

Got it — that reshapes the design significantly. Let me play it back
and draw it before drafting the issue file.

`★ Insight ─────────────────────────────────────`
- The tutorial isn't an *overlay applied to every similar-different page* — it's a **single duplicate** of one chosen record, living at its own URL, only reachable from the home page's guide-me button. The regular per-poem page stays clean.
- The marker-style annotations sit in the **margins**, pointing inward at the existing layout. The inner record is untouched — so the reader who's already familiar with the layout sees the exact same shape they've seen before, just with felt-tip annotations crowding the edges. That preserves the "it's the same thing, you've been here" feeling that makes the tutorial *teach the real surface* rather than a fake practice surface.
- The integer flag is then naturally the **index of which similar-different record gets duplicated as the tutorial** — the "first" page the guide-me path delivers you to. The same record is also the landing page for trust-me and think-me, just without the marker annotations (or with their own variation).
`─────────────────────────────────────────────────`

Updated picture of the flow:

```
                          ┌────────────────────────────┐
                          │    chronological.html      │
                          │       (home page)          │
                          │                            │
                          │   ┌────┐ ┌────┐ ┌────┐    │
                          │   │trust│ │guide│ │think│   │
                          │   │ me │ │ me │ │ me │    │
                          │   └─┬──┘ └──┬─┘ └─┬──┘    │
                          └─────┼───────┼─────┼────────┘
                                │       │     │
                                │       │     │
                       ╭────────╯       │     ╰─────────╮
                      ╱                 │                ╲
                     ╱                  │                 ╲
                    ╱            tap "guide-me"            ╲
                   ╱                    │                   ╲
                  ╱                    ╱╱                    ╲
                 ╱                  ╱╱╱  ◢◤                   ╲
                ╱                ╱╱╱   ◢◤  3D curve            ╲
               ╱              ╱╱╱    ◢◤                         ╲
              ╱            ╱╱╱     ◢◤                            ╲
             ▼          ╱╱╱      ◢◤                               ▼
       ┌─────────┐    ▼▼▼      ▼                          ┌──────────┐
       │ similar/│                                        │ similar/ │
       │different│  ┌──────────────────────────────────┐  │different │
       │ /N.html │  │       similar/N-guide.html       │  │ /N.html  │
       │         │  │   (a SECOND copy of record N)    │  │          │
       │  plain  │  │                                  │  │  plain   │
       │ record  │  │                                  │  │ record   │
       │   N     │  │   ╲╮"these are                   │  │    N     │
       └─────────┘  │    ╲╲  poems near             ▒ │  └──────────┘
                    │     ╲╲  to this one"          ▒ │
                    │      ╲▶                       ▒ │
                    │   ┌──────────────────────┐    ▒ │
                    │   │                      │    ▒ │
                    │   │   poem text          │    ▒ │
                    │   │   (UNTOUCHED, same   │    ▒ │
                    │   │    as N.html)        │    ▒ │
                    │   │                      │    ▒ │
                    │   │   similar │ different│    ▒ │
                    │   │   ───────────────────│    ▒ │
                    │   │   · poem A           │    ▒ │
                    │   │   · poem B           │ ◀──╮▒│ ╲ "scroll a bit
                    │   │   · poem C           │    │▒│  ╲  & watch the
                    │   │                      │    │▒│   ▶ list shift"
                    │   │   [chronological]    │    │▒│
                    │   └──┬───────────────────┘    │▒│
                    │      │                        │▒│
                    │      ╲                        │▒│
                    │       ╲ "tap me, scroll       │▒│
                    │        ╲  a bit, tap          │▒│
                    │         ▶ back here,          │▒│
                    │            then to            │▒│
                    │            different,         │▒│
                    │            then back &        │▒│
                    │            forth!"            │▒│
                    │                               │▒│
                    │   (yellow felt-tip arrows, thin│▒│
                    │    black-and-white border,    │▒│
                    │    only in the page margins)  │▒│
                    └───────────────────────────────┴─┘
```

Two clarifications I still need before I write up the issue file:

1. **Is the integer the *poem id* of the record that becomes the tutorial?** That's the reading I'm running with — e.g. `--guide-record 4625` picks poem 4625 as the duplicated record. The alternative is that the integer is the *mode* (1=trust, 2=guide, 3=think) and the tutorial-record is configured elsewhere. The first reading matches your phrase "the number that will be the *index* or initial viewpage" better — I want to make sure.

2. **Naming and URL** — does `similar/N-guide.html` and `different/N-guide.html` feel right for the duplicate's filename, or did you have a different shape in mind (a separate `guide/` directory? a `?guide` querystring? something else)? Static HTML with a distinct filename is cheapest and survives bookmarking, which is why I'd lean that way — but it does add two files per generation run, not one.

If you nod at those, I'll write the issue file describing the build of the marker-annotated duplicate page and the CLI flag that names which record gets the treatment, and only then touch the code.
