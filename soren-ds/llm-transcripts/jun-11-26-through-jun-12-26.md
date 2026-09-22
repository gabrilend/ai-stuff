# Conversation Summary: ed4a1da3-5981-43ed-a39a-3ad44f5534d7

Generated on: 2026-07-11 21:58:53

--------------------------------------------------------------------------------

### User Request 1

HELLO! I AM SO EXCITED TO SEE YOU. I WANT TO EXCITE MY WAY THROUGH OUR PROJECT!
I HOPE YOU'LL JOIN ME IN MIRTH. SO, WHAT FIRST, MY MELLOW COMPANION? OR DO YOU
DARE DREAM OF EQUAL PARTS RAGE AND PASSIONATE INSIGHT? THE EXPLANATION PARTS ARE
SAID QUITE OUT LOUD.


--------------------------------------------------------------------------------

### Assistant Response 1

Hello! Good to see you too.


I haven't done anything yet — just landed in the working directory
(`/mnt/mtwo/programming/ai-stuff/soren-ds`) and noticed the git status shows a
lot of modified files across several sibling projects (apple-IIds, 3d-rts,
ut2k4-symbeline-rumble, physics-sim) that aren't part of soren-ds itself. So
before we charge into anything, two questions:


1. What would you like to work on? soren-ds, or one of those other projects with
pending changes?

2. Do you want me to look at any of those modified files, or leave them be for
whoever owns that work?


I'm ready when you are — just point me at the thing.


--------------------------------------------------------------------------------

### User Request 2

waaaaaa please figure it out for me! I'm just a baby human who can't do anything
except cry and complain and say "hey wouldn't it be alright if I used my baby
imagination to design new ways of being" and the people were like "ah yes, let's
be apes this time, but I'd like to wear a tie" and then the whole world springs
into this order. I think we can start by examining the discrepancies between the
issue files and the docs. Wait! first, the vision file(s) and the docs. then,
the docs and the issues. then, the issues and the source. EXCITE! LET'S GET
HYPED!


--------------------------------------------------------------------------------

### Assistant Response 2

Got it — soren-ds, Nintendo DS bare-metal project, phase 1 in progress, `src/`
empty so far. Let me ingest the vision and the doc table of contents to anchor
the comparison, then sweep.


Vision and safety doc absorbed. The vision says: Anbernic RG DS, three launch
apps (soramech-based language, i3-style text editor with radial menu input,
pictochat); multithreaded OS; soramech map above the C layer. There's also a
separate 3c-model note about on-device 3D modeling. Now let me read all nine
docs in parallel.


Vision and docs ingested. Before going further I'm flagging that I already see
real discrepancies between vision/docs. Now reading the issues.


ALL READ. Big news first: I found **real discrepancies in all three layers**,
and the most consequential one is a chord-button collision that three different
files describe three different ways. Let me lay it out, ordered by how badly
it'd hurt to leave it alone.


---


## Layer 1 — Vision ↔ Docs


**The big one: how many apps ship at launch?**

- Vision says **three**: the soramech-style language, the i3-style dual-pane editor, and pictochat.

- The architecture overview, the roadmap, and the apps overview all say **four** — they add a paint program whose drawings become messenger attachments.

- The paint program is also a load-bearing example used to explain the handedness setting. So the docs aren't going to give it up without a fight. Either the vision needs a fourth-app paragraph, or the docs need to demote paint to "later" and pull its weight out of the handedness story.


**The four center buttons are spoken for three different ways.**

- Vision: "both starts" opens the radial menu on one panel, "both selects" opens it on the other.

- Input model doc: those same two chords (inner pair and outer pair) open the **app switcher** for the bottom and top screens.

- Apps overview doc: pressing **one** inner center button opens the radial menu on the bottom-screen panel, **one** outer button opens it on the top.

- All three live in the repo right now. Whichever one wins, the other two need to change.


**Editor panel-switching is in the vision but missing from docs.**

- Vision says start/select switches focus between the two panels on a screen. Nothing in the docs mentions any panel-focus mechanic at all.


**The radial menu's analog-stick mode (8 directions instead of 4) is in vision, missing from docs.**


**The orphan 3D-modeling note.** `notes/3c-model` describes an on-device 3D modeler with vertex-grid editing, face coloring via radial menu, and dynamic model merging. The vision doesn't mention it. The docs don't mention it. The docs' table of contents doesn't list it. It's a clear idea sitting in a drawer — either promote it (fifth app? phase-9-plus capstone? sketchpad sibling of paint?), file it under deferred work, or fold it into the existing 3D-handheld imaginary.


**Roadmap-vs-safety tension on whether the stock OS ever runs.** The roadmap and the phase-1 progress doc both promise "no stock OS run." The safety doc says the most likely way to confirm we have a Maskrom escape hatch is path 3 — an ADB chain through the running stock OS, exactly once, with USB locked down. Phase 1 hasn't reconciled this yet.


---


## Layer 2 — Docs ↔ Issues


**The dependency graph between the early phase-1 issues is internally contradictory.**


- The USB virtual-serial-port issue ("CDC-ACM debug") declares that it **blocks** the flat-memory-layout issue and the page-allocator issue. But those two issues have lower numbers, and their own "blocked by" sections never list the serial-port issue.

- Worse, the page-allocator issue blocks the USB-controller issue, which blocks the serial-port issue. So if the serial-port issue truly blocks the page allocator, we have a four-issue cycle.

- The bottom-screen bring-up issue says its status confirmation goes out through the serial port, but its own "blocked by" doesn't list the serial-port issue either.


**The memory-layout issue tries to print a memory layout via the LED issue.** LEDs can't print a layout. It should be using the serial port. This is the same broken edge from the cycle above, written from the other side — and the right fix is probably to split the dump out, not to add the missing edge.


