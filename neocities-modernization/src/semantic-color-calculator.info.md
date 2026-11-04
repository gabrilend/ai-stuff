# semantic-color-calculator.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in src/semantic-color-calculator.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
semantic-color-calculator.lua: Stage 6's colours -- each poem's colour.

WHAT IT DOES (for a CEO): embeds a set of words for each of the site's
colours (config.lua color_associations), averages them into one point
per colour, and gives every poem the colour it sits nearest, writing
poem_colors.json for the progress bars and word cloud. run.sh runs it
in Stage 6.

Usage: luajit src/semantic-color-calculator.lua [--dir PATH] [-I]
  --dir PATH  project folder (default below); -I  ask before each step

--help: print the header above and exit, when run as a program (libs/script-help.lua)
```

## External functions (what other programs can call)

### `M.generate_color_embeddings(color_names, model_name, endpoint, color_associations)`

```
endpoint is optional: nil means "ask inference-server-config for the active server",
which is the right behavior for almost all callers. The parameter exists
so that test harnesses or one-off scripts can target a specific server
without having to mutate inference-server-config's module-local selection.

Each color's embedding is the MEAN of the embeddings of its association words
(config.color_associations), giving a richer "essence" anchor than the bare
color word. color_associations is optional: without it (or for a color missing
from it) we fall back to embedding the bare color name, so old callers keep
working. Words are embedded in one batched request per color via the shared
primitive; endpoint + prompt formatter are passed so this file's config
instance stays authoritative (matching prefixes are essential so colors and
poems land in the same embedding space). Mean (not length-weighted) combine:
every association word should count equally regardless of its spelling length.
```

### `M.precompute_poem_colors(poems_data, poem_embeddings_data, color_embeddings, output_file)`
(No comment above it in the source.)

### `M.main(interactive_mode)`
(No comment above it in the source.)

## Inside (local to the file)

### `cosine_similarity(vec1, vec2)`
(No comment above it in the source.)

### `compute_color_stats(poems_data, poem_embeddings_data, color_embeddings)`

```
Per-color mean/std of cosine similarity across ALL poems, used to z-score the
color assignment below. Why this is needed: bare color-word embeddings suffer
from "hubness" -- a couple of them (yellow, green) sit slightly nearer the
centre of the whole poem cloud, so by raw nearest-cosine they win ~70% of all
poems (38% yellow + 29% green) while blue gets 2.5%. The colours are NOT
evenly spread anchors; they are bunched, and tiny baseline offsets decide
everything. Standardising each colour's similarity (subtract its mean, divide
by its std) makes a poem pick the colour it is most ABOVE-baseline for, which
balances the distribution to ~10-18% each without touching the embeddings.
```

### `calculate_semantic_color_for_poem(poem_embedding, color_embeddings, color_stats)`

```
color_stats is optional. With it, the colour is chosen by z-scored similarity
(hubness-corrected); without it, by raw nearest cosine (legacy behaviour). The
returned similarity is always the RAW cosine, so downstream displays are
unchanged -- only the WINNER selection is standardised.
```
