# 904 — Distribution: a gift, "one copy to each european"

> **Phase:** 9 — Platform & Packaging
> **Role in phase:** decide how the finished artifact reaches people, in the
> vision's own spirit — **free, anti-commercial, a gift.** This issue is as much a
> preservation of voice as an engineering task; the framing is sacrosanct.
> **Blocked by (within phase):** 903 (there must be an artifact to give away).

## Current Behavior

None of this exists yet. There is no distribution story at all — no channel, no
copy-and-hand-on story, and no statement of the free/anti-commercial intent that
the vision insists on. Without this, an artifact from 903 would exist but have no
sanctioned way to reach "each european," and the project's socialist-utopia voice
would go unrecorded in the delivery layer.

## Intended Behavior

The artifact from issue 903 is distributed as a **gift**, faithful to the vision:

> then, make it run on an anbernic, and give one copy to each european.

Concretely, distribution bends every choice toward *giving away* and toward *the
next person being able to give it away too*:

- **No DRM, no store lock-in, no account, no network requirement.** The artifact
  is a plain thing anyone can copy onto a cheap SD card and hand to the next
  person. The last step of the datapath is a copy that costs nothing to make again.
- **Copy-and-pass-on friendly.** Because the artifact is self-contained (903b) and
  path-portable (903a), a recipient can re-give it without a rebuild. The intended
  flow is a chain of gifts, not downloads from a single owner.
- **A stated license/spirit note** carried with the artifact that says, in plain
  words, that it is free to copy, free to give, and not for sale — consistent with
  "there's no skynet in my socialist utopia" and "I'm not interested in product."
- **A "one copy to each european" reading** kept as intent, not as a literal
  logistics plan: the point is *universal, unpriced reach*, one copy per pair of
  hands, not a shipping manifest. Documented as spirit so nobody mistakes it for a
  fulfillment spec.

This issue deliberately holds the **voice** as a deliverable. Where the vision
speaks in its socialist-utopia register, this issue quotes it rather than
sanding it into corporate-release language.

## Suggested Implementation Steps

1. Write the **distribution note / license-of-spirit** that travels with the
   artifact: free to copy, free to give, not for sale — in the vision's plain,
   generous voice.
2. Confirm the artifact carries **no DRM / no lock-in / no network requirement**;
   if any prior packaging step introduced one, file it back to 903 as a defect
   (a lock-in would be a silent contradiction of the gift, so surface it loudly).
3. Describe the **copy-and-pass-on chain**: how a recipient re-gives the artifact
   without a rebuild (leaning on 903a portability + 903b self-containment).
4. Record the **"one copy to each european" framing** as *intent* (universal
   unpriced reach), explicitly not as a logistics plan.
5. Keep the vision's relevant lines quoted verbatim so the voice is preserved in
   the delivery layer, not paraphrased away.

## Stats / Meta

- **Kind:** distribution + preservation of voice.
- **Commercial?** No — explicitly anti-commercial, by vision.
- **Dependency:** needs an artifact (903) to give away.

## Related Documents / Tools

- [datapath-platform-packaging.md](../docs/datapath-platform-packaging.md) — "The
  spirit of delivery — a gift, not a product."
- [notes/vision](../notes/vision) — the source of the voice; sacrosanct.
- [vision-overview.md](../docs/vision-overview.md) — the socialist-utopia framing
  and "I'm not interested in product."
- Issue **903** — produces the artifact being given away.
