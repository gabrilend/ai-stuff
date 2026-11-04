# 005 — Datapath: the picture

How an analogy record becomes a PNG on the reader's screen, holding exactly the
right number of things.

```
analogy record
  └─ "what this quantity shows" cache ── hit (and no middle-click) ──► redisplay
       └─ layout: count + frame size + packing ──► one cell per object
            └─ scene cache (by setting, cells, generation settings) ── hit ──► picture
                 └─ miss: build a ComfyUI graph — the setting for the whole
                    frame, one area prompt per cell        (graph writer, reused)
                      └─ POST /prompt to ComfyUI (192.168.0.88:8188) ──► prompt id
                           └─ poll /history until done
                                └─ GET /view for the image ──► picture bytes
                                     └─ store in both caches
                                          └─ host ──► bridge ──► panel
```

## Every one in its place

Image models cannot count. Asked for "eleven sacks" they draw nine or fourteen.
So the number never reaches the image model as a number. The host divides the
frame into cells — a grid for boxes and vehicles, a hexagonal packing for round
or piled things — and each cell gets its own prompt for *one* object, pinned to
that rectangle with ComfyUI's core `ConditioningSetArea` node. The cells and
the background setting are joined with `ConditioningCombine` and sampled
together. Eleven cells, eleven sacks.

**Fractions hang off the edge.** 11.2 sacks is eleven whole cells and one cell
that crosses the frame's edge so only a fifth of a sack shows: "half of a
*whatever*, sticking off the page". Leftover cells at the end of the last row
are left empty.

**The ceiling.** A cell smaller than a minimum size cannot hold a recognisable
object. Measured quantities past the ceiling are offered a larger reference
object instead; bare counts past it are drawn in groups ("a crate of 100
marbles" per cell), and the sentence says so.

If area prompts prove unable to hold one object per cell, the alternative is to
draw one object once and paste copies into the cells (core
`ImageCompositeMasked`): exact by construction, but visibly pasted. The phase 4
demo's count column decides between them.

## The graph

The project does not hand write graph JSON. The kanji project's graph writer
(`kanji-learning-image-generator/src/028-the-shape-of-a-graph.lua`) knows every
socket of every node it uses, in slot order, and refuses to wire a socket it
does not know. This project loads it the way `world-edit-to-execute` does.

The checkpoint name, frame size, step count and server address live in the
settings file. They are installation facts, not design. Checkpoints on the
server as of 2026-10-04: `Chroma1-HD`, `NetaYume_v4_all_in_one`,
`juggernautXL_ragnarokBy`, `waiIllustriousSDXL` v10/v160/v170.

## Two caches

- **What each quantity is showing** — keyed by page address, paragraph text and
  the quantity's position. Hovering again redisplays it; only a middle-click
  replaces it.
- **Pictures by scene** — keyed by a checksum of the setting, the cells, the
  checkpoint, size, steps, sampler and seed. The same scene is drawn once.

Both live in RAM (`tmp/shared-memory/pictures/`) by default, or on disk in a
folder named in the settings, chosen by one setting reachable from the
Extensions menu. The reader can also save any recent picture to a place of
their choosing through Firefox's downloads.

## Leaving before it is done

A picture takes seconds. What happens when the pointer leaves before it
arrives — finish it so it is cached for next time, or cancel it so the server
is free — is an [open question](008-open-questions.md). ComfyUI can drop a
waiting prompt (`POST /queue` with a delete list) or interrupt a running one
(`POST /interrupt`).