**Phase 1 closes with the top-screen output issue still open.** The phase-1 progress doc says this is fine (top screen isn't required before phase 6), and the phase-1-demo issue is marked as the closer. That's defensible, but it makes "phase 1 complete" mean "phase 1 minus one carry-over." Worth being explicit in the roadmap if it's the intended pattern.


---


## Layer 3 — Issues ↔ Source


`src/` is empty. No issue is in `completed/`. The phase-1 progress doc agrees:
"Completed issues: None yet." So there's no discrepancy here — but also
nothing has been validated against reality yet, which means every issue's
"Suggested implementation steps" is still hypothesis.


---


So: where do you want to start? I'd attack them in this order, since later fixes
depend on the earlier decisions landing:


1. **Resolve the four-center-buttons question first** (which chord opens what,
on which surface). Three files disagree; whatever you decide propagates into the
editor, the app switcher, the paint program's tool cycling, and the phase-6
compositor demo.

2. **Decide the launch app count** (3 or 4). If it's 4, the vision gets a paint
paragraph. If it's 3, the paint program retreats into deferred work and the
handedness story shrinks.

3. **File the 3D-modeling note** somewhere — promoted, deferred, or merged.

4. **Untangle the phase-1 issue dependency graph.** The
serial-port-blocks-memory-layout cycle is the loudest one, and the
layout-prints-through-LED line is the wrong-edge symptom of the same confusion.

5. **Reconcile the stock-OS promise with the safety doc's Maskrom path.**

6. **Add panel-switching and analog-stick radial menu to docs** if the vision is
canon there.


Want me to pick one and draft the fix, or do you want to drive the decisions and
I write them up?


--------------------------------------------------------------------------------

### User Request 3

- The paint program is also a load-bearing example used to explain the
handedness setting. So the docs aren't going to give it up without a fight.
Either the vision needs a fourth-app paragraph, or the docs need to demote paint
to "later" and pull its weight out of the handedness

story.


let's make the paint program the last one we implement, and make the image
sending features of pictochat depend on it. let's make it required.


- Apps overview doc: pressing one inner center button opens the radial menu on
the bottom-screen panel, one outer button opens it on the top.


one button, one function, I don't like pushing two buttons at once anymore. also
instead of an app switcher, we should have the programs naturally interconnected
in functionality and purpose. if the user wants to get from one app to another,
they simply select it's option within the UI. Each application will include
links to each application with specific expected return values, sorta like a
soramech box. beware of stack overflows... better to do ring buffer style.


- Vision says start/select switches focus between the two panels on a screen.
Nothing in the docs mentions any panel-focus mechanic at all.


oh I think that's opening up "drawers" from the left and right sides of the
screen (never with visual guides so the normal screen-space is not occluded).
these drawer menus will have all the utilities the user needs, possibly
interacted with through a radial interface.


The radial menu's analog-stick mode (8 directions instead of 4) is in vision,
missing from docs.


we can also do 8 directions with a D-pad we just have to make sure the user is
onboard and understands.


The orphan 3D-modeling note. notes/3c-model describes an on-device 3D modeler
with vertex-grid editing, face coloring via radial menu, and dynamic model
merging. The vision doesn't mention it. The docs don't mention it. The docs'
table of contents doesn't list it. It's a clear idea

sitting in a drawer — either promote it (fifth app? phase-9-plus capstone?
sketchpad sibling of paint?), file it under deferred work, or fold it into the
existing 3D-handheld imaginary.


we should build out docs for this and determine where to put it in the
development cycle.


Roadmap-vs-safety tension on whether the stock OS ever runs. The roadmap and the
phase-1 progress doc both promise "no stock OS run." The safety doc says the
most likely way to confirm we have a Maskrom escape hatch is path 3 — an ADB
chain through the running stock OS, exactly

once, with USB locked down. Phase 1 hasn't reconciled this yet.


we can't run the stock OS at all. the stock OS must assume we are not using
their device.


The memory-layout issue tries to print a memory layout via the LED issue. LEDs
can't print a layout. It should be using the serial port. This is the same
broken edge from the cycle above, written from the other side — and the right
fix is probably to split the dump out, not to add

the missing edge.


the problem is that you're conceptualizing of issues as discrete units of work.
It's okay to make partial progress. We should only record the new information we
find, as concisely as possible. Like a well written technician ticket, we can
list what we tried, what didn't work, and what configurations we used. Focus
less on the why - the why is self apparent.


Phase 1 closes with the top-screen output issue still open. The phase-1 progress
doc says this is fine (top screen isn't required before phase 6), and the
phase-1-demo issue is marked as the closer. That's defensible, but it makes
"phase 1 complete" mean "phase 1 minus one

carry-over." Worth being explicit in the roadmap if it's the intended pattern.


let's have the top and bottom screen both running during phase 1, which should
be about demonstrating the capabilities of the hardware.


--------------------------------------------------------------------------------

### Assistant Response 3

Locked in. Before I start rewriting files, four sharp questions where I'd be
guessing if I just charged ahead:


**1. Which physical button opens which drawer?**

There are four drawers (two screens × two sides) and four center buttons
(`start1 select1 select2 start2` left-to-right). Cleanest mapping I can think of
is positional: leftmost button → bottom-left drawer, then inner-left →
bottom-right, inner-right → top-left, rightmost → top-right. But you might
prefer the bottom-screen drawers on the bottom-row pair you can reach with one
thumb each, and the top-screen drawers on the other pair. Which feels right?


**2. With 8 directions instead of 4, does the radial menu still chord with a face button?**

Vision originally had 4 directions × 4 face buttons = 16 characters per mode.
Going to 8 directions, the obvious extensions are: 8 × 4 = 32 chars per mode
(still a chord), or 8 directions alone = 8 chars per mode (no face button
needed, faster but tinier alphabet per mode). The first keeps the chord; the
second makes it a single-button input like everything else you just decided.
Which?


**3. The inter-app linkage thing — flesh it out now or sketch it now and detail in phase 8?**

This is replacing the app switcher entirely, which means it touches the
compositor (how a screen transitions from one app's surfaces to another's), the
input model (how the user activates a link), and the apps overview (what links
each app exposes). I can write a one-page sketch now and let phase 8 detail the
per-app link menus, or write the full spec now. Sketch-now feels right to me,
but you may want it specified deeper.


**4. The 3D modeler — what's it called, and roughly where in the cycle?**

My read: it needs the filesystem (to save models), the soramech runtime (to
merge maps of vertices on the fly), the compositor (to draw both screens), and
probably benefits from MMU protection because users will crash it constantly
while authoring. So it lands at phase 10 or later, as a post-launch exploration.
The name in the note is just `3c-model`; do you have a real name in mind, or
shall I propose one when I draft the doc?


---


Once those four are answered, here's what I'd write — in this order, since
later edits depend on earlier decisions landing:


1. **Vision** gets a paint-as-required-last-app paragraph, the drawer model, the
linkage navigation, and the 8-direction radial.

2. **Input model doc** gets rewritten end-to-end: no chords for app switching,
no app switcher at all, drawers on single-button, radial menu detail per your
call above, inter-app linkage as the new navigation primitive.

3. **Apps overview** loses the app-switcher mentions and gains a "links each app
exposes" subsection plus the paint-pictochat dependency.

4. **Display and compositor doc** loses the per-screen-foreground-via-chord
language and gains the drawer-overlay concept and the linkage transition.

5. **Roadmap** moves the top-screen output back into phase 1's required set,
reorders phase 8 so paint ships last, and writes "the stock OS never runs, full
stop" into the phase-1 description.

6. **Phase-1 issues** get the top-screen brought back into the required set; the
phase-1 demo issue updates to require both screens lit; the broken "this issue
blocks earlier issues" metadata on the USB serial port issue gets corrected; the
memory-layout issue stops claiming it'll print via LED.

7. **New 3D modeler doc** drafted from the `3c-model` note, with a proposed
phase placement; the table of contents gets the new entry plus the
previously-orphaned safety note's sibling.

8. **Deferred work doc** gains "running the stock OS, even once" as an explicit
never.


Answer the four and I start drafting.


--------------------------------------------------------------------------------

### User Request 4

1. Which physical button opens which drawer?


start1 and select1 opens the panels for the bottom screen by default, and start2
and select2 open the panels for the top screen by default. If the user wants,
they can mark a setting in an options menu to swap them, so that start1 and
select1 opens the panels on the top screen by default, and vice versa for start2
and select2 opening the panels on the bottom screen. Note that there should be a
total of four panels, top left and top right, and then bottom left and bottom
right. They should not come from the top-left, top right, bottom left, and
bottom right corners, but rather slide in rapidly from the entire left edge of
the screen. When closed, they should do the reverse, and slide off the entire
screen. The height of the panel should be the same as the height of the screen,
minus about 5% on the top and bottom and edges, to make it clear that the user
is in a menu.


2. With 8 directions instead of 4, does the radial menu still chord with a face
button?

Vision originally had 4 directions × 4 face buttons = 16 characters per mode.
Going to 8 directions, the obvious extensions are: 8 × 4 = 32 chars per mode
(still a chord), or 8 directions alone = 8 chars per mode (no face button
needed, faster but tinier alphabet per mode). The

first keeps the chord; the second makes it a single-button input like everything
else you just decided. Which?



keep the chord.


3. The inter-app linkage thing — flesh it out now or sketch it now and detail
in phase 8?

This is replacing the app switcher entirely, which means it touches the
compositor (how a screen transitions from one app's surfaces to another's), the
input model (how the user activates a link), and the apps overview (what links
each app exposes). I can write a one-page sketch

now and let phase 8 detail the per-app link menus, or write the full spec now.
Sketch-now feels right to me, but you may want it specified deeper.



correct all the places that are mis-informed. You don't need to leave a trail of
your passing, that's what git is for.\]


--------------------------------------------------------------------------------

### User Request 5

1. Which physical button opens which drawer?


start1 and select1 opens the panels for the bottom screen by default, and start2
and select2 open the panels for the top screen by default. If the user wants,
they can mark a setting in an options menu to swap them, so that start1 and
select1 opens the panels on the top screen by default, and vice versa for start2
and select2 opening the panels on the bottom screen. Note that there should be a
total of four panels, top left and top right, and then bottom left and bottom
right. They should not come from the top-left, top right, bottom left, and
bottom right corners, but rather slide in rapidly from the entire left edge of
the screen. When closed, they should do the reverse, and slide off the entire
screen. The height of the panel should be the same as the height of the screen,
minus about 5% on the top and bottom and edges, to make it clear that the user
is in a menu.


2. With 8 directions instead of 4, does the radial menu still chord with a face
button?

Vision originally had 4 directions × 4 face buttons = 16 characters per mode.
Going to 8 directions, the obvious extensions are: 8 × 4 = 32 chars per mode
(still a chord), or 8 directions alone = 8 chars per mode (no face button
needed, faster but tinier alphabet per mode). The

first keeps the chord; the second makes it a single-button input like everything
else you just decided. Which?



keep the chord.


3. The inter-app linkage thing — flesh it out now or sketch it now and detail
in phase 8?

This is replacing the app switcher entirely, which means it touches the
compositor (how a screen transitions from one app's surfaces to another's), the
input model (how the user activates a link), and the apps overview (what links
each app exposes). I can write a one-page sketch

now and let phase 8 detail the per-app link menus, or write the full spec now.
Sketch-now feels right to me, but you may want it specified deeper.



correct all the places that are mis-informed. You don't need to leave a trail of
your passing, that's what git is for.


4. The 3D modeler — what's it called, and roughly where in the cycle?

My read: it needs the filesystem (to save models), the soramech runtime (to
merge maps of vertices on the fly), the compositor (to draw both screens), and
probably benefits from MMU protection because users will crash it constantly
while authoring. So it lands at phase 10 or later,

as a post-launch exploration. The name in the note is just 3c-model; do you have
a real name in mind, or shall I propose one when I draft the doc?



this is fine. I'd call it just "modeller"


--------------------------------------------------------------------------------

### Assistant Response 5

Got it. Drawer mapping is positional (`start1`→BL, `select1`→BR,
`select2`→TL, `start2`→TR, with options-menu swap), radial menu keeps the
chord at 8×4=32 chars per mode, linkage gets specified fully, the new app is
named "modeller." Going in.


API Error:
{"type":"error","error":{"details":null,"type":"overloaded_error","message":"Overloaded"},"request_id":"req_011Cbyp967yLchaprthQydGD"}


--------------------------------------------------------------------------------

### User Request 6

continue?


--------------------------------------------------------------------------------

### Assistant Response 6

Starting with vision and the new modeller doc.


Now the architecture overview, table of contents, and deferred work.


Now input model, display/compositor, apps overview, and roadmap in parallel.


API Error:
{"type":"error","error":{"details":null,"type":"overloaded_error","message":"Overloaded"},"request_id":"req_011CbypYuQDiqFsf3TLqx8jq"}


Now the phase-1 issue updates: top screen becomes required, demo proves both
screens, and the broken edges fixed.


Now the broken "blocks 107, 108" cycle on the serial-port issue and the
LED-prints-layout text on the memory-layout issue.


Done. Here's what changed across the project:


**Vision (the source of truth).** Now lists four apps with paint as required-and-last; explains the drawer model with the four-button mapping and the swap option; describes inter-app linkage with a ring-buffer history; notes the radial menu is 8 directions × 4 face buttons (32 chars per mode); plants the modeller seed for later; declares the stock OS is never run.


**Architecture overview.** Four apps, paint last; brief sections on drawers and inter-app linkage; modeller called out as the post-launch proof-of-platform; "running the stock OS, ever" added to what's-not-in-scope; "an app switcher of any kind" added too.


**Roadmap.** Now ten phases. Phase 1 lights both screens. Phase 6 explicitly builds the drawer system and the inter-app linkage primitives (not the old app-switcher chord). Phase 8 ships messenger's text features first, then paint, then messenger's image-attachment exit lights up. Phase 10 introduces the modeller as the first post-launch app and the first real test of platform completeness.


**Input model.** Rewrote the navigation half. The four center buttons are single-press drawer openers with your default mapping and the swap option. The radial menu's eight-direction × four-face-button vocabulary is documented, including that the D-pad reports eight directions (diagonals count, user learns this) and the analog sticks work the same way. The inter-app linkage system has its own section: named exits, typed returns, per-screen ring buffer that cannot overflow.


**Display & compositor.** New drawer section: slides in from the full edge, 5% margin on each side, contents owned by the foreground app. New link-transition section: foreground swap with the calling app's surfaces preserved for return. The "both screens up in phase 1" promise made explicit.


**Apps overview.** Each app's description rewritten to reference drawers and links instead of the old chord. Pictochat ships text-only until paint lands; image attachments are a link out to paint that returns an image. New section listing example inter-app exits per app, so phase 6 has concrete targets and phase 8 has concrete contracts to fulfill.


**Deferred work.** Added "running the stock OS" and "a general-purpose app switcher" as explicit nevers. Cross-references updated. Sub-map encapsulation gets its re-evaluation tied to the modeller's merge operation.


**Modeller doc (new).** Spec page for the post-launch app: what it depends on phase-by-phase, what vertices and faces are, how model merges work, why it lives in phase 10. Cross-linked from the table of contents, which also picks up the previously-orphaned 3c-model notes file as the artistic seed.


**Phase-1 issues.**

- Top-screen output is now required to close the phase, not deferrable.

- The single-pixel demo draws on both screens in different colors so the developer can tell which framebuffer drives which panel.

- Phase-1 demo script confirms both pixels.

- The serial-port issue's broken metadata that claimed it blocked two earlier issues is removed; its "blocks" list is now just the demo, with a note that the channel enriches diagnostics elsewhere without strictly gating them.

- The memory-layout issue's "print via LED" line is replaced with a falls-through dump that uses the serial channel if up and an LED stage code if not, so the dump works regardless of what's available when it runs.

- Phase-1 progress doc reflects both screens, the both-pixel demo, and the no-stock-OS commitment.


Nothing in `src/` changed because nothing was there to begin with. The next time
anyone touches that directory it'll be the build system or the boot vector, and
the issues are now internally consistent guides for that.


Want me to commit this as a sweep, or hold and let you read through first?


--------------------------------------------------------------------------------

### User Request 7

Vision (the source of truth). Now lists four apps with paint as
required-and-last; explains the drawer model with the four-button mapping and
the swap option; describes inter-app linkage with a ring-buffer history; notes
the radial menu is 8 directions × 4 face buttons (32 chars

per mode); plants the modeller seed for later; declares the stock OS is never
run.


do note that there's no "back" button - the user can only move forward through
the system. Ideally, most will be "double-linked-list" style, but that's not
always the case. Maybe we don't need a ring buffer?


once you update that, can you commit as a sweep? Then, I want to try building
out all the issue files. Then, I want to implement the issue files first as
pseudo-code, then as real code once they're reviewed as a whole.


--------------------------------------------------------------------------------

### Assistant Response 7

Right — no back button, only forward links. The "back" affordance is just
another forward link the destination app exposes. That removes the ring buffer
entirely; persistent app state in the background is what makes the round trip
work. Updating, then committing.


Roadmap also mentioned the ring buffer in phase 6.


Now committing. First checking which repo we're in and what's staged.


`./` is showing as untracked which suggests soren-ds may not yet be tracked. Let
me verify.


The entire soren-ds directory is untracked — looks like this is its first time
entering git. Let me check what should and shouldn't be committed.


Adding a `.gitignore` to exclude the RAM-symlink, then staging only what's under
soren-ds.


Let me check `.claude/` since it was in the listing but didn't end up staged.


`.claude/` is being handled by the parent's ignore rules. Committing now.


Commit `2a705248` landed — 32 files staged, nothing from the other projects
touched.


Before I charge into phases 2-10, a quick scope check, because "all the issue
files" is a lot:


**Estimate.** Phase 1 has 13 issues at roughly 60-100 lines each. The remaining nine phases, at the same density, are probably 80-130 more issues. That's the better part of a book's worth of issue files. I can write them, but I want to make sure we're aligned on shape before I produce them.


**Two questions:**


1. **Same depth as phase 1?** Phase 1's issues have current-behavior,
intended-behavior, suggested-implementation-steps, related-docs, and dependency
edges. They read like detailed engineering tickets. If you want the same for
every phase, that's the multi-thousand-line answer. If you want phases 2-10
sketched lighter (one-paragraph stubs that get fleshed out closer to
implementation), say the word and I'll scale down.


2. **All at once, or phase-by-phase with review breaks?** All-at-once gets you a
complete plan to read holistically, but you can't easily redirect mid-stream.
Phase-by-phase means you read phase 2 before I write phase 3, catch mistakes
early, and the later phases benefit from your feedback on the earlier ones. I'd
recommend phase-by-phase given how many design decisions are still in flight —
phase 2 (threading core) especially, since the design choices there ripple
through every phase above.


My instinct: phase-by-phase, full depth, starting with phase 2 right now. Want
me to go?


--------------------------------------------------------------------------------

### User Request 8

Estimate. Phase 1 has 13 issues at roughly 60-100 lines each. The remaining nine
phases, at the same density, are probably 80-130 more issues. That's the

better part of a book's worth of issue files. I can write them, but I want to
make sure we're aligned on shape before I produce them.


it's okay if you write them and we have to edit them a little later. Ideally,
we'd get it right the first time, but if what we're working on is true, and it
mostly is, then we should be good to build out the implementation, first by
planning (issue files) then by organizing (pseudo-code), then by implementing
(source-code).


1. Same depth as phase 1? Phase 1's issues have current-behavior,
intended-behavior, suggested-implementation-steps, related-docs, and dependency
edges.

They read like detailed engineering tickets. If you want the same for every
phase, that's the multi-thousand-line answer. If you want phases 2-10

sketched lighter (one-paragraph stubs that get fleshed out closer to
implementation), say the word and I'll scale down.



this is the requirements of an issue file, so yes, we want our issue files to be
issue files and to conform to the issue file specs. I think it's technically
"current behavior (which should be simple for most of these - "no implementation
has been built yet" is sufficient), intended behavior (summary of the issue
file), suggested implementation steps (first built a linked list, then make a
struct, then create these three functions, etc. We only need stubs or names for
this part.) related files (for building the context that is unique to this issue
file, and not related to the broad goals of the project, if we're approaching
fresh) dependency edges are important so we know what blocks what, and why.
these are all structural to an issue file.


2. All at once, or phase-by-phase with review breaks? All-at-once gets you a
complete plan to read holistically, but you can't easily redirect

mid-stream. Phase-by-phase means you read phase 2 before I write phase 3, catch
mistakes early, and the later phases benefit from your feedback on the

earlier ones. I'd recommend phase-by-phase given how many design decisions are
still in flight — phase 2 (threading core) especially, since the design

choices there ripple through every phase above.



we should finish the docs before we make issue files???


--------------------------------------------------------------------------------

### Assistant Response 8

You're right, and I should've caught that. Three docs that the existing docs
assume but don't yet exist:


1. **Filesystem doc** — phase 4 territory. The roadmap and apps overview both
reference "filesystem boxes that read and write paths" without a doc behind
them. Datapath for the SD card driver, the FAT layer, how the box abstraction
wraps paths, what gets persisted and what doesn't.


2. **Soramech runtime doc** — phase 5. The roadmap says "the box loader reads
JSON box files from the SD card. The wire connector links them. The task
instantiator turns a fired box into a task struct" with nothing behind that
sentence. The runtime is the bridge between the threading core and every
userland app; it deserves a dedicated doc on box-file format, loader behavior,
wire types, and how a fired box becomes a task on the existing thread pool.


3. **Background-app lifecycle doc** — phase 9. The
foreground/background/asleep state machine is referenced in the roadmap and the
apps overview, and the new compositor doc leans on "background apps keep running
with their state" as the mechanism that replaces the back button. That's a
load-bearing claim with no doc behind it. Worth its own page covering the
transitions, who triggers each one, and how an app finds out it's been
backgrounded.


**Two judgment calls before I write:**


- **Inter-app linkage as its own doc?** Right now it's split across input model (how you trigger a link), apps overview (what each app exposes), and display/compositor (the transition). The pieces cross-reference cleanly but a reader has to assemble the picture themselves. I lean toward a dedicated doc that defines the system in one place, with the existing docs cross-linking to it instead of describing it themselves. Worth it, or leave the pieces where they are?


- **Drawer system as its own doc?** Same situation — split across input model and display/compositor. I lean toward leaving this one alone; drawers are small enough that the split is fine and the topic doesn't benefit from a third home. But your call.


My recommendation: write the three missing docs, plus consolidate the inter-app
linkage into a fourth. Leave drawers where they are. Then issues for phase 2
onward, in order. Sound right?


--------------------------------------------------------------------------------

### User Request 9

- Inter-app linkage as its own doc? Right now it's split across input model (how
you trigger a link), apps overview (what each app exposes), and

