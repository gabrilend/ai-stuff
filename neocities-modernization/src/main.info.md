# main.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in src/main.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
main.lua: the poetry site's core stages, one at a time or all together.

WHAT IT DOES (for a CEO): reads the exported posts and notes into one
list of poems, checks that list, finds the pictures, and draws the
website's pages from the poems and the caches the GPU stages made. run.sh
calls it once per stage (3, 4, 5 and 9); asking for no stage runs them
all in order, and -I opens a menu instead.

Usage: luajit src/main.lua [--dir PATH] [MODE] [OPTIONS]
  --dir PATH           the project folder (default below); any word that is
                       not a flag or a flag's value stops the program
Modes (one at most; none = the whole pipeline):
  --parse-only         stage 3: the exports become assets/poems.json
  --validate-only      stage 4: check the poems, write the validation report
  --catalog-only       stage 5: find every picture, write the image catalog
  --html-only          stage 9: draw every page into output/
  -I, --interactive    a menu of the stages
Options:
  --assets PATH        where assets/ lives (run.sh passes it; was --dir)
  --force              redo a stage even when its output looks current
  --threads N          page workers for --html-only (asked for if missing)
  --pages LIST         similar/different pages per poem: 1, all, 1-10
  --poems-per-page N   poems on each similar/different page
  --chrono-per-page N  poems on each chronological page
  --seed N             the build's random seed
  --no-boosts / --include-boosts   leave out or keep boosted posts
  -v, --verbose        more detail
  --help               this text, and nothing else

--help: print the header above and exit, before any work (libs/script-help.lua)
```

## External functions (what other programs can call)

### `M.show_tui_menu()`

```
Runs the TUI menu and returns the selected action and values
```

### `M.show_simple_menu()`

```
Simple text-based menu fallback when TUI is not available
```

### `M.show_main_menu()`

```
Legacy wrapper for backwards compatibility
```

### `M.is_data_fresh()`
(No comment above it in the source.)

### `M.extract_poems(force)`
(No comment above it in the source.)

### `M.validate_poems()`
(No comment above it in the source.)

### `M.test_embedding_service()`
(No comment above it in the source.)

### `M.catalog_images(verbose)`

```
Issue 10-015a: Added verbose parameter for detailed statistics output
```

### `M.is_html_fresh()`
(No comment above it in the source.)

### `M.generate_website_html(force, pages_spec, poems_per_page, num_threads, chrono_per_page)`

```
Phase D (Issue 8-012): Added pages_spec parameter for pagination control
Issue 8-022: Added poems_per_page parameter for CLI override
Issue 9-002: Added num_threads parameter for parallel HTML generation
Issue 9-003: Added chrono_per_page parameter for chronological pagination
```

### `M.generate_complete_dataset()`
(No comment above it in the source.)

### `M.show_project_status()`
(No comment above it in the source.)

### `M.clean_and_rebuild()`
(No comment above it in the source.)

### `M.handle_tui_action(values)`

```
Handles actions from the TUI menu based on which items are selected
values is a table mapping item_id -> "1" for selected items
```

### `M.test_one_poem_pages(poem_number, threads, poems_per_page)`

```
Draws one poem's similar and different pages (first page of each), and all
the chronological pages they link to, into a fresh folder in RAM, through
the same page workers a build uses (Issue 8-058: there is one way to draw
a page). The site is not touched. poem_number is the site's number (the N
of poem-N); threads is how many workers draw; poems_per_page is asked for
as a build asks, config.lua's value offered, since the neighbour caches
hold only as many poems as the builds' page size needs.
```

### `M.main(options)`

```
Main entry point with support for selective stage execution via CLI flags
Options table can include: interactive, parse_only, validate_only, catalog_only, html_only, force, threads
```

## Inside (local to the file)

### `resolve_include_boosts()`
(No comment above it in the source.)

### `build_menu_config()`

```
Builds the unified menu configuration for the TUI library
Combines functionality from main.lua and flat-html-generator.lua into one interface
```
