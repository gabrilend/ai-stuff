# packs.lua

Asset packs for the matchmaking server's mirror (issue 801f). A lobby names
the packs its map needs (`{ id, hash }` in REGISTER_GAME); a mirror keeps
common packs so players needn't fetch them from the host. The transfers
themselves go over rmail (owner, 2026-09-23; issue 609): the mirror is an
rmail contact that answers requests for packs, and the player accepts each
transfer through rmail's consent step. This module only keeps the lists.

A pack is one file, `<id>.pack`, in a folder; an id is letters, digits,
`.`, `_` and `-`, up to 64, not starting with `.` or `-`. Its hash is
`"sha256:"` and the file's SHA-256 (from `sha256sum`), as lobbies already
write map hashes.

- **`packs.registry(dir)`**: the packs in `dir`. `:list()` (by id: `id`,
  `hash`, `size`, `file`), `:get(id)`, `:has(id [, hash])`, `:add(id,
  from)` (copies the file in, through a `.part` file renamed when whole),
  `:remove(id)` (deletes its file), `:reload()`; `.skipped` lists the
  `*.pack` files it couldn't take, and why.
- **`packs.hash_file(path) -> hash, size`**, or nil and why.
- **`packs.available(registry, required)`**: those of a lobby's packs the
  registry holds with the same hash, as `{ id, hash, size }`; what the
  server sends in ASSET_PACKS_AVAILABLE.
- **`packs.plan(required, have, mirror)`**: each required pack the player
  lacks (`have`: `{ [id] = hash }` or a registry; another hash counts as
  lacking), with `from = "mirror"` when the advertised mirror list has it,
  else `"host"`.

The server takes `mirror = { contact, packs = registry }`; the daemon makes
one with `--mirror-contact C --packs-dir DIR`. Adding and removing packs
from the command line is issue 801g.
