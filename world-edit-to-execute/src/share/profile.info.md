# profile.lua

The receiver's half of a shared list (issue 609), in the editor: checked,
stored once, and kept as one of the player's own asset packs.

| Function | Takes | Gives |
|----------|-------|-------|
| `profile.verify(l, store, bundle)` | a list, a dedup store, the folder the files arrived in | `{hash, key, problem}` for each file not sent or not matching its hash |
| `profile.keep(l, opts)` | `data`, `store`, `bundle`, `name` | the new pack's folder (`<data>/asset-packs/<name>/`, links into the store); or nil and the problems: one bad file refuses the whole list, and nothing is stored |
| `profile.trust(data)` | the player data folder | the remembered choices (`<data>/share-trust.lua`) |
| `T:decide(sender, l)` | who sent it, the list | `"apply"` (always from them, or always for this map) or `"ask"` |
| `T:always_from(player, on)` / `T:always_for_map(hash, on)` | | remembered at once |

The tool `src/cli/share.lua` does `make`, `missing`, `bundle` and `check`
as files.

Using a list for one game (a layer in front of the player's packs, taken
off after the game) was built and tested here first and is now the W
client's, its issue 1110 (issue 609, "After the editor-and-client
split").