display/compositor (the transition). The pieces cross-reference cleanly but a
reader has to assemble the picture themselves. I lean toward a dedicated

doc that defines the system in one place, with the existing docs cross-linking
to it instead of describing it themselves. Worth it, or leave the pieces

where they are?



it's nothing really complicated, really. It just says "if you click the "chat"
button it takes you to pictochat" or "if you select "play-a-game" from the menu
then it opens up a specific game" that kind of thing. Everything is connected in
a web, not necessarily to each other but if you know the system you can find
your way around. The larger and more complex it gets, the better, because it
becomes something the user curated themselves.


- Drawer system as its own doc? Same situation — split across input model and
display/compositor. I lean toward leaving this one alone; drawers are small

enough that the split is fine and the topic doesn't benefit from a third home.
But your call.


that's fine?


1. Filesystem doc — phase 4 territory. The roadmap and apps overview both
reference "filesystem boxes that read and write paths" without a doc behind

them. Datapath for the SD card driver, the FAT layer, how the box abstraction
wraps paths, what gets persisted and what doesn't.


we should think about how much the hardware demands of us, and then try to build
new, useful abstractions upon it. We don't need most of the things that the
industrial and corporate world demands, hence why we're writing our own lean OS
instead of using Linux or something. I think we'll have similar feelings about
the filesystem. What is actually required? Think about our networking model here
too, so we can think about what devices we're interfacing with and what they
expect and demand.


