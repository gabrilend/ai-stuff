# fetch.lua (command line)

| Command | Does |
|---------|------|
| `sources` | each site in `src/fetch/sources.lua`, its access, and whether it may be fetched |
| `scan FOLDER [--as NAME]` | a catalogue of the maps and models in a folder on disk (keeps entries downloaded before) |
| `list SOURCE` | the entries, numbered, marked when downloaded |
| `download SOURCE N [--network]` | fetches, checks and stores entry N; prints the hash and where it is stored, and any stock textures left unverified |

Options first: `--dir DIR` (the project) and `--data FOLDER` (a player
data folder). Exit status: 0 done, 1 refused or not found, 2 a usage error.
