# audit-config-keys

Lists the settings in `config.lua` that no program in the project reads, and
the "Read by:" comments in `config.lua` that point at the wrong file.

## Why it exists

A setting nothing reads still looks like a control. Someone edits it, rebuilds,
and nothing changes, with no message saying why. Settings become unread
quietly: a stage stops consulting one (the no-defaults change moved several
onto the command line), or a feature is replaced and its switch is left behind.

## Usage

    scripts/audit-config-keys [--dir PATH]          report the unread settings
    scripts/audit-config-keys [--dir PATH] --all    also list what IS read, and by which files

Exit status: 0 nothing unread and no stale comments, 1 something found,
2 `config.lua` could not be loaded.

## What counts as "read"

| How the code reaches it | Example | Counted |
|---|---|---|
| field after a dot | `config.pagination` | yes |
| quoted key in brackets | `cfg["pagination"]` | yes |
| through a local alias | `local p = config.pagination; p.size` | yes (a setting is searched for in the files that read its section) |
| by a quoted name | `local key = "gamma"; config.quoted[key]` | yes |
| a loop over the section | `pairs(unified_config.storage)` | yes, every setting in it |
| through a list in `config.lua` | `config.color_associations[n]` for each `n` in `color_names` | yes |
| in a comment only | `-- config.randomization.seed is no longer read` | no |

The searched files are every tracked program: Lua, shell (including the Lua
written inside shell scripts) and C. Issues, docs, notes, transcripts and the
archive are skipped.

## Limits

It is a candidate list, not a verdict. A name built at run time
(`config[stage .. "_threads"]`) is invisible to it. A short common setting name
(`enabled`, `path`) can match unrelated code and look read. That error only
goes the safe way: a setting reported unread is named by nothing at all.

## Test

`scripts/audit-config-keys.test.sh` builds a throwaway project covering each
row of the table above and checks every verdict.