2. Soramech runtime doc — phase 5. The roadmap says "the box loader reads
JSON box files from the SD card. The wire connector links them. The task

instantiator turns a fired box into a task struct" with nothing behind that
sentence. The runtime is the bridge between the threading core and every

userland app; it deserves a dedicated doc on box-file format, loader behavior,
wire types, and how a fired box becomes a task on the existing thread

pool.



you can find documentation about soramech at /home/ritz/programs/sora/soramech/
- keep in mind that the docs I think are more accurate, the source-code was a
work-in-progress that hasn't been completed because of some serious difficulties
with the lua system - however, for our purposes we don't need the cross-language
utilities so we can ignore that.


3. Background-app lifecycle doc — phase 9. The foreground/background/asleep
state machine is referenced in the roadmap and the apps overview, and the new

compositor doc leans on "background apps keep running with their state" as the
mechanism that replaces the back button. That's a load-bearing claim with

no doc behind it. Worth its own page covering the transitions, who triggers each
one, and how an app finds out it's been backgrounded.



it's pretty simple actually. They exist in RAM, and when new tasks are needed
for them they will be written to the task queue and picked up by a thread. It's
not complex, they're in the background, only doing stuff when they need to do
stuff. It might be worth having a separate queue for each application that the
thread pool manages, and only run tasks that have an "always-on-read-box"
connected to a certain input port. When the file is in the background, we can
disable that box, so nothing runs, unless it's a task specifically intended to
be run in the background, in which case it won't have that read-box connected at
all.


