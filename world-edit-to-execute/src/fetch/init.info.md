# fetch (init.lua)

Catalogues maps and models, and downloads the one the player picks into
their storage, checked first (issue 603). Local files only unless asked:
see the network rule below.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `fetch.SOURCES` | — | the source list (`sources.lua`) |
| `fetch.source(name)` | a source's name | its entry, or nil |
| `fetch.may_fetch(site)` | a source list entry | true, or false and why (anything not `"allowed"`) |
| `fetch.scan_folder(folder, name)` | a folder on disk, the source's name (default the folder's) | a catalogue of its `.w3x`/`.w3m` maps and `.mdx`/`.zip` models, with `file://` addresses |
| `fetch.save(S, cat)` / `fetch.load(S, source)` | a storage (`assets/storage.lua`), a catalogue or source name | writes / reads `<player data>/catalogue/<source>.lua` |
| `fetch.http_command(url, out)` | an address, a file | the curl command a network fetch runs |
| `fetch.get(entry, opts)` | an entry; `network`, `site`, `run`, `folder` | the file's path, and whether it is a temporary copy; raises when refused |
| `fetch.check_map(path, name)` | a file | `{opens, map_info, map_name, players}`; raises with the file's name and the reason |
| `fetch.check_model(bytes, name, opts)` | a `.mdx` or a `.zip` holding models; `install_read(path)` | `{models, textures_in_download, textures_from_install, stock_unverified}`; raises when a model or a texture in the download doesn't read |
| `fetch.download(S, cat, i, opts)` | storage, a catalogue, an entry's number | the entry with `hash`, `checked`, `stored_as`, `downloaded`; raises, storing nothing, when refused |

## The network rule

An `https://` address is fetched only when the player passes
`network = true` (`--network`) **and** the site's entry is `"allowed"`
(every site starts `"unreviewed"`), and only on that site's own address.
The request is `curl` over HTTPS only, with the user agent
`world-edit-to-execute fetch` and no other headers, cookies or referrer.
Any other address (`http://`, `ftp://`) is refused.

## Where a download goes

- a map: `maps/<title>/<file>` in the player data folder
- a model: `asset-packs/fetched-<source>/<title>/<file>` (a `.zip` stored as it came)
