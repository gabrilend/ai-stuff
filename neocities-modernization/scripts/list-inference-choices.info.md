# list-inference-choices.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/list-inference-choices: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
list-inference-choices
Print the inference servers and embedding models this project knows about,
one per line, so the interactive menu can offer them as a pick-list instead of
a box to type into.

General description (for a CEO): the pipeline needs to be told which machine
to ask and which model to ask it for. Those are exact strings -- "qwen3-
embedding:4b", not "qwen3 embedding 4b" -- and a person typing one from memory
will eventually get it wrong, then wait for a stage to fail before finding
out. This tool reads the real list out of the configuration file so the menu
can show it as a list of choices. You cannot mistype something you pick.

Why a separate tool rather than a few lines inside run.sh: the list has one
source of truth (config.lua's inference_servers), and anything that needs it
-- the menu today, a validator or a status page tomorrow -- should read it
from the same place rather than each growing its own copy of the parsing.

Usage:
  scripts/list-inference-choices [--dir PATH] --servers   -> one server name per line
  scripts/list-inference-choices [--dir PATH] --models    -> one model name per line
--dir PATH defaults to the hard-coded project root; pass it (as run.sh does) to be safe.

Exits non-zero with a message on stderr when the config has no servers, rather
than printing nothing: an empty list and a broken config look identical to a
caller reading stdout, and the caller would render an empty menu section with
no idea why.

--help: print the header above and exit, before any work (libs/script-help.lua)
```

## Inside (local to the file)

### `setup_dir_path(provided)`
(No comment above it in the source.)

### `parse_args(args)`

```
--servers / --models choose the list.
```

### `collect_servers()`

```
Just the names, in the order config.lua lists them. Order is preserved rather
than sorted: the file's order is the author's ordering, and a menu that
reorders someone's list is quietly editing their intent.
```

### `collect_models()`

```
Every model any configured server can serve: each server's default `model`,
plus its `available_models` entries. An available_models entry is either a
plain string or a table carrying its own model_path and prompt prefix (see
config.lua's "local" server), so both shapes are read.

Deliberately NOT filtered by what has embeddings on disk. Stage 6 exists to
CREATE those embeddings, so a model with none is a legitimate choice there;
and for the stages that only read caches, run.sh's own
require_embeddings_for_model already refuses a model with nothing behind it
and prints what is available. One check, in the place that knows which stage
is running, beats two lists that can disagree.
```