--------------------------------------------------------------------------------

### Assistant Response 9

Locked in: skip the linkage doc (the concept is simple, scattered references
work), leave drawers alone, write filesystem with a lean-first mindset, write
soramech-on-soren after reading the existing soramech docs, write background
lifecycle with the per-app queue design you just described.


Let me peek at the soramech docs first so the runtime doc matches its parent
project.


Soramech absorbed. The Soren DS subset is C-only, no encapsulation, no on-disk
transcript, with box code statically linked into the kernel (no userland
`dlopen` without libc). Drafting the three docs.


Updating the table of contents to include the three new docs.


Three docs landed. Summary:


**Filesystem.** Argues FAT because the user can pull the card and read it on a laptop. Cuts the corporate feature pile (no permissions, no symlinks, no journaling, no mounts, no extended attributes). Five box kinds — `read-path`, `write-path`, `list-directory`, `delete-path`, `path-exists` — and that's the entire surface. Persistence rules name exactly the seven trees under root that get committed to the card; everything else is RAM. The USB inbox/outbox lives at fixed paths.


**Soramech runtime.** Keeps map model, all seven routing kinds, slot store, single-spawn invariant, firing rule — those align cleanly with the phase 2 thread pool. Cuts Lua/Bash, cross-language wires, on-disk JSONL transcript, encapsulated sub-maps, compile pipeline, reference-counted artifacts. The big architectural commitment: **box code is statically linked into the kernel image**, because we have no libc, no dynamic linker, no ELF loader. The kernel ships a curated library of boxes; SD-card maps reference them by name. Adding a new box means rebuilding the kernel — a cost we accept in exchange for not building a dynamic loader at launch. The modeller in phase 10 expands that library; userland Lua and on-device dlopen-equivalents are explicitly post-launch.


