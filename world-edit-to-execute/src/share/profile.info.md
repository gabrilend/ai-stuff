# profile.lua

The receiver's half of a shared list (issue 609): checked, stored once,
and put in front of the player's packs for one game.

| Function | Takes | Gives |
|----------|-------|-------|
| `profile.verify(l, store, bundle)` | a list, a dedup store, the folder the files arrived in | `{hash, key, problem}` for each file not sent or not matching its hash |
| `profile.apply(l, opts)` | `data`, `store`, `bundle`, `name` | the profile (`<data>/profiles/<name>/`, links into the store); or nil and the problems: one bad file refuses the whole list |
| `P:attach(L)` | a loader | its files come first (`L:push_layer`, source `"layer:share:NAME"`) |
| `P:revert(L)` | | taken off and removed; its stored files go at the next `gc` |
| `P:keep(name, L)` | a pack name | made an asset pack of the player's own; its folder |
| `P.types` | | `{id -> model path}` for the list's unit types |
| `profile.trust(data)` | the player data folder | the remembered choices (`<data>/share-trust.lua`) |
| `T:decide(sender, l)` | who sent it, the list | `"apply"` (always from them, or always for this map) or `"ask"` |
| `T:always_from(player, on)` / `T:always_for_map(hash, on)` | | remembered at once |

The tool `src/cli/share.lua` does `make`, `missing`, `bundle` and `check`
as files; applying is the game's, for one game.
