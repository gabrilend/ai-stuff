# similarity-engine.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in src/similarity-engine.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
similarity-engine.lua: Stage 6's text embeddings, and the tools around them.

WHAT IT DOES (for a CEO): sends every poem's text to the embedding server
and keeps the vector that comes back, reusing a poem's stored vector when
its text has not changed (Issue 8-019), cutting long poems into pieces and
averaging them (Issue 10-050). generate-embeddings.sh drives it in a
build; run on its own it offers the same work from a menu.

Usage: luajit src/similarity-engine.lua [--dir PATH] [-I]
  --dir PATH project folder (default below); -I  the menu

--help: print the header above and exit, when run as a program (libs/script-help.lua)
```

## External functions (what other programs can call)

### `M.list_available_models()`
(No comment above it in the source.)

### `M.get_model_status(base_output_dir, model_name)`
(No comment above it in the source.)

### `M.show_all_model_status(base_output_dir)`
(No comment above it in the source.)

### `M.checkpoint_is_due(windows_since_save, min_windows, now, next_allowed_at, is_last_window)`

```
Decide whether the embedding run should stop and rewrite its cache file.

A checkpoint rewrites the WHOLE cache -- every vector gathered so far becomes
JSON text again and the entire file is written out. It is pure CPU in this one
process, single-threaded, with the inference server idle throughout; and its
price is not fixed but grows with how much has already been done, because
"everything so far" is the thing being re-encoded. Measured on this corpus, a
checkpoint at 7,300 poems costs about seven seconds and turns 5.6 million
floating-point numbers into decimal digits.

Checkpointing every ~100 poems therefore levied a toll that climbed all run.
On one measured 8,531-poem run the server sat idle 249 seconds out of 460 --
more than half the run was the saving, not the work.

So the interval is measured in TIME rather than in poems, and it is set by the
run itself: each checkpoint reports what it cost, and the next one is refused
until `duty` times that long has passed. Overhead is then pinned near
1/(1+duty) of the run however large the corpus grows. Cheap early checkpoints
stay frequent; expensive late ones space themselves out, which is the shape
you want -- late in a run there is more work at risk, but proportionally less
run remaining in which to lose it.

Arguments (all plain numbers except the last two flags):
  windows_since_save : integer, windows completed since the last checkpoint
  min_windows        : integer, floor so a corpus with instant saves does not
                       checkpoint after every single window
  now                : integer, wall-clock seconds (os.time)
  next_allowed_at    : integer, the wall-clock second the cooldown expires
  is_last_window     : boolean, the run is ending
Returns true when a checkpoint should happen now.
```

### `M.checkpoint_cooldown_until(now, save_seconds, duty)`

```
The wall-clock second at which the next checkpoint becomes allowed, given what
the one just finished cost. A save too fast to measure earns no cooldown, and
the window count alone paces the run.
```

### `M.reusable_vector(poem, prior, dims)`

```
Whether a stored vector may serve this poem again (Issue 8-019).
poem      : a poem from poems.json (source_key, content, is_image_only,
            nearest_text_poem_index)
prior     : the stored entry under the poem's source key, or nil
dims      : the model's vector length
returns   : the reuse (boolean) and a reason (string):
  "reuse"         its own vector, from this exact text
  "new"           nothing stored for this poem
  "made_fresh"    an image-only post or an empty poem: made every run
  "text_changed"  the stored vector came from other text
  "invalid_dimensions"  the stored vector has the wrong length
A vector is matched by the poem it came from and the text it came from,
never by number: numbers are counted fresh each run, and the notes of
2026-10-07 kept their old numbers' vectors.
```

### `M.reused_entry(prior, poem_index)`

```
The stored entry carried into this run, filed under this run's number.
prior      : the stored entry (a table; it is not changed)
poem_index : this run's number for the poem (integer)
returns    : a new entry, a copy of prior
Issue 9-013: a text + picture post was blended with its pictures by Stage
6.7, which kept the pure text vector beside the blend (text_embedding). The
text vector is what this stage makes, so it is the one carried over, and
Stage 6.7 blends again from it. Taking the blend would blend a blend, and
the post would drift toward its pictures a little more every run.
```

### `M.generate_all_embeddings(poems_file, base_output_dir, endpoint, incremental, model_name)`
(No comment above it in the source.)

### `M.calculate_similarity_matrix(embeddings_file, output_file, top_n, force_regenerate)`

```
[DEPRECATED / DEAD CODE / PRUNE CANDIDATE] -- Issue 10-060.