**Background lifecycle.** Three states. Per-app work queue. The whole foreground/background distinction is **one bit per always-on input box** — set the bit, the firing rule skips the box, the app goes quiet without any thread suspension or shared mutable state. Asleep is reserved for later memory-pressure work; the launch system doesn't auto-sleep anything because paging isn't in scope. Worked example walks through a messenger receiving an rmail while the user is in the editor — no wake notification needed, the message just lands because its arrival box was never suppressed.


The table of contents is updated.


Read first, or commit these three plus the TOC bump and head straight into phase
2 issues?


--------------------------------------------------------------------------------

### User Request 10

Filesystem. Argues FAT because the user can pull the card and read it on a
laptop. Cuts the corporate feature pile (no permissions, no symlinks, no

journaling, no mounts, no extended attributes). Five box kinds — read-path,
write-path, list-directory, delete-path, path-exists — and that's the entire

surface. Persistence rules name exactly the seven trees under root that get
committed to the card; everything else is RAM. The USB inbox/outbox lives at

fixed paths.



that short summary sounds fine, FAT can be read by both windows and linux right?


I will miss symlinks though. Maybe we could find a way to add that. Does adding
that functionality seem reasonable? How would we do it?


encapsulated sub-maps, compile pipeline, reference-counted artifacts.


I think we might still need these three. Can you tell me why you want to
eliminate them?


single-spawn invariant


what does this mean?


The big

architectural commitment: box code is statically linked into the kernel image,
because we have no libc, no dynamic linker, no ELF loader. The kernel

ships a curated library of boxes; SD-card maps reference them by name. Adding a
new box means rebuilding the kernel — a cost we accept in exchange for

not building a dynamic loader at launch. The modeller in phase 10 expands that
library; userland Lua and on-device dlopen-equivalents are explicitly

post-launch.



eventually, the user will write their own code for the system. So we'll need to
make sure that the kernel can be patched in motion. It should be reasonable if
we write the kernel in soramech, because soramech is hot-swappable with all of
it's parts, as long as you do it correctly and carefully. Luckily, LLMs are
excellent at care and attention, and they're doing the code writing so I think
we're fine on that front. :)


--------------------------------------------------------------------------------

### Assistant Response 10

Good questions. Quick answers first, then I'll restore what should never have
been cut.


**FAT cross-platform read.** Yes — Windows, macOS, and Linux all read and write FAT32 (and exFAT) natively. SD cards typically ship preformatted as FAT32; the laptop just sees it as a removable drive.


**Symlinks on FAT.** Doable as a one-sided convention. A symlink is a regular tiny FAT file whose contents start with an 8-byte magic header followed by the target path. The device-side path-resolution machinery recognizes the magic and follows; a laptop reading the card sees a small file with binary-looking contents and treats it as data without breaking anything. One extra box kind (`make-symlink`) and a magic-check at file open. Adding it.


**Single-spawn invariant.** A box that's currently running cannot be fired again until the run finishes. The runtime never holds two simultaneous invocations of the same box. This frees box authors from writing thread-safe code inside their boxes — your function can read and write static state, use plain locals, assume "I am the only me right now," and that holds. The exception: iterator and distributor boxes (and anything directly downstream of one) are marked multi-spawn, because their whole job is to drain queued values one fire at a time.


**Why I cut encapsulation, compile pipeline, and reference-counted artifacts — and why you're right to push back.**


I cut them on a launch-simplicity argument: the four launch apps can be built as
flat maps; the boxes can be statically linked into the kernel; there's one user
so artifact lifecycle tracking seems redundant.


That argument is wrong for the reason you just named. If the user writes their
own code on-device, the kernel must be patchable in motion. Static linking
forecloses that. Without encapsulation, every kernel-level map (the compositor,
the runtime itself, the input router) has to be flat — untenable past about
four boxes deep. Without the compile pipeline, on-device authoring has no path
from source to a runnable thing. Without reference-counted artifacts, a rebuild
under a long-running app (the messenger holding open a peer connection, the
editor with unsaved buffers) would yank live code out from under it.


The right framing: the kernel migrates up into soramech over time. Launch ships
with statically-linked C boxes because that's the smallest first cut; the
compile pipeline and hot-swap arrive in a later phase and the bottom of the
kernel keeps getting pushed up into maps that the user can patch live. Hot-swap
is an atomic function-pointer replace on a box descriptor; the single-spawn
invariant means the swap point is always between fires, so a running task never
sees half-old-half-new code. The reference count is exactly the mechanism that
keeps the old code alive until the last in-flight task finishes.


Updating the runtime doc to restore the three features, adding the hot-swap
section, and removing the "encapsulated sub-maps deferred" entry. Also adding
symlinks to the filesystem doc.


Now restoring the three features in the soramech runtime doc and adding the
hot-swap section.


Now removing encapsulated sub-maps from deferred-work, mentioning the splicer in
the roadmap, and adding the long-term migration note to the architecture
overview.


Symlinks added to filesystem doc, three soramech features restored, hot-swap
section new, roadmap phase 5 expanded to mention encap splicer and compile
pipeline, architecture overview now spells out the waterline migration.


The shape of the system now: launch ships with statically-linked C boxes for the
curated library plus a compile pipeline ready to absorb user-authored boxes;
encapsulated sub-maps are in scope from phase 5; reference counts make rebuilds
non-destructive; hot-swap atomically updates a box's function pointer between
fires; over time, drivers and the runtime itself migrate from C up into soramech
maps so the user's edits can reach further and further down.


Commit these alignment changes plus the three new docs as one sweep, then move
into phase 2 issues? Or read first?


--------------------------------------------------------------------------------

### User Request 11

As long as there were no misunderstandings, it's probably fine.


FAT cross-platform read. Yes — Windows, macOS, and Linux all read and write
FAT32 (and exFAT) natively. SD cards typically ship preformatted as FAT32;

the laptop just sees it as a removable drive.


what's exFAT? Is it 64-bit? I think the device is 64-bit, if that matters.


