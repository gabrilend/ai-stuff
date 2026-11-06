# Conversation Summary: 31e0832c-1d86-4f24-b966-2f12876bf0c4

Generated on: 2026-11-06 00:02:52
Models: claude-opus-5-5

--------------------------------------------------------------------------------

### User Request 1

hi can you review the open pull requests?

--------------------------------------------------------------------------------

### Assistant Response 1

> **[Asked the user]**
>
> *Q1 — PR scope:* There are 321 open pull requests (all drafts) across many
> projects. Reviewing all of them properly would take hundreds of separate
> reviews. Which group should I start with?
> - World-edit (49) (Recommended) — The newest batch, all from today:
>   matchmaking (801a–h), camera, minimap, interface layout, model overrides,
>   validator. Many build on each other, so reviewing them together catches
>   mismatches between them.
> - Guide-feature (36) — The guide project's phases 5–8: distill mode,
>   terminal view, Lua window, HTML page, phase demos.
> - Soren-ds (29) — The handheld's radial-menu chord, handedness and drawer
>   swap, and earlier work.
> - Newest 10 only — A quick pass over the ten most recent, whatever project
>   they belong to.
> → **Selected:** World-edit (49) (Recommended)

20 of 49 world-edit reviews are done, and the review of #312 is still running.
Next I'm starting on the older chain of map-converter pull requests, #238 to
#265.

--------------------------------------------------------------------------------

### User Request 2

