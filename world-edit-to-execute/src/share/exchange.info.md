# exchange.lua

Carries a shared list (issues 609a, 609b) between two players over a transport,
with the one consent step before anything is stored or kept, for "check
out my map": a map and its list given to keep. The
transport is anything with `send(to, message)`; `rmail_hook.lua` is the
one for rmail.

| Function | Takes | Gives |
|----------|-------|-------|
| `exchange.new(opts)` | `data`, `me`, `transport`, `pack` (the sharer's files), `consent(q)` (default: nil, ask later), `on_ready(pack, q)` (a list was kept, as the pack in folder `pack`), `on_problem(id, what)`, `name_for(q)`, `store` | an exchange |
| `X:offer(to, l[, map])` | a player, a list, the map file it names | sends one message: the list, a copy of every file it names and of the map when given (an error when the map's hash isn't the list's); its id |
| `X:on_message(msg)` | a delivered message, or the glue's files message | `"asking"`, `"waiting"`, `"declined"`, `"ready"` (kept as a pack); or nil and why it was refused |
| `X:pending()` | | the questions waiting for the player |
| `X:answer(id, "yes" or "no")` | | yes: takes only the files the store lacks and the map unless held, and keeps the list once they're in (at once in process, or when nothing is lacking); no: takes nothing. Nothing is sent back either way |
| `X:sent(id)` | | removes the copies written for that offer |
| `X:wants(id, from, hex)` | | true when it will take that file sent with that list, false when it never will, nil before the player answers; changes nothing |
| `X:wants_map(id, from)` | | the same for the map sent with that list |
| `X:awaiting(id, from)` | | the names (files' hex, the map's name) still to come, `{}` when nothing more is wanted, nil before the answer; changes nothing |
| `exchange.prompt(q)` | a question | the prompt's lines: the question, the map, each entry's provenance |

A question `q` is `{id, sender, map, entries, missing, trusted, map_sent, map_held}`;
once ready, `q.map_file` is where a map sent with the list is kept
(`<data>/maps/<its name>/`, or the link the player already had).

## Messages

| Kind | Fields | Sent by |
|------|--------|---------|
| `list` | `text` (the list file), `files = {{name = <64 hex>, path}}` (every file it names), `map = {name, path}` (the map file, when it goes with the list); a path is nil when the file comes later (over rmail) | the sharer |
| `files` | `files`, `map`: what came of those the receiver wants | the glue, once they have all come |

Nothing travels from the receiver to the sharer: the receiver's mail
program takes only the files it wants (over rmail, by its consent forms).

Every message also has `from` (the transport's sender) and `id`.

## What is refused

- Files from anyone but the list's sender, or that the player didn't say
  yes to; an attachment whose name isn't a hash the list names (so never
  a path).
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