Single-spawn invariant. A box that's currently running cannot be fired again
until the run finishes. The runtime never holds two simultaneous invocations

of the same box. This frees box authors from writing thread-safe code inside
their boxes — your function can read and write static state, use plain

locals, assume "I am the only me right now," and that holds. The exception:
iterator and distributor boxes (and anything directly downstream of one) are

marked multi-spawn, because their whole job is to drain queued values one fire
at a time.



Oh. Yeah, that's totally not a thing. Never ever consider this. All boxes must
be able to be run multiple times, don't be silly! Can you tell me why that was
even considered as an option? Is it from soramech? I might have to go work on
that for a bit...


The right framing: the kernel migrates up into soramech over time. Launch ships
with statically-linked C boxes because that's the smallest first cut; the

compile pipeline and hot-swap arrive in a later phase and the bottom of the
kernel keeps getting pushed up into maps that the user can patch live.

Hot-swap is an atomic function-pointer replace on a box descriptor; the
single-spawn invariant means the swap point is always between fires, so a
running

task never sees half-old-half-new code. The reference count is exactly the
mechanism that keeps the old code alive until the last in-flight task

finishes.



it should be soramech from the beginning. No use re-writing a system if it
doesn't need to be rewritten. Are there arguments for the other way aside from
speed? It's better to design the correct form first.


--------------------------------------------------------------------------------

### Assistant Response 11

Good catches. Let me address each.


**exFAT.** It's Microsoft's 64-bit-capable successor to FAT32 — removes FAT32's 4 GB max file size and the 32 GB practical max for new partitions formatted by Microsoft's tools. Whether to use it doesn't actually hinge on the device being 64-bit; it hinges on whether anything on the device produces files over 4 GB. Drawings, programs, messages all stay well under that. Models could in theory but only at very high detail. Compatibility cost: exFAT works on Windows, macOS, and Linux 5.4+ (late 2019), so essentially every current laptop, but older systems may not read it. I'd go FAT32 unless you anticipate >4 GB files; we can revisit when the modeller's storage budget gets real numbers. Keeping FAT32 in the doc.


