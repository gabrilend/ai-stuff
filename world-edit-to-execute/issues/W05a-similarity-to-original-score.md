# Issue W05a: Similarity-to-Original Score

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W05
**Priority:** High (the forge's progress measure)
**Dependencies:** W03 (renders models from fixed cameras)
**Blocks:** W05c, W05d

---

## Current Behavior

Nothing measures how close a replacement model is to the Blizzard model it
replaces. "Replaced" would currently mean "a new file exists", even if the new
file is a near-copy.

## Intended Behavior

In the owner's words: "we should just try and have a 'similarity score' that
rates the distance from the original model, and we should try to improve our
artwork bit-by-bit until it's sufficiently distinct."

For any candidate and its original, the scorer produces one number between
0.0 (identical) and 1.0 (unrelated) and the parts it was built from. Every
score is kept, so each model has a history showing its distance growing as the
artwork is reworked.

What it measures, all computed on the candidate and original after both are
scaled to the same height and posed in the same frame of the same animation:

| Part | How it is measured | Data type |
|------|--------------------|-----------|
| Silhouette | Render both from the scoring camera ring (below); per view, 1 − intersection-over-union of the two filled outlines; averaged | float 0-1 |
| Surface shape | Sample points on each surface (e.g. 10,000); symmetric nearest-point (Chamfer) distance, divided by model height | float, ≥ 0, clamped to 0-1 |
| Overall look, by region | Per view, the picture is cut into labelled regions (below); each region's image-embedding vector, from a vision model such as DINOv2 or CLIP, is compared with the matching region of the original's picture by cosine distance | float 0-1 per region; averaged per view |
| Colour (optional) | Per view, distance between colour histograms of the two renders. Off by default: the owner (2026-10-01) doesn't think colour palettes are copyrighted, but it may be switched on to help a well-liked design over a final hurdle. Generated models carry colour slots (below), so recolouring is cheap | float 0-1 |
| **Combined** | Weighted sum; weights kept in a data file (colour's weight is 0 unless switched on) | float 0-1 |

**The scoring camera ring: 26 views** (owner, 2026-10-01: "We must be
thorough"). 8 cameras around the model at each of 3 heights (24), or at 5
heights (40), plus one straight above and one straight below: 26 views
with 3 heights, 42 with 5. Each view is its own pass through the
rendering pipeline. The number of heights is part of the camera ring
version kept in each score record.

**Photographed in scenic places, in the engine** (owner, 2026-10-01).
Besides the plain studio frame, both models are teleported to a few scenic
vistas and photographed there, so the comparison also sees them in light,
shadow and against backgrounds the way a player would. The capture is
in-engine rendering, not a separate tool. When the server starts up, it
goes through the list of every model that needs a photoshoot (new
candidates, and originals not yet photographed with the current camera
ring) before players are allowed in. The game server itself draws
nothing, so a copy of the custom client, drawing off screen, takes the
pictures while logins wait: the server spins up that client itself and
poses each model at each vista and camera (owner, 2026-10-01).

**Region overlays: where the likeness is** (owner, 2026-10-01: "make sure
we mark which parts are most similar"). The scorer's output for each view
includes a collection of regions as an overlay that can be laid over the
picture. Each region holds:

- its outline in the picture (list of points, x and y as floats 0-1 of
  the picture's width and height)
- what it covers, in words (string, e.g. "left pauldron", "helmet crest")
- its similarity score against the matching region of the original's
  picture (float 0-1). The matching region is found by what it covers,
  not by position: its boundary in the original's picture need not be the
  same shape.

A region with no match in the original is kept, with no score and marked
unmatched (a part the original doesn't have).

**How regions are found** (owner, 2026-10-01): an image-recognition model
is told to break each picture into the pieces of equipment, and each piece
into its parts. Fine parts are welcome ("leather strap" as its own part of
the chestpiece). Each part points to the piece it belongs to, so a region
record also holds:

- its parent (region id string, or none for a whole piece: "leather strap"
  points to "chestpiece")

A part is scored against the matching part of the original, and its
parent piece is scored as a whole as well, so a likeness shows both where
it sits and what it belongs to.

**Colour slots, like WC3 team colour** (owner, 2026-10-01: "we could
mix-and-match the colors later on as we go"). In WC3 a unit's texture has
areas marked to take the player's colour: the material has a layer that is
the plain team colour, and the texture's transparency decides where that
layer shows through. Generated models are built the same way: besides its
painted texture, each model carries a mask that marks areas as colour
slot 1, 2, 3 and so on, and a palette (list of colours, each three bytes
red, green, blue) fills the slots when it is drawn. Recolouring a model is
then swapping a palette, not regenerating it. Mask format: one 8-bit
channel per slot, same size as the texture, 0 = the painted texture shows,
255 = the slot's colour shows.

**Where the vistas come from** (owner, 2026-10-01): found while playing.
The owner saves a scenic spot (map, position, facing, time of day) with a
chat command, not yet built; the startup photoshoot uses every saved
vista.

A score record holds: candidate id (SHA-256 string), original model path
(string), each part (float), combined (float), weights file hash (string),
camera ring version (uint), time, and the candidate's **lineage** (`derived`
or `independent`, copied from its provenance record so every score is read
beside how the asset was made).

**Every asset kind, not only models** (decided 2026-09-23: animations,
particle effects, textures and the rest are replaced over time too). Models
are built first; the others use the same record and threshold idea with
their own measures:

| Asset kind | Measure |
|------------|---------|
| Texture | image-embedding distance, structural similarity, colour histograms |
| Animation | joint-angle curves per bone, compared after time alignment (dynamic time warping) |
| Particle effect | rendered frame sequences compared as in W04 |
| Sound | spectral and audio-embedding distance |
| Font / interface art | outline overlap plus embedding distance |

The table is kept in step with the W client's
`docs/012-asset-replacement-and-provenance.md`.

**One pipeline, routes as parameter sets** (owner, 2026-10-01: "we should
have one pipeline that is configured with separate parameters"). The forge
and this score are shared by every route; a route is a named set of
settings, not a separate program. The setting that differs most:

| Setting | Data type | Clean-room route (W05d) | Generation route (seed, vote, select) |
|---------|-----------|-------------------------|----------------------------------------|
| score shown to the builder | bool | false | false |
| score used to pick next round's seeds | bool | false | true: seeds are the candidates best on votes and distance together |
| votes used to pick next round's seeds | bool | true | true |
| original used as input | bool | false (described in words only) | true (the seed) |
| gate threshold | float 0-1 | the shared setting | the shared setting |

In both routes the score is a **gate**: it decides whether a finished
candidate is distinct enough. It is never shown to whatever builds a
candidate, because a builder told where it is too close looks at the
original to fix it (see W05d, "Why the loop never uses similarity as its
guide"). The generation route may still *select* by it: keeping the
least-similar of the well-liked candidates as next round's seeds steers
away from the original without the builder ever seeing a number. The
clean-room route picks its seeds by the players' votes alone.

**Why two routes through one pipeline** (owner, 2026-10-01, verbatim):

> The goal is to show that clean-room routes and seed-based generation
> routes produce outputs that are if not identical, then comparably
> distinct, proving that the destination is what matters, not the route to
> reach it.
>
> "if not identical" because two painters tasked with drawing a bowl of
> fruit will produce two separate paintings, and "comparably distinct"
> because one who was shown the bowl of fruit and one who was told
> "there's an apple on the left side, a banana stuck into the part between
> a melon on the bottom and a bunch of grapes along the top,,, " etc will
> produce two paintings that are both comparably distinct from a
> photograph of the fruitbowl.

So the two routes are an experiment with a measured result: run both on
the same original, score each route's accepted models against it with
this same score, and compare the two distributions of scores. The claim
holds when the seeded route's accepted models are no closer to the
original than the clean-room route's. A per-original report (two lists of
combined scores, float 0-1, one per route, and their medians) is the
evidence, kept beside the score records.

The threshold that counts as "sufficiently distinct" is a setting, not a
constant in code. The engine's replacement-progress statistic (W03) counts a
model as replaced only above it.

**What the score is for** (owner, 2026-10-01). Generation plus this
comparison is the route the system means to prove worthy of legality; the
clean-room loop (W05d) is a possibility players may use, not a
requirement. In the owner's words: "This system is intended to push the
boundaries of copyright law, in order to better define, secure, and
represent the place that AI generated words, images, and artwork in
general has in our economy, civic society, and legal system. We want to
remain maximally compliant, and explain exactly how to create everything,
with an emphasis on the fact that the end result could be
indistinguishable from a 'clean room' created project, and thus certain
restrictions would be unenforcable."

And on why the original is the input, not something to hide (owner,
2026-10-01, verbatim):

> the goal is to show that using someone else's work as a kernel, a seed,
> you can grow into something completely different. This reflects that
> image diffusion models take other creative works as "kernels" or "seeds"
> and adjusts their models to produce output that is inspired by them. In
> the same way, we take the Blizzard artwork from the hit popular video
> game World of Warcraft: The Wrath of the Lich King Arthas and we
> "diffuse" new models and animations and whatever else we get to. We
> "diffuse" them through the eyes of the viewers, encouraging them to
> choose high quality outputs while we pick the intersection of "highest
> quality" and "least similar" again and again until we find ourself
> distinct and reflective of our own creative potential. Similar to how an
> image generation system will be trained through patterns inherent in the
> nature of artwork, so too will we create patterns that train and provide
> inheritance to the future examples of artwork. We are attempting to turn
> Azeroth into a medium, a canvas, and we shall provide the paintbrush, and
> tell you how to build your own if you'd like.

So the records proving the original was the seed are the point, not a
weakness: they show the path from seed to something distinct. Each round
keeps the candidates where the gallery's votes (quality) and this score
(distance) are best together, and those seed the next round.

What needs a score: only what is
pulled directly from the game and then used as an input to an AI process.

The same pipeline serves Everland Ghostsong's generated models (its issue
506): they pass this score as well as its gallery's votes.

**Limit, stated plainly:** this is an engineering measure of distance, not a
legal test of whether something is a derivative work. No statute or court
gives a percentage (see open question 1). A model made by feeding
a render of the Blizzard original into image-to-3D starts from the original by
construction, and it may keep recognisable design features even at a high
score. Candidates generated from text or from the owner's own concept art
start further away. The score shows how far each route gets.

## Suggested Implementation Steps

1. Fixed camera ring and pose, rendered offscreen by W03's renderer into `tmp/shared-memory/`.
2. Silhouette and colour parts (plain image arithmetic).
3. Surface-point sampling and Chamfer distance (thread pool; one model pair per task).
4. Embedding part behind a small interface so the vision model can be swapped.
5. Score records stored beside candidates (W05 keep step); a per-model history chart on the gallery page.
6. Tests: a model scored against itself gives 0.0; the model mirrored or recoloured gives a small but non-zero score; two unrelated models score high.

## Acceptance Criteria

- [ ] The self, mirror/recolour and unrelated tests pass
- [ ] Every stored candidate has a score record
- [ ] The gallery shows each model's score history
- [ ] The threshold is a setting and drives the replacement-progress count

## Open Questions

1. What threshold is "sufficiently distinct"? The owner asked (2026-10-01) whether the law defines one. It doesn't: in the United States, infringement is judged by "substantial similarity", a judgment made by an ordinary observer or by comparing protected elements, never by a percentage; the "change 30%" rule is a myth. Copying a small but central part can infringe. So the number is ours to choose; suggest deciding after scoring a few hand-picked examples the owner judges by eye.
2. Should the score also compare textures on their own (unwrapped), or only as rendered?
3. ~~Which machine renders the startup photoshoot?~~ Answered 2026-10-01: "the server will spin up a client and pose them appropriately": at startup the game server launches a copy of the custom client on its own machine, places each model at each vista and camera, and has it take the pictures before logins open. Vistas: every one the owner saves while playing. The work is models × (26 or 42 views) × (1 + vistas).
4. ~~How are regions found?~~ Answered 2026-10-01: image recognition breaks each picture into equipment pieces and their parts, each part pointing to its piece (above).
5. ~~Is proving access the intended stance?~~ Answered 2026-10-01: yes; the original is the seed on purpose (the owner's words above).
6. ~~Is the score now a guide after all?~~ Answered 2026-10-01: "we should have one pipeline that is configured with separate parameters." One forge, one score; each route is a parameter set, and whether the score may steer is one of its parameters (below).

## Related Documents

- `issues/W05-asset-forge-find-or-generate-a-replacement-model.md`
- `docs/datapath-asset-forge.md`, `docs/wow-client-bridge.md` (Decisions made)
