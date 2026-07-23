# 001 — Paired apply/unapply

**Shape.** Every divergence between two configurations is expressed as a
pair of functions: `apply` and `unapply`. Both are idempotent. A manifest
declares which pairs are active for which configuration. The
configuration is selected at one place; the manifest is consulted at one
place; the divergences themselves are isolated, named, and reversible.

**Origin in this project.** Borrowed from the patch-system shape in
`/home/ritz/games/azeroth-core/wow-chat-2026/patches/`. Adopted as the
nds-vs-native build strategy in `docs/004-architecture.md`.

**Where else it fits.**

- A/B testing of any kind: feature is on (apply) or off (unapply).
- Save-file migrations: every migration ships with a downgrade.
- Mod loading at runtime: every mod's `enable` has a `disable`.
- Database schema changes: every up migration has a down migration.

**Why it works.** A divergence that cannot be undone is a divergence that
metastasizes. Forcing the unapply at design time makes the divergence's
boundary visible. Forcing idempotency makes it safe to run on a confused
or partially-mutated state.

**Where it does not fit.** Things that genuinely cannot be undone (data
deletions, cryptographic key rotations, certain side effects to external
systems). For those, the strategem becomes "apply once with a verifiable
preimage so the previous state can be reconstructed if needed."
