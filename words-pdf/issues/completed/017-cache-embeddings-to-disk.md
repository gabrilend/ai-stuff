# Issue 017: Cache Embeddings to Disk

## Current Behavior
Every time `compile-pdf-ai.lua` runs, it makes a fresh round-trip to the local
Ollama server for every theme description and every poem analyzed. For a full
corpus run that is approximately:

- 82 calls for one-time theme initialization (22 Tier 1, 20 Tier 2, 40 Tier 3)
- One call per page for Tier 1 classification (~400 for full corpus)
- One call per poem for Tier 2 classification (~6,500)
- One call per poem for Tier 3 classification (~6,500)

Total: roughly 13,500 Ollama embedding calls per book, none of which are
preserved between runs. Iterating on visual code or on theme descriptions
forces another full pass even when only one variable changed. This is the
single biggest reason the script "feels slow" and was probably the original
motivation behind the 3-page debug cap that was removed in the cleanup pass.

The embedding function lives in `libs/fuzzy-computing.lua` as
`M.get_embedding(text, model)`, which writes a request JSON to `/tmp/`, shells
out to `curl`, reads the response back, and parses it. No caching layer
anywhere in the call path.

## Intended Behavior
A disk-cache layer sits between `compile-pdf-ai.lua` and Ollama. On every
embedding request:

1. Compute a deterministic key from `(text, model)` using a stable hash
2. Look up `tmp/embeddings/<key>.lua` (or `.json`) on disk
3. If present, deserialize and return — no Ollama call
4. If absent, call Ollama, write the result to `tmp/embeddings/<key>.*`, return

A cold run computes everything and writes the cache. A warm run (same corpus,
same model) reads everything from disk and makes zero Ollama calls. A run with
slightly different content does as many Ollama calls as there are changed
poems — same-text poems reuse their cached embeddings.

The cache lives under `tmp/` (which is the existing symlink to a RAM-backed
`/tmp/words-pdf/` directory) so it doesn't pollute the project tree and clears
naturally on reboot. A future enhancement could move it to a persistent
location if cache survival across reboots becomes useful.

## Suggested Implementation Steps
1. Choose a hash. Lua 5.2 has no built-in cryptographic hash; the project
   already shells out to system tools elsewhere, so `sha256sum` is the
   simplest. Alternative: a small pure-Lua FNV-1a or djb2 — adequate for
   cache keys since collision risk is low at this scale and a collision
   only re-fetches one embedding.
2. Decide cache file format. Lua tables serialized as
   `return { 0.123, 0.456, ... }` are dead-simple to load with `dofile`. JSON
   via the existing `dkjson` dependency also works. Lua-return format is
   smaller (no quoting) and faster to load — preferred.
3. Modify `libs/fuzzy-computing.lua`'s `get_embedding` to consult the cache
   before making the curl call, and write the result on a miss. Keep the
   function signature stable so `compile-pdf-ai.lua` needs no changes
   beyond importing.
4. Have the cache directory be created lazily on first write — if
   `tmp/embeddings/` doesn't exist, create it. (This is one of the few
   places where `os.execute("mkdir -p ...")` is justifiable since it's
   creating a project-internal ephemeral directory, not targeting user
   files. Alternative: have the `run` script `mkdir -p` it alongside the
   output dirs.)
5. Add a print at startup showing cache state — "embedding cache: 8423
   entries on disk" or "embedding cache: cold start". This makes it
   obvious whether the cache is doing its job.

## Related Documents
- `libs/fuzzy-computing.lua` — the embedding function to wrap
- `compile-pdf-ai.lua` — every caller of `fuzz.get_embedding`
- `run` script — handles `mkdir -p` for ephemeral dirs

## Metadata
- Priority: High (unblocks rapid iteration on Issue 019 — without this,
  each tweak-and-re-render cycle takes minutes)
- Complexity: Low
- Dependencies: none
- Estimated Effort: Small

## Implementation Notes
The cache key should be `hash(model_name .. "::" .. text)` so that switching
models doesn't collide on the same text. The separator string matters: any
single non-printable byte works to prevent the (model, text) tuple from
ambiguously rejoining.

If the user re-runs after editing theme descriptions, the cache will hold
stale embeddings for the old descriptions. They become harmless garbage that
just takes disk space until the user clears `tmp/embeddings/`. Worth a note
in the project README, not worth automated invalidation.

Crucially: do NOT silently fall back to "no cache" if the cache directory is
unwritable. Per the project's "prefer errors over fallbacks" rule, an
unwritable cache dir should fail loudly so the user can fix it rather than
silently doing 13,500 Ollama calls every run.
