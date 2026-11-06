# storage.lua (command line)

Shows and clears out the player's stored maps and asset packs (issue 605),
through `src/assets/storage.lua`.

| Command | Does |
|---------|------|
| (none), `--detail` | the overview: total, savings, each pack and map with its size, its own bytes and when last used; shared and unused bytes |
| `report` | the overview with `--detail` |
| `delete map\|pack NAME [--force]` | asks, then deletes and collects; with no answer (not a terminal) nothing is deleted; `--force` skips the question |
| `gc` | removes stored files nothing uses |
| `orphans` | lists the hashes `gc` would remove |

Options first: `--dir DIR` (the project; its player data folder is used)
and `--data FOLDER` (a player data folder directly).

Exit status: 0 done, 1 nothing deleted (answered no, or no such map or
pack), 2 a usage error.

Loaded with `dofile`, it returns `{render(S, detail), delete(S, kind, name, force, ask)}`.
