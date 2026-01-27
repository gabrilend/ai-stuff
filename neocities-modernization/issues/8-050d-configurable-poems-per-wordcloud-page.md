# Issue 8-050d: Make Poems-Per-Word-Page Configurable via run.sh

## Priority
Low (independent of other 8-050 sub-issues)

## Current Behavior

The number of poems shown per word-cloud similarity page is hardcoded in `src/generate-word-pages.lua:109`:

```lua
local CONFIG = {
    -- ...
    poems_per_word_page = 50,        -- Show top 50 most similar poems
    -- ...
}
```

This value cannot be changed via `run.sh`, the TUI, or `config.lua`. The only way to change it is by editing the source code.

By contrast, other pagination parameters ARE configurable:
- `--poems-per-page N` (for similar/different pages, parsed in run.sh:230)
- `--chrono-per-page N` (for chronological pages, parsed in run.sh:243)
- `--wordcloud-words N` (number of words in the cloud, parsed in run.sh)

## Intended Behavior

Add a `--wordcloud-poems-per-page N` CLI flag to `run.sh` that controls how many poems appear on each word-cloud similarity page.

### Configuration Precedence

```
CLI --wordcloud-poems-per-page N  >  config.lua word_cloud.poems_per_page  >  default (50)
```

### TUI Integration

Add a "Poems Per Word Page" text field in the "Word Cloud Options" section of the TUI, similar to the existing "Word Count" field.

## Suggested Implementation Steps

### 1. Add CLI flag to run.sh

In the argument parsing section (around line 148-155):

```bash
WORDCLOUD_POEMS_PER_PAGE=""
```

In the argument parsing loop (around line 200-260):

```bash
--wordcloud-poems-per-page)
    WORDCLOUD_POEMS_PER_PAGE="$2"
    shift 2
    ;;
```

### 2. Add TUI item in run.sh

In the "Word Cloud Options" section (near the existing wordcloud TUI items):

```bash
menu_add_text "wordcloud_ppp" "Poems Per Word Page" "50" "Number of poems per word-cloud page"
```

### 3. Pass to scripts in run.sh

In `run_generate_html()`, when calling `generate-word-pages.lua`:

```bash
local wordcloud_ppp_arg=""
if [[ -n "$WORDCLOUD_POEMS_PER_PAGE" ]]; then
    wordcloud_ppp_arg="--poems-per-page $WORDCLOUD_POEMS_PER_PAGE"
fi

luajit "$DIR/src/generate-word-pages.lua" "$DIR" --html-only $wordcloud_ppp_arg
```

### 4. Parse in generate-word-pages.lua

Update `parse_args()` (line 34) to handle `--poems-per-page N`:

```lua
elseif a == "--poems-per-page" then
    poems_per_page = tonumber(args[i + 1])
    i = i + 2
elseif a:match("^--poems%-per%-page=") then
    poems_per_page = tonumber(a:match("^--poems%-per%-page=(.+)$"))
    i = i + 1
```

### 5. Add to config.lua

In the `word_cloud` section:

```lua
word_cloud = {
    -- ... existing fields ...
    poems_per_page = 50,  -- Poems shown per word-cloud similarity page
}
```

### 6. Apply precedence in CONFIG construction

```lua
local CONFIG = {
    -- ...
    poems_per_word_page = CLI_POEMS_PER_PAGE
        or (wc.poems_per_page)
        or 50,
}
```

## Validation

- Default behavior (no flag): 50 poems per page (unchanged)
- `--wordcloud-poems-per-page 25`: Pages show 25 poems
- `--wordcloud-poems-per-page 100`: Pages show 100 poems
- TUI: Value entered in "Poems Per Word Page" field is respected
- Config: `word_cloud.poems_per_page = 75` overrides default but is overridden by CLI

## Related Documents

- Issue 8-050: Enhance Word-Cloud Semantic Similarity Pages (parent)
- Issue 8-043: Generate Semantic Word Cloud Page (original configurable word count implementation)
- `src/generate-word-pages.lua:104-111` — CONFIG definition
- `run.sh:148-155` — Existing wordcloud CLI variables
- `config.lua:221-280` — word_cloud config section

## Metadata

- **Status**: Open
- **Created**: 2026-01-26
- **Phase**: 8 (Website Completion)
- **Parent**: 8-050
- **Estimated Complexity**: Low (pattern exists from --wordcloud-words, replicate for poems-per-page)
- **Dependencies**: None (independent sub-issue)
