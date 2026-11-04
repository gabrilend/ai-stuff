# centroid-generator.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in src/centroid-generator.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Centroid Generator
Generates custom embedding centroids from user-defined source files and keywords.
These centroids serve as alternative starting points for similarity/diversity exploration,
allowing users to discover poems by mood or theme rather than by existing poem.

The generator reads assets/centroids.json, embeds each centroid's combined content,
and outputs the results to assets/embeddings/{model}/centroids.json for use by
the HTML generator.

--help: print the header above and exit, when run as a program (libs/script-help.lua)
```

## External functions (what other programs can call)

### `M.generate_all_centroids(options)`

```
Processes all centroids defined in the config file
```

## Inside (local to the file)

### `generate_embedding_with_chunking(text, endpoint, depth)`

```
Issue 10-050: embeds a centroid's combined text and returns the LIST of its
per-chunk vectors (calculate_ultra_centroid below folds them into one
normalized centroid). This replaced three things at once: a bespoke single-
input curl (generate_embedding), a paragraph/line split-point finder
(find_safe_split_point), and a recursive binary chunker. All three are now the
shared chunker (text-chunking.lua) plus ONE batched request covering every
chunk of the centroid. The `depth` parameter is kept for call-site
compatibility but is no longer used (chunking is no longer recursive here).
```

### `calculate_ultra_centroid(chunk_embeddings)`

```
Combines multiple chunk embeddings into a single normalized centroid
```

### `load_source_files(file_paths)`

```
Reads and concatenates content from source file paths
```

### `build_centroid_text(centroid_def)`

```
Combines source file contents and keywords into a single text for embedding
```

### `generate_centroid_embedding(centroid_def, endpoint)`

```
Main function to generate a single centroid's embedding
```
