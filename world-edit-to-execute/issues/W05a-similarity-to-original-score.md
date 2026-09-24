# Issue W05a: Similarity-to-Original Score

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W05
**Priority:** High (the forge's progress measure)
**Dependencies:** W03 (renders models from fixed cameras)

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
| Silhouette | Render both from a fixed ring of cameras (8 around, 1 above, 1 in front at eye height); per view, 1 − intersection-over-union of the two filled outlines; averaged | float 0-1 |
| Surface shape | Sample points on each surface (e.g. 10,000); symmetric nearest-point (Chamfer) distance, divided by model height | float, ≥ 0, clamped to 0-1 |
| Colour | Per view, distance between colour histograms of the two renders | float 0-1 |
| Overall look | Per view, cosine distance between image-embedding vectors from a vision model (e.g. DINOv2 or CLIP), which responds to style and detail the other measures miss | float 0-1 |
| **Combined** | Weighted sum; weights kept in a data file | float 0-1 |

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

The threshold that counts as "sufficiently distinct" is a setting, not a
constant in code. The engine's replacement-progress statistic (W03) counts a
model as replaced only above it.

**Limit, stated plainly:** this is an engineering measure of distance, not a
legal test of whether something is a derivative work. A model made by feeding
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

1. What threshold is "sufficiently distinct"? Suggest deciding after scoring a few hand-picked examples the owner judges by eye.
2. Should the score also compare textures on their own (unwrapped), or only as rendered?

## Related Documents

- `issues/W05-asset-forge-find-or-generate-a-replacement-model.md`
- `docs/datapath-asset-forge.md`, `docs/wow-client-bridge.md` (Decisions made)
