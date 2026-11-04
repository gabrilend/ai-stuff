# flat-html-generator.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in src/flat-html-generator.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
flat-html-generator.lua: Stage 9 -- every page of the site.

WHAT IT DOES (for a CEO): draws the site from the poems and the caches the
earlier stages made: each poem's similar and different pages, the
chronological pages, the poems' plain-text exports and the word pages,
all as jobs for a pool of worker threads (src/poem-entry.lua draws each
poem), plus the explore pages. main.lua --html-only calls it in a build.

Usage: luajit src/flat-html-generator.lua [--dir PATH] [-I]
  --dir PATH project folder (default below); -I  ask before each step

--help: print the header above and exit, when run as a program (libs/script-help.lua)
```

## External functions (what other programs can call)

### `M.use_similarity_rankings_for_tests(cache_table)`

```
Hands the module a rankings table directly ({ rankings = { ["<poem_index>"] =
{ neighbour poem_index, ... } } }), so a test can build pages from a few
made-up poems without the real cache file.  The site build never calls it.
```

### `M.default_chrono_per_page()`

```
The chronological page size, from config. There is no compiled-in fallback on
purpose: a runtime --chrono-per-page override is the OTHER legitimate source
(callers prefer that and use this only when no override was given), and if the
config key is somehow missing that is a broken config we want to hear about,
not paper over with a silent default that would mis-paginate every poem link.
```

### `M.get_pagination_config()`

```
Exposes pagination configuration for external scripts
Returns: PAGINATION_CONFIG table
```

### `M.get_storage_config()`

```
Exposes storage configuration for external scripts (Issue 8-020)
Returns: STORAGE_CONFIG table
```

### `M.calculate_page_count(total_poems)`

```
Exposes page count calculation for external scripts
Returns: number of pages needed for given poem count
```

### `M.generate_word_pages_on_workers(jobs, output_dir, num_threads)`

```
Draws the word-cloud word pages on the page workers (Issue 10-035).
jobs        : list of { word, header_color, centre_link, entries } as
              run_page_workers takes for kind "word_page" (kind is set here)
output_dir  : the site folder; pages go to output_dir/wordcloud/
num_threads : worker threads, 1 or more
returns     : the number of pages written
```

### `M.generate_chronological_index_with_navigation(poems_data, output_dir, chrono_per_page, num_threads)`

```
Writes the chronological pages: every poem in date order, a page at a time,
each page built by a worker thread (Issue 8-058; they used to be built here,
one long string at a time, which took ~33 s for 9 pages).
poems_data      : the loaded poems.json
output_dir      : the site folder
chrono_per_page : number of poems per page, or nil for config.lua's value
                  (Issue 9-003); a number also turns pagination on
