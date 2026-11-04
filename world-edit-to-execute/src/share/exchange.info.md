# exchange.lua

Carries a shared list (issues 609a, 609b) between two players over a transport,
with the one consent step before anything is stored or kept, for "check
out my map": a map and its list given to keep. The
transport is anything with `send(to, message)`; `rmail_hook.lua` is the
one for rmail.

| Function | Takes | Gives |
|----------|-------|-------|
| `exchange.new(opts)` | `data`, `me`, `transport`, `pack` (the sharer's files), `consent(q)` (default: nil, ask later), `on_ready(pack, q)` (a list was kept, as the pack in folder `pack`), `on_problem(id, what)`, `name_for(q)`, `store` | an exchange |
| `X:offer(to, l[, map])` | a player, a list, the map file it names | sends the list, with a copy of the map when given (an error when its hash isn't the list's); the id its answers carry |
| `X:on_message(msg)` | a delivered message | `"asking"`, `"waiting"`, `"declined"`, `"ready"` (kept as a pack), `true` (files sent); or nil and why it was refused |
| `X:pending()` | | the questions waiting for the player |
| `X:answer(id, "yes" or "no")` | | yes: asks for the missing files only (or keeps the list at once); no: sends nothing |
| `X:sent(id[, "map"])` | | removes the bundle written for that answer, or the map's copy sent with the list |
| `X:wants(id, from[, hex])` | | whether this side waits for files on that id from that sender (and asked for that file); changes nothing |
| `X:wants_map(id, from)` | | true when it waits for the map sent with that list, false when it never will, nil before the player answers; changes nothing |
| `exchange.prompt(q)` | a question | the prompt's lines: the question, the map, each entry's provenance |

A question `q` is `{id, sender, map, entries, missing, trusted, map_sent, map_held}`;
once ready, `q.map_file` is where a map sent with the list is kept
(`<data>/maps/<its name>/`, or the link the player already had).

## Messages

| Kind | Fields | Sent by |
|------|--------|---------|
| `list` | `text` (the list file), `map = {name, path}` (the map file, when it goes with the list) | the sharer |
| `want` | `hashes` (only those the store lacks) | the receiver, after yes |
| `files` | `files = {{name = <64 hex>, path}}` | the sharer |
| `map` | `map = {name, path}`: a list's map that came after it | the glue, when the map has come |

Every message also has `from` (the transport's sender) and `id`.

## What is refused

- A want from anyone but the player the list was offered to, or for a
  hash that isn't in that list.
- Files nobody asked for, or from another sender; an attachment whose
  name isn't a hash this side asked for (so never a path).
- A list that isn't plain data (it is read, never run), or a file that
  doesn't match its hash: the whole list is refused.
- A map sent with a list under any name but the list's map hash, or whose
  bytes don't have that hash: the whole list is refused, and the map
  isn't stored.

## Not here

Using a list for one game, and the lobby's prompt for "come check out my
map" (a hosted map, whose list comes with the join), are the W client's,
its issue 1110 (609a, "After the editor-and-client split"). The rules
above carry over to it as a design.