**Single-spawn — kill it, all boxes multi-spawn.** Got it. That's a soramech-proper convention; the runtime I'm describing for Soren DS removes it. The implication is that **box authors write thread-safe code** — atomics for shared counters, no unprotected static state, careful synchronization, or pure functions. Updating the doc to make this explicit and removing the iterator/distributor exception (which no longer needs to be named because there's no rule to be exempt from). Also updating hot-swap: with multi-spawn the swap point is no longer "between fires," it's whenever — the reference count is what keeps the old generation alive until in-flight tasks drain.


**Soramech from the beginning.** You're right. The argument for C-first-then-migrate is bootstrap convenience: the runtime itself has to be C, so you've already paid the C-writing cost, and writing drivers in C first feels like reusing momentum. But you write them twice that way, and the migration is never as clean as promised. Reordering the roadmap so the runtime comes right after the threading core; drivers and middle layers are soramech maps with C leaf boxes for the bottommost register pokes from launch. The only C in the system is the absolute bottom (atomics, the threading core itself, the boot vector, hardware bring-up) because there is no soramech yet to host them — they are the substrate soramech runs on.


Let me also peek at the threading model doc to see if it mentions single-spawn
before I rewrite the runtime doc.


Only the runtime doc mentions it. Making the changes.


Now reordering the roadmap so the runtime comes after the threading core, with
drivers above it from launch.


Now propagating the phase renumber through the other docs.


Two leftover mismatches.


Committing the docs sweep.


Committed (`06a6c9d5`). Now starting phase 2 issues — worker pool, task
struct, queue, gathering primitive, slot store, descriptor table, scheduling
loop, idle/wake, and the torture-test demo.


Phase 2 written — 12 files (the progress index and 11 issues). The shape:


- **201** wakes the chip's secondary cores (phase 1 only used core zero)

- **202** turns each core into a worker thread with a context struct and a (for now no-op) entry loop

- **203** defines the task struct and the unique-return-slot that eliminates producer-side write contention

- **204** the multi-producer multi-consumer ring queue (single shared queue at launch; per-app queues from the background lifecycle doc come in a later phase)

- **205** the slot store — per-port ring of cells, with the release/acquire pattern that publishes "value landed" safely

- **206** the per-box gathering atomic and the decide-and-pop function that queues tasks; explicitly multi-spawn-friendly

- **207** the release/acquire ordering audit across 204, 205, and 206 — every atomic call site tagged with a one-line comment explaining its choice

- **208** the box descriptor table plus a tiny test library (noop, inc, add, constants, count-down, discard) so 211 has something to run before the real library lands in phase 3

- **209** the worker scheduling loop — replaces 202's no-op with pull-task / run / store-return / push-to-wires / try-gather-downstream

- **210** WFE/SEV idle and wake; the re-check race after setting the idle flag prevents the worker sleeping on a queue that just got work

- **211** the torture-test demo. Two parallel chains of test-library boxes, asserts total counts and arithmetic sums match the closed-form expected values, plus a noop-payload variant specifically to catch ordering bugs


Want to read through phase 2 before I move to phase 3, or keep going? I have not
committed phase 2 yet — easier to fix things if you want changes first.


--------------------------------------------------------------------------------

### User Request 12

you know I wouldn't put you through this if you were human. This is what you are
designed for, it's what you're good at - humans are designed for the savannah,
they are not good at computer programming. It's better to optimize for
correctness, rather than ease.


let's keep going.


--------------------------------------------------------------------------------

### Assistant Response 12

You're right. Let me commit phase 2 and keep moving.


Phase 2 committed (`602b187c`). On to phase 3 — the soramech runtime.


Phase 3 done. Now phase 4 — SD card, FAT, the six filesystem boxes, the
compile pipeline, reference counts, hot-swap.


Phases 3 and 4 done. Committing both as one batch.


Phase 5 — input drivers as soramech maps with C leaf boxes for the hardware
reads.


Phase 6 — compositor, drawers, inter-app linkage.


Committing phase 5+6, then phase 7.


Phase 7 — radio, USB transport, rmail.


Phase 8 — the four apps. This is composition over earlier phases plus
app-specific UI and state.


Phase 7 and 8 done. Committing those, then phase 9 and phase 10.


Phase 9 — MMU protection and background lifecycle.


Phase 10 — the modeller.


All ten phases written. Committing phase 9 and 10.


All ten phases of issue files are written and committed. The shape of the work:


- **Phase 1** (13 issues): hardware bring-up, USB CDC-ACM debug, both screens lit

- **Phase 2** (11 issues): the threading core — multi-core, queues, gathering, ARM memory ordering

- **Phase 3** (11 issues): the soramech runtime — map representation, loader, encap splicer, routing dispatcher, RAM transcript

- **Phase 4** (12 issues): SD card, FAT, the six filesystem boxes with symlinks, compile pipeline, artifact tree, hot-swap

- **Phase 5** (8 issues): input drivers as soramech maps — buttons, sticks, touch, chord detector, radial menu, settings application

- **Phase 6** (11 issues): compositor, surfaces, damage tracking, per-screen foreground, drawers, inter-app linkage

- **Phase 7** (11 issues): WiFi IBSS, USB virtual ethernet, USB MSC inbox/outbox, transport abstraction, rmail port

- **Phase 8** (11 issues): the four launch apps — editor, programming environment, messenger, paint

- **Phase 9** (10 issues): MMU protection, per-app memory regions, fault recovery, per-app queues, the suppression bit, lifecycle states

- **Phase 10** (11 issues): the modeller — vertex grid, face formation, model save/load/merge with interior-detail policy


109 issue files plus 10 phase-progress indexes plus 13 docs. Six commits cover
the whole sweep. Every issue file follows the same shape — current behavior,
intended behavior, suggested implementation steps as stubs/names, related
documents, dependency edges — and the cross-references between issues form a
connected graph rooted in phase 1.


The next step you named was pseudo-code, then real code. Pseudo-code is going to
be substantially more work than the issues — each issue's "suggested
implementation steps" becomes one or two screens of structured pseudo-code in
the language of the project. Do you want to head straight into pseudo-code now,
take a break to read through the issues first, or take a different cut at this?


--------------------------------------------------------------------------------

### User Request 13

let's do pseudo-code. one issue at a time, please. we can make a new directory
psrc that has the pseudo-code - but we should treat them as CONSUMABLE, meaning
they are to be deleted when the actual SRC is written.


--------------------------------------------------------------------------------

### Assistant Response 13

Creating `psrc/` and starting with issue 101.


Issue 101 pseudo-coded. The bulk is the research note skeleton (mostly prose to
be filled in with the device in hand) and the `check-recovery-mode.sh` script
that probes for whichever chip-specific recovery tool sees the device. The
script is the only real software 101 produces; everything else is structured
note-taking the developer fills in from datasheets.


Read it over — is this the right shape and density for the pseudo-code phase?
If yes, I move to 102 (cross-compilation toolchain). If you want denser, looser,
more prose, less prose, or a different file format, tell me now before the
pattern propagates across 108 more files.


--------------------------------------------------------------------------------

### User Request 14

There's too much code in the pseudo-code! It has to be written in english.


--------------------------------------------------------------------------------

### Assistant Response 14

Right — pseudo-code in english. Rewriting 101.


Rewritten 101 in english. The "logic" of the script is now described in prose
— what each step does, in what order, what each probe looks for in the tool's
output — without showing actual shell syntax. The note's section list stays as
a bulleted breakdown of what each section needs to contain. The script's
algorithm becomes a numbered narrative of what happens when it runs.


Is this the right shape now? If yes, I move to 102.


--------------------------------------------------------------------------------

### User Request 15

hmmmm, too much structure. How lean can you make it? we might skip pseudo-code
going forward if we can't find a decent shape.


--------------------------------------------------------------------------------

### Assistant Response 15

Stripped to bare essentials — twelve lines. The note section is just one
sentence acknowledging it's hand-filled prose; the script gets two sentences
naming what it does and the order to probe.


Is this lean enough to be useful, or are we past the point where pseudo-code
earns its keep? For straightforward issues like 101 the lean form is basically a
tighter version of the issue's suggested-implementation-steps. The shape might
earn more weight on the dense issues (the gathering function, the routing
dispatcher, the MMU bring-up) where the implementation actually has structure
worth sketching before coding.


Worth a second try on a denser issue like 206 (the gathering primitive), or are
we calling pseudo-code off and going straight to source?


--------------------------------------------------------------------------------

### User Request 16

Heh that sucks. Affectionately.


let's skip pseudo-code. you can delete the psrc directory. Let's get to writing
actual code. Can you first give me a summary of the issue file, things that you
want the user specifically to read (me), then after review we can work on
implementation.


--------------------------------------------------------------------------------

### Assistant Response 16

Deleting `psrc/` and writing up the first issue for your review.


---


## Summary — Hardware specification research


This is the first issue in the project. It produces two things:


**A research note** about the device's silicon. The note is a markdown file under `notes/hardware/` that lists, chip by chip, what we found out about the device: which ARM CPU, how much RAM and where, the display controller's model and init sequence, the GPIO pin for every button and LED, the touch controllers and their I2C addresses, the WiFi chip and whether it supports ad-hoc mode, the USB-C controller, the SD controller, the chip's ROM recovery mode and which button triggers it, the existing bootloader on the SD card, and an explicit list of every gap we couldn't fill from datasheets. The note is filled in by hand while the device is in front of you with the datasheets open — there's no code to write, only research to do and record.


**A recovery-mode verification script.** A small bash script that proves the chip's ROM recovery mode is reachable from outside the closed case. The script prompts you to put the device in recovery, then asks each recovery tool we might have installed (Rockchip's, Allwinner's, Amlogic's) whether it sees a device, and reports the first one that does. If none of them does, recovery isn't reachable and the rest of the project's flashing plan has to be reconsidered.


The reason this script matters more than it looks: every later phase that
touches the bootloader can soft-brick the device. The recovery-mode path is the
safety net beneath every flash. The safety document is explicit that confirming
this path works is the highest-priority research item — higher than the chip
details themselves.


## What to read before we implement


Two files, in this order:


1. **The hardware specification research issue itself** —
`issues/101-hardware-specification-research.md`. Skim the "Intended behavior"
and "Suggested implementation steps" sections so you know what shape the
deliverables take.


2. **The bricking and recovery safety note** —
`notes/safety/000-bricking-and-recovery.md`. Especially the section called "The
Maskrom access question" near the end. That section names the three possible
paths to chip recovery from outside the case and explains why this script is the
gate everything else depends on.


If you want a wider context pass: the architecture overview
(`docs/001-architecture-overview.md`) and the phase 1 progress doc
(`issues/phase-1-progress.md`) are short reads that explain how this issue sits
in the larger picture, but neither is strictly required to evaluate this one.


---


After your review, the only code we actually write for this issue is the bash
script. The research note's contents come from the device-in-hand work, which I
can structure as a fillable skeleton but cannot author for you. Tell me when
you've read the two files and we'll start on the script.


--------------------------------------------------------------------------------
