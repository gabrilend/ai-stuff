# image-manager.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in src/image-manager.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
image-manager.lua: Stage 5 -- the catalog of every picture.

WHAT IT DOES (for a CEO): looks through the picture folders config.lua
lists (sources.images) for the formats it allows, and writes
assets/image-catalog.json: each picture's path, size, dimensions, date
and a fingerprint of its contents. main.lua --catalog-only calls it in a
build.

Usage: luajit src/image-manager.lua [--dir PATH] [-v]
  --dir PATH project folder (default below); -v  more detail

--help: print the header above and exit, when run as a program (libs/script-help.lua)
```

## External functions (what other programs can call)

### `M.discover_images()`
(No comment above it in the source.)

### `M.generate_catalog(images, output_file)`
(No comment above it in the source.)

### `M.show_statistics(catalog, verbose)`
(No comment above it in the source.)

### `M.main(verbose)`

```
Issue 10-015a: Added verbose parameter for detailed statistics output
```

## Inside (local to the file)

### `parse_seed_from_args(args)`

```
Issue 10-058: pull the build's master seed out of the shared arg vector. run.sh
threads "--seed=N" (equals form, so the bare number is never mistaken for the
positional DIR). Both "--seed=N" and "--seed N" are accepted. Returns a number
or nil (nil => no master seed supplied; per-source random_seed still applies and
a source with neither is randomized by the system RNG, which run.sh warns about).
```

### `shell_escape(path)`

```
Escape single quotes in paths for safe shell execution
e.g., "Sant'Azraphel.png" -> "Sant'\''Azraphel.png"
```

### `relative_path(absolute_path)`
(No comment above it in the source.)

### `load_config()`

```
Issue 10-015a: Use sources-loader for image directories (replaces input_sources dependency)
Issue 10-030: Now returns full directory objects (not just paths) for randomization support
This is the "no fallbacks" design - errors if sources.images not configured
```

### `get_file_size(file_path)`
(No comment above it in the source.)

### `get_file_mtime(file_path)`
(No comment above it in the source.)

### `extract_image_dimensions(file_path)`
(No comment above it in the source.)

### `generate_image_hash(file_path)`
(No comment above it in the source.)

### `is_supported_format(file_path, supported_formats)`
(No comment above it in the source.)

### `scan_directory_for_images(directory, config, dir_config)`

```
Issue 10-030: Now accepts dir_config (full directory object) for randomization tracking
```

### `create_seeded_rng(seed)`

```
Issue 10-030: Create a seeded random number generator for reproducible randomization
Uses a simple linear congruential generator (LCG) for deterministic results
```

### `derive_source_seed(master_seed, source_name)`

```
Issue 10-058: turn the one build-wide master seed into a STABLE per-source seed,
so every randomized source gets its own reproducible order from the same master.
The per-source key is the source NAME (a djb2 string hash), not its position in
the iteration -- so the derived seed does not change if sources are reordered,
added, or removed. Folded to a 31-bit non-negative int to match create_seeded_rng.
```

### `apply_randomization(all_images)`

```
Issue 10-030: Apply randomized timestamps to images from randomized sources
```

### `print_aligned(rows, indent)`

```
Issue 10-015a: Added verbose parameter - detailed stats only show when verbose=true
Summary (always shown): total, unique, duplicates count, size
Detailed (verbose only): format distribution, size distribution, resolution distribution
Warnings (always shown): duplicate groups
Prints one section of label/value pairs with the colons lined up, so a
column of numbers reads straight down.  rows: array of {label, value}
(strings); indent: string put before every line.
```
