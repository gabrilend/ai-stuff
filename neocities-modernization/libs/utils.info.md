# utils.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in libs/utils.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Project-wide utility library
project-dir: none -- a library the programs load; it is never run itself.
The programs read --dir (libs/project-dir.lua) and tell it their folder.
Common functions for file I/O, logging, and configuration management
```

## External functions (what other programs can call)

### `M.log_info(message)`
(No comment above it in the source.)

### `M.log_warn(message)`
(No comment above it in the source.)

### `M.log_error(message)`
(No comment above it in the source.)

### `M.file_exists(filepath)`
(No comment above it in the source.)

### `M.read_file(filepath)`
(No comment above it in the source.)

### `M.write_file(filepath, content)`
(No comment above it in the source.)

### `M.get_timestamp()`
(No comment above it in the source.)

### `M.ensure_directory(dirpath)`
(No comment above it in the source.)

### `M.get_project_paths(base_dir)`
(No comment above it in the source.)

### `M.parse_interactive_args(args)`

```
returns: interactive (boolean, -I given), dir_override (string from --dir
PATH, or nil)
```

### `M.parse_cli_args(args)`

```
Comprehensive CLI argument parser for main.lua
Returns a table with all parsed options for selective stage execution
Supports: stage flags (--parse-only, --validate-only, etc.), config (--force, --threads)
Phase D (Issue 8-012): Added --pages flag for pagination control
```

### `M.show_menu(title, options)`
(No comment above it in the source.)

### `M.confirm_action(message)`
(No comment above it in the source.)

### `M.read_json_file(filepath)`
(No comment above it in the source.)

### `M.write_json_file(filepath, data)`
(No comment above it in the source.)

### `M.directory_exists(dirpath)`
(No comment above it in the source.)

### `M.get_file_mtime(filepath)`
(No comment above it in the source.)

### `M.get_working_directory()`
(No comment above it in the source.)

### `M.relative_path(absolute_path, base_dir)`
(No comment above it in the source.)

### `M.parse_assets_dir(args)`

```
Parse --assets flag from command line arguments (Issue 10-076; it was --dir,
which is now the project folder in every program).
@param args: table of command line arguments (default: global 'arg')
@return: string path if --assets found, nil otherwise
```

### `M.load_asset_config()`

```
Issue 10-003: Load asset path configuration from unified config (config.lua)
@return: table with assets_root key, or nil if config not found
```

### `M.init_assets_root(cli_args)`

```
Initialize assets root path with priority: CLI > config > error
Must be called once at startup, before any asset_path() calls
@param cli_args: optional table of CLI arguments (default: global 'arg')
@return: string path to assets root, or nil on error (after printing message)
```

### `M.get_assets_root(cli_args)`

```
Get the configured assets root path
Initializes from config if not already done
@param cli_args: optional CLI args for initialization
@return: string path to assets root
```

### `M.asset_path(relative)`

```
Build full path to an asset file
@param relative: relative path within assets (e.g., "poems.json")
@return: full absolute path
```

### `M.embeddings_dir(model_name)`

```
REVERSED 2026-08-08 (Issue 10-065, question 11): this returns the DISK path
again. It read "M.DIR .. /tmp/shared-memory/cache/embeddings/ .." -- the RAM
tier -- from Issue 10-054 until the finding in question 10 undercut the
premise that change rested on.

10-054 traded durability for SSD write endurance, on the understanding that
what it gave up was survival across a REBOOT. That was wrong about this host.
elogind runs here with RemoveIPC at its default of yes, so /dev/shm is emptied
when the operator's last login session ends -- closing the last terminal is
enough. The caches were not surviving until the next reboot; they were
surviving until the next logout, and a 20-minute rebuild (per .stage-timings)
was being paid per session rather than per reboot. A cache with that lifetime
is a per-session scratch buffer, and paying twenty minutes an evening to avoid
roughly 4 GB of writes per full regeneration is the wrong side of the trade.

The reversal is one line ONLY because 10-054 did the hard part: it routed
every reader AND every writer of a movable cache through this function (that
was the work its own history records as failing twice before it stuck). With
one resolution point, moving the tier is changing one return value. The value
of that centralization is exactly this -- that the decision it encodes can be
revisited cheaply when the facts change.
```

### `M.embeddings_dir_disk(model_name)`

```
The on-DISK embeddings dir (assets/). Kept as a SEPARATE function even though
it now returns exactly what embeddings_dir() returns, because the distinction
it draws is real and worth keeping legible: its callers
(diversity_cache.json, in flat-html-generator and main.lua)
are the ones that must NEVER be moved to volatile storage,
whatever embeddings_dir does next. Collapsing them would erase the record of
which caches are cheap to lose and which are not -- and that record is the
thing that made the reversal above safe to reason about.
```

### `M.similarities_dir(model_name)`

```
Get path to similarities directory for a specific model
@param model_name: optional model name
@return: full path to model's similarities directory
```

## Inside (local to the file)

### `setup_dir_path(provided_dir)`
(No comment above it in the source.)

### `stray_word(word)`

```
Issue 10-076: a word with no flag in front of it stops the program, named.
It used to become the project folder (dir_override), so a flag that lost
its dashes, or a value whose flag this parser did not know, silently moved
the whole program to a folder named after that word.
```

### `safe_model(model_name)`

```
Get path to embeddings directory for the named model, or for the currently
configured default model when called with no argument.

Centralizing the model -> directory mapping here means a model switch in
config.lua propagates automatically to every caller, instead of requiring
a hunt through ~30 hardcoded "embeddinggemma_latest" string literals.
@param model_name: optional. nil means "ask inference-server-config which model is
                   currently selected and use that"; pass an explicit
                   string only if you need a different model's directory.
@return: full path to that model's embeddings directory
WHERE THE CACHES LIVE, and the history of that answer.

Now: on DISK, under assets/embeddings/<model>/. Both this function and
embeddings_dir_disk() resolve there.

Issue 10-054 moved the movable, regenerable caches into RAM
(tmp/shared-memory/, the /dev/shm tier) to spare SSD write endurance, keeping
only diversity_cache.json on disk because it is the expensive one to
recompute. It removed the earlier CACHE_IN_RAM on/off flag rather than
flipping it, on the reasoning that one unconditional location cannot desync
the way a half-applied switch had twice before.

Issue 10-065 (question 10) then found the fact that decision was missing.
"RAM until reboot" was not true on this host: elogind runs with RemoveIPC at
its default of yes, which deletes every IPC object a user owns -- POSIX shared
memory, i.e. the contents of /dev/shm -- when that user's LAST LOGIN SESSION
ends. Closing the last terminal is enough. (/tmp is not an IPC object, which
is why the exec tier survives when the shared-memory tier does not.)

Observed: /dev/shm/neocities-modernization was emptied overnight on a machine
with two days of uptime, taking a 120 MB embeddings.json with it.

So the caches were being discarded per SESSION, not per reboot, and the
~20-minute rebuild (per .stage-timings) was being paid that often. Reversed
accordingly: see the note on embeddings_dir below.

The rule is unchanged in shape, only in destination: movable caches ->
embeddings_dir(); the one that must never be volatile -> embeddings_dir_disk().
```