num_threads     : number of worker threads, 1 or more
returns         : the path of the first page written
```

### `M.generate_simple_discovery_instructions(output_dir, poems_data)`

```
Back-compat shim: callers that pass only output_dir still work (boosts/golden
counts simply won't appear without the corpus). Prefer passing poems_data.
```

### `M.generate_explore_page(output_dir, poems_data)`

```
explore.html -- the welcome / map: orientation + live corpus stats + every
navigation mode + links to the deeper-math page and (placeholder) the source
browser (Issue 10-052). Data/view split: corpus_stats() computes, this renders.
```

### `M.generate_explore_math_page(output_dir, poems_data)`

```
explore-2.html -- the deeper math: how the semantic engine works, explained
honestly, with REAL corpus-shape charts (per-source, length, over-time) drawn
as monospace bars. Similarity-distribution charts need the 662MB matrix that
is deliberately not loaded here, so they are noted as a future addition.
```

### `M.generate_chronological_txt_file(poems_data, output_file)`

```
Every poem in date order as one text file (Issue 8-013), drawn as on the
chronological pages but as plain text: each poem's file line and its frame,
no navigation boxes, no links, pictures as their descriptions. No time
stamp, so the same poems write the same bytes. Returns output_file.
```

### `M.generate_complete_flat_html_collection(poems_data, similarity_data, embeddings_data, output_dir, pages_spec, poems_per_page, num_threads, chrono_per_page, anchor_indices)`

```
Generates all similarity and diversity pages for the entire corpus
poems_data: full poems dataset
similarity_data: similarity matrix
embeddings_data: poem embeddings (for diversity calculation)
output_dir: base output directory
pages_spec: (optional) --pages flag value: nil/"default", "all", or a page count such as "3" (Phase D: Issue 8-012)
poems_per_page: (optional) CLI override for poems per page (Issue 8-022)
num_threads: (required) number of worker threads, 1 or more (Issue 10-065a: no default in code)
chrono_per_page: (optional) CLI override for chronological poems per page (Issue 9-003)
anchor_indices: (optional) list of poem_index numbers. Given, only these
  poems get similar/different pages; every poem in poems_data still takes
  its place on the timeline and in the ranked lists. Used by
  scripts/render-page-sample to draw a sample of the site (Issue 8-058);
  a build passes nothing and every poem gets its pages.
```

### `M.main(interactive_mode)`

```
The page builder run on its own (-I). One poem's test pages are drawn by
src/main.lua's "Test one poem's pages", or scripts/render-page-sample
--anchor N; the menu items here that drew them with the old one-thread
builder went with it (Issue 8-058).
```

## Inside (local to the file)

### `load_diversity_cache(model_name)`

```
Loads pre-computed diversity sequences from GPU cache (required for HTML generation)
Errors out if cache doesn't exist - no fallback to on-the-fly computation
```

### `load_similarity_rankings_cache(model_name)`

```
Loads pre-sorted similarity rankings from cache (required for HTML generation)
Errors out if cache doesn't exist - no fallback to on-the-fly sorting
```

### `flatten_media_files(output_dir)`
(No comment above it in the source.)

### `load_pagination_config()`
(No comment above it in the source.)

### `compute_storage_max_pages(output_dir, num_poems)`

```
Issue 10-057 follow-up: derive how many similar/different pages per poem fit the
storage quota instead of freezing a guess in config. Everything is MEASURED from
the last build's output on disk -- a self-correcting validator, not an estimate:
  budget          = storage.limit_gb (the Neocities quota; the one real config fact)
  avg_page_size   = bytes of output/similar / number of those page files
  per_page_level  = avg_page_size x num_poems x 2 (each poem gets one similar AND
                    one different page per page-level)
  fixed           = everything else already in output/ (media, wordcloud, chrono,
                    gallery) -- does NOT grow with the page count
  max_pages       = floor((budget - fixed) / per_page_level)
Pages reference images via <img src>, so a page on disk is text; the picture bytes
are the single output/media cost, folded into `fixed`. Measurements use du/find
(read-only) with block-rounded bytes -- conservative (rounds the cap DOWN, the safe
direction for a quota). First build (no pages to measure): warn and DO NOT cap; the
next build measures real sizes and applies the cap.
```

### `calculate_page_count(total_poems)`

```
Calculates the total number of pages needed for a given poem count
Returns: number of pages (always at least 1)
```

### `parse_pages_specification(pages_spec, total_pages_possible)`

```
Parses the --pages flag value into a list of page numbers or special value
Supports formats:
  nil or "default"  → Use minimum_pages from config (usually {1})
  "all"             → Generate all pages up to max_pages_per_poem limit
  "N"               → N pages per poem: pages 1 through N, e.g. "3" → {1,2,3}

A bare number is a COUNT, the same as stages 7 and 8 read it and as run.sh's
help says ("pages generated per poem"). It briefly meant "only page N",
which made "--pages 3" write nothing but the -03 file for every poem while
every link on the site pointed at -01: 1.3 million broken links in one build.
Returns: {pages = {1,2,3,...}, is_all = boolean}
is_all flag indicates if we should generate all pages (respecting max_pages limit)
```

### `load_poem_colors()`
(No comment above it in the source.)

### `sort_poems_chronologically_by_dates(poems_data)`
(No comment above it in the source.)

### `compute_chronological_mapping(poems_data, chrono_poems_per_page)`

```
Computes poem_index → {position, page_number, total_poems, total_pages, timeline_progress}
Used by parallel workers to generate correct chronological links and progress bars
Issue 8-045: Added timeline_progress for time-based progress bar calculation
```

### `worker_config(output_dir)`

```
What every page worker is handed when it starts (plain values only: a worker
is its own Lua state). Callers add the fields their jobs need.
  dir, output_dir      : strings, the project and the site folder
  image_manifest_path  : string, the picture pseudo-poem manifest (Issue 9-013)
  embeddings_dir       : string, the selected model's folder (poem colours)
  palette, boost_palette : the colour tables from config.lua (Issue 8-058)
  layout               : the widths the drawer needs
  page_head            : string, the shared <head> lines
```

### `run_page_workers(num_threads, config, jobs)`

```
Builds pages on a pool of worker threads (Issue 10-034's orchestrator,
shared by every page type since Issue 8-058). This program keeps the job
list and the big neighbour caches; each worker asks for a job, gets just
what that job needs, writes its pages and asks again.
num_threads : number of workers, 1 or more (one thread is one worker: the
              single-threaded builder, a drifted copy, is gone)
config      : table from worker_config(), plus job-specific fields
jobs        : list of
  { kind = "poems", poem_index = n }  -- that poem's similar + different pages
  { kind = "chrono_page", page_num = n, total_pages = n, total_poems = n,
    entries = { { poem = <a poem from the caller's poems>, progress_pct = number }, ... } }
  { kind = "word_page", word = string, header_color = "#rrggbb", centre_link = string,
    entries = { { poem = <a poem from the caller's poems>, progress_pct = number, chrono_file = "03.html" }, ... } }
    -- one word-cloud word's page (Issue 10-035); the poems are already
    -- chosen and ordered by src/generate-word-pages.lua, and carried in
    -- the job as the chronological jobs carry theirs (this worker's own
    -- copy has the gallery pictures folded in, which draws an image-only
    -- post as a picture box)
returns     : { similar = n, different = n, poems = n, chrono_pages = n, text_files = n, word_pages = n }
```

### `explore_page_shell(title, heading, body)`

```
Shared HTML shell for the explore pages: black background, monospace, the
corrected centered-<pre> layout. Returns the full document for a title +
heading + pre-formatted body.
```

### `corpus_stats(poems_data)`

```
Gather the live numbers both explore pages render from, so nothing is
hard-coded (stale figures are worse than no figures). Reads only poems_data
(the small 12MB file) -- never the 662MB similarity matrix -- so it is cheap.
```

### `ascii_bar_row(label, count, max_count, bar_width, label_width)`

```
One labelled monospace bar: "<label padded> | ████····  <count>". Fits the
site's no-JS, monospace aesthetic (same idiom as the poem progress bars).
```