READ THIS BEFORE DELETING ANYTHING IN THIS FILE. similarity-engine.lua is
LIVE: it is the embedding generator behind generate-embeddings.sh (stage 6).
A previous cleanup deleted the whole file as "CPU similarity code" and the
next full regeneration failed at stage 6. The FUNCTIONS below are dead; the
FILE is not. Prune at function granularity here, never at file granularity.

What the live pipeline actually calls into this module (verified 2026-08-08 by
grepping generate-embeddings.sh, the only .sh that requires it):
    generate_all_embeddings, flush_embeddings_cache,
    list_available_models, show_all_model_status

This function and the two CPU matrix builders below it are reachable ONLY from
M.main() -- this module's own standalone interactive menu -- and from
generate_all_model_similarity_matrices, which nothing outside the file calls.
The CPU similarity route they implement was removed from the pipeline by Issue
10-057: run.sh hard-errors when libvkcompute.so is absent rather than falling
back to CPU. Stage 7 is GPU-only.

Prior note, still true and now subsumed by the above (Issue 8-029): this
generates a top-N array format incompatible with the HTML generator; the full
pairwise format came from calculate_full_similarity_matrix().
```

### `M.calculate_full_similarity_matrix(embeddings_file, output_file, force_regenerate)`

```
[DEPRECATED / DEAD CODE / PRUNE CANDIDATE] -- Issue 10-060. CPU similarity,
superseded by the GPU path (Issue 10-057). Reachable only from this module's
own M.main() menu and generate_all_model_similarity_matrices. See the longer
note on calculate_similarity_matrix above -- in particular, that this FILE is
live (it is stage 6's embedding generator) even though this function is not.
```

### `M.calculate_triangular_similarity_matrix(embeddings_file, output_file, force_regenerate)`

```
[DEPRECATED / DEAD CODE / PRUNE CANDIDATE] -- Issue 10-060. CPU similarity,
superseded by the GPU path (Issue 10-057). Not to be confused with
src/triangular-similarity-matrix.lua, which is a separate and entirely
unreferenced FILE, also marked. See the note on calculate_similarity_matrix
above: this file is live, these functions are not.
```

### `M.get_similarity_triangular(matrix, id1, id2)`
(No comment above it in the source.)

### `M.get_all_similarities_for_poem_triangular(matrix, poem_id, poem_ids)`
(No comment above it in the source.)

### `M.generate_similarity_report(similarity_file, poems_file, output_file)`
(No comment above it in the source.)

### `M.generate_all_model_similarity_matrices(base_output_dir, min_completeness, use_full_matrix)`
(No comment above it in the source.)

### `M.compare_model_similarities(poem_id, base_output_dir, models, use_full_matrix)`
(No comment above it in the source.)

### `M.get_multi_model_status(base_output_dir)`
(No comment above it in the source.)

### `M.main(interactive_mode)`
(No comment above it in the source.)

### `M.flush_embeddings_cache(output_file, flush_type, backup)`
(No comment above it in the source.)

## Inside (local to the file)

### `get_model_storage_path(base_dir, model_name)`
(No comment above it in the source.)

### `cosine_similarity(vec1, vec2)`
(No comment above it in the source.)

### `generate_embedding(text, endpoint, model_name)`

```
model_name is required; it ends up in the request payload AND determines
which dimension downstream validators expect. Defaults are dangerous here
because the wrong model silently produces wrong-shape embeddings.
```

### `table_length(t)`
(No comment above it in the source.)

### `generate_random_embedding(poem_id, dimension)`

```
Generates a random 768-dimensional embedding for empty poems
Seeded by poem_id for reproducibility
```

### `inherit_embedding(nearest_embedding, own_embedding, dimension)`

```
Issue 9-010: For image-only posts, inherit embedding from nearest text poem
Optionally combine with own text embedding if the post has any content
```

### `validate_similarity_matrix_currency(similarity_file, embeddings_file, poems_file)`
(No comment above it in the source.)