[Usage limit reached; a short grace allowance remains, then this turn is cut off
without warning. Judge what's left: if it's genuinely only a few steps, finish
it properly, then stop and say so without extra polishing. Otherwise don't
attempt it all: finish the piece in hand and at most two more like it, then
stop. The allowance also pays for any subagents you have running: they don't get
this message and will keep going, so it's up to you how to handle them. Either
way, end by telling the user their usage limit was reached, what's done and
what's left.]

--------------------------------------------------------------------------------

*You've hit your session limit · resets 11:20pm (America/Los_Angeles)*

--------------------------------------------------------------------------------

### User Request 3

Your claude.ai usage limit has reset. Continue the task you were working on when
the limit was reached; do not repeat work that is already complete.

--------------------------------------------------------------------------------

### User Request 4

[Earlier usage-limit notes no longer apply. Continue working normally. Don't
mention this to the user.]

--------------------------------------------------------------------------------

*You've hit your session limit · resets 11:20pm (America/Los_Angeles)*

--------------------------------------------------------------------------------

### User Request 5

Your claude.ai usage limit has reset. Continue the task you were working on when
the limit was reached; do not repeat work that is already complete.

--------------------------------------------------------------------------------

*You've hit your session limit · resets 11:20pm (America/Los_Angeles)*

--------------------------------------------------------------------------------

### User Request 6

Your claude.ai usage limit has reset. Continue the task you were working on when
the limit was reached; do not repeat work that is already complete.

--------------------------------------------------------------------------------

*You've hit your session limit · resets 11:20pm (America/Los_Angeles)*

--------------------------------------------------------------------------------

### User Request 7

please continue

--------------------------------------------------------------------------------

### Assistant Response 7

> Rerunning the three reviews the usage limit cut short: #246, #239 and #238.

47 of 48 reviews are done. #238 is still running, and I'll write up all the
findings together once it finishes. I'm skipping #262 because it only merges
branches that are already reviewed individually.

--------------------------------------------------------------------------------

*[background task] Agent "/code-review https://github.com/gabrilend/ai-stuf…"
finished —
[code-review-https-github-com-gabrilend-ai-stuf-nov-5-26-through-nov-6-26.md](code-review-https-github-com-gabrilend-ai-stuf-nov-5-26-through-nov-6-26.md)*

--------------------------------------------------------------------------------

### Assistant Response 7 (continued)

I reviewed 48 of the 49 open world-edit pull requests, all except #262, which
only merges branches that are reviewed one by one here. Each review returned
about 10 findings, so there are close to 480 in all. Most reviews come from
reading the code. The ones marked *(confirmed)* were reproduced by running the
code on the pull request's branch. One finding is still a guess (#240), and I
have a question about it at the end.

## The most serious problems

- **A downloaded map can write files anywhere on your machine (#250, #242).**
  The converter copies a map's own model files into the build folder using the
  name stored inside the map. Names containing `..` are never refused, so a map
  file named `..\..\..\.bashrc` lands outside the build folder.
- **The matchmaking server can be crashed from outside.**
  - **#305:** a game list too big for one message crashes it, and so does a
    client that disconnects in the instant it is accepted.
  - **#310:** a pack file of 4 GiB or more crashes it.
  - Nothing catches errors in the server's main loop, so any one of these ends
    the whole process.
- **The wrong program can be killed (#311, #253).** Signals are sent to a
  process number saved in a file. If the server died and the operating system
  handed that number to another program, the signal goes there instead. A
  "reload" signal ends most programs, and the server keeper also sends terminate
  and kill signals.
- **The map's trigger runner on the server goes quiet (#244, #245).**
  - One error inside the region check stops all "unit enters region" and death
    events for the rest of the game *(confirmed)*.
  - A region filter that raises an error is treated as "yes, let this unit
    through" *(confirmed)*.
  - Blizzard's "destroy this group afterwards" flag is never cleared, so the
    next group loop destroys an unrelated group *(confirmed)*.
- **Undo after a save writes wrong ground (#256, #257).** Painted texture layers
  stay in the file after they are undone. A new texture can point at the wrong
  texture name. Water depths come back measured from the old ground.
- **The editor freezes.**
  - **#313:** building a tooltip on a very narrow window loops forever
    *(confirmed)*.
  - **#257:** every single height edit copies the whole far-view (WDL) file,
    which adds up to gigabytes of copying per tile on a stock-sized map.

## The same problems across many pull requests

- **Several maps in one build folder don't really work (#242, #243, #246, #247,
  #250, #264, #265).**
  - The server's creature file and the root ground and info files hold only the
    last map converted.
  - Two maps open at once can be given the same explored-zone bit.
  - The server's fingerprint file isn't rewritten when areas change, so Test Map
    keeps a server that never loads them.
- **Silent fallbacks.** Missing values quietly become 0, defaults or "no file"
  in about 30 of the pull requests, against your rule that a fallback counts as
  an error.
- **Issue files written as work logs.** About 15 pull requests add a dated note
  to the end of the issue instead of rewriting its "current behavior" section.
  Several also write test counts into the text, which go stale.
- **Issues moved to completed while work or questions are still open:** #323,
  #305, #256 and #238.
- **The same helper copied by hand into many files:**
  - the function that quotes text for the shell
  - the function that lists a folder
  - the function that writes data out as Lua
  - three separate JSON writers
  - four copies of the code that loads the W client's file-reading library
- **House rules broken in most pull requests:** missing one-fold-per-function
  markers, missing `.info.md` companion files, and long if/else chains where
  your rules ask for a lookup table.

## One worst finding per pull request

| PR | Worst finding |
|---|---|
| 324 | A test run on its own still quietly uses the fixed old project path, so it can pass against the wrong copy. |
| 323 | Files a protected map stores twice are counted twice, which inflates the report's numbers. |
| 322 | A note says ships float on the water, but near a shore one dry corner reads the water as far below the ground. |
| 321 | The issue's own body still says "ten messages" and "38-byte" unit records. |
| 320 | An unknown ping style still shows a red ping, which the real game would ignore. |
| 319 | A set name containing a line break slips extra overrides into the shared file *(confirmed)*. |
| 318 | Models a map sets keep their `.mdx` ending and stock models don't, so one of the two kinds will miss every lookup. |
| 317 | Items a map defines itself and places on the ground fail as "wrong type", and real runs never use the new lookup. |
| 316 | A view box that only touches the minimap's edge from outside draws a stray line *(confirmed)*. |
| 315 | With edge scrolling on and no screen size given, the camera drifts right and down forever. |
| 314 | A zero-height window gives a "found" ground point with no real coordinates *(confirmed)*. At full zoom-out the view box is about 23 tiles too far north *(confirmed)*. |
| 313 | The tooltip freeze above *(confirmed)*. A button disabled while held down still clicks when released *(confirmed)*. |
| 312 | The test starts a real server with no time limit, so a failed run leaves it running forever. |
| 311 | The process-number reuse problem above. |
| 310 | The 4 GiB crash above. A new message type without a version bump also disconnects older clients. |
| 309 | An older server reads a kick as the host leaving and closes the whole lobby. |
| 308 | A machine with no NAT is never reported as "open" when it listens on all addresses. |
| 307 | The headless checksum depends on the order slots were freed and reused, so the same scene can give different numbers. |
| 306 | A timed-out lobby request leaves the server holding the connection in a lobby the client has forgotten. |
| 305 | The server crashes above. |
| 304 | Whole numbers just past 2^53 are rounded instead of refused *(confirmed)*. Ports above 65535 pass the check. |
| 265 | Two maps can share one explored-zone bit, and a failed rebuild is never tried again. |
| 264 | The fingerprint file isn't rewritten, so Test Map keeps a server that never loads the new areas. |
| 263 | Four tables share one list of read columns, so editing one quietly edits all four. |
| 261 | At the default brush size, the area brush usually changes nothing but still records an undo step. |
| 260 | If the W client's lighting code fails to build, its checks are skipped and the test still passes. |
| 259 | A tile removed and then re-added reads the old file's objects and blocks every object edit. Turned buildings get unturned bounding boxes. |
| 258 | One tile that the map's tile list (the WDT file) names but whose file is missing blocks every add, remove and nearby brush stroke. |
| 257 | The water-depth redo and WDL copying problems above. |
| 256 | The undo-after-save problems above. |
| 255 | Adding a map from the project's own folder deletes it before copying it, then reports success. |
| 254 | Walls from the pathing map exist on the client only. The server's navigation ignores them. |
| 253 | A second editor can start a server on the same ports and overwrite the first editor's record. |
| 252 | A pathing file that fails to unpack is treated as "this map has none", with no warning. |
| 251 | The "old stamp removed" test can never fail. Reusing a server ignores which build folder it was started on. |
| 250 | The `..` path problem above. A "no map" answer is also remembered forever. |
| 249 | If the W client setting includes an extra option word, the client's folder isn't passed, so your default client runs instead. |
| 248 | Unknown file versions are read with a guessed layout, and missing new fields are written as zeros. |
| 247 | One root info file is shared by every map in the build folder. |
| 246 | The ground file is copied from the map archive, not made from the terrain that was actually converted. |
| 245 | The group-flag leak above *(confirmed)*. Deaths from before a death trigger existed fire later *(confirmed)*. |
| 244 | The region-check and filter problems above *(confirmed)*. |
| 243 | Positions are saved with 6 significant digits, so spawns can be up to 0.04 yards off. |
| 242 | The `..` problem, neutral players misassigned on the 24-player map, and most stock items spawned as creatures. |
| 241 | The report's timestamp changes every run, so the server restarts on every F5. |
| 240 | Texture blend strengths may be written for the wrong mixing rule *(unconfirmed)*. A failed build leaves half a folder plus the old report. |
| 239 | An empty table in the settings file wipes the defaults and crashes F5. A typo in that file silently falls back to the defaults. |
| 238 | The model exporter has its own triangle loop that still writes out-of-range corner numbers. |

## Things to know

- **A stray review of uncommitted work.** The first run for #318 mistook its
  target and reviewed your uncommitted neocities-modernization changes instead.
  Nothing was changed. It did find one privacy problem: taking a picture off the
  approved list deletes the local copy, but the copy already published in
  `output/media/` stays on the site.
- **A leftover git ref.** The #321 review left a temporary reference named
  `refs/pr321` in the repository. I haven't deleted it.
- **Nothing posted.** I haven't put any of this on the pull requests. I can post
  each review as comments on its pull request, or publish all 48 as one private
  page.

One question, about #240: when the W client draws ground with three or four
textures, does it lay each one over the last in order, or does it add their
strengths together? The converter assumes the first. If the client adds them,
any chunk where three textures meet comes out with the wrong colours, and the
tests can't catch it because they compare the written bytes, not the drawn
picture.

--------------------------------------------------------------------------------

