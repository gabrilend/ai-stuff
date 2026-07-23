# Filesystem Tapestry — Roadmap

Phases are **clusters of functionality**, not a schedule. A lower phase is more
foundational; higher phases build on what is below them. It is entirely normal
for the last issue completed on the project to belong to Phase 1.

For live counts of what is built versus planned, run the validator rather than
trusting numbers written here (numbers written in prose go stale):

    scripts/validate.sh --stats

---

## Phase 1 — The Thread (catalog + chronology + the walk)

The runnable spine. After Phase 1 you can scan the data drives, get a catalog of
creation/modification dates for every file, walk it in chronological order, and
open the file under the cursor in the correct program.

- **1-001 — Catalog builder.** Walk one root, record path, birth time, modified
  time, size, and media kind for every file. One process per root (roots are
  independent, so the walk is parallel).
- **1-002 — Shared exclusion matcher.** Read the unified `.gitignore` from
  delta-version at runtime and turn it into a fast path matcher. Excluded files
  are still catalogued (flagged), but skipped by the walk.
- **1-003 — Catalog store & merge.** Merge the per-root shards into one catalog;
  load it back for viewing. Generation and viewing never share code.
- **1-004 — Ordering engine (chronological).** Produce an ordered index of the
  catalog by birth time or modified time, ascending or descending.
- **1-005 — Media dispatch table.** Map a file's kind to a viewer program
  (mpv / neovim / feh / zathura) via a dispatch table, with a flagged fallback.
- **1-006 — Navigator.** A cursor over an ordering. `next`, `previous`, `open`,
  and switching the active ordering. Reads input/ on startup, writes output/ on
  goodbye.

## Phase 2 — The Meaning (policies + embeddings + similar/different)

Similarity cannot be read off the bytes of a video. It is read off a **policy
description** — a short text per file describing what the file is and what should
be done with its contents, authored by a user, sourced by a user, or
auto-generated. Phase 2 makes similar/different real.

- **2-001 — Policy store.** Attach, load, and save a policy text per file (or per
  group). Human-written, user-sourced, or auto-generated provenance is recorded.
- **2-002 — Policy embeddings.** Embed policy texts with Ollama (the same
  integration neocities uses) into vectors.
- **2-003 — Similarity matrix.** All-pairs cosine over policy embeddings, stored
  sparsely (top-K neighbours per file).
- **2-004 — Ordering engine (similar).** Nearest-neighbour ordering from a seed.
- **2-005 — Ordering engine (different).** Greedy diversity chain — reuse the
  least-similar-unvisited algorithm from neocities `diversity-chaining.lua`.
- **2-006 — Auto-policy generator.** Draft policy descriptions for files that
  lack one, so the tapestry is navigable before every file is hand-annotated.

## Phase 3 — The Loom (surfacing & polish)

- **3-001 — Static HTML tapestry view.** Browsable pages (chronological / similar
  / different) in the shared documentation style, like the neocities output.
- **3-002 — Incremental re-scan.** Only re-walk what changed since the last scan.
- **3-003 — Cross-drive dedup view.** Find the same content on multiple drives by
  birth time + size + policy.

---

## Design invariants (true across all phases)

- **Generation and viewing are isolated halves.** A bug in the walk cannot reach
  the navigator, and vice versa.
- **Chronology is measured in seconds; similarity is measured on policy text.**
  Never attempt to embed file bytes.
- **Exclusions come from the shared unified `.gitignore`, at runtime.** We do not
  keep our own copy of "what to ignore."
- **Excluded ≠ forgotten.** Excluded paths stay in the chronological catalog.
- **Every dispatch is a table, never an if-else ladder.**
- **Fallbacks are warnings.** Any time the tool falls back (birth time missing →
  use modified time; no viewer for a kind → xdg-open; no policies yet → order by
  chronology), it says so out loud.
