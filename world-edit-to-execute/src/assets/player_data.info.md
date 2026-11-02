# player_data.lua

Where the player's own files live (issue 604, answering issue 601's open
question): `<root>/player-data/` by default, or the folder that
`<root>/config/player-data.lua` names. Git ignores both.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `folder(root)` | the project folder | the player data folder (no trailing `/`), and `"default"` or the config file's path |
| `blobs(root)` | the project folder | `folder(root) .. "/blobs"`, the store of `dedup.lua` |

## The config file

    return { folder = "/srv/games" }

A relative folder is read from the project; `~/` is `$HOME`. A config file
that doesn't load, raises an error, or returns no `folder` string is an
error, not a quiet fall back to the default.
