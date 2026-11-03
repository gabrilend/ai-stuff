# exchange.lua

Carries a shared list (issue 609a) between two players over a transport,
with the one consent step before anything is stored or applied. The
transport is anything with `send(to, message)`; `rmail_hook.lua` is the
one for rmail.

| Function | Takes | Gives |
|----------|-------|-------|
| `exchange.new(opts)` | `data`, `me`, `transport`, `pack` (the sharer's files), `consent(q)` (default: nil, ask later), `on_ready(P, q)`, `on_problem(id, what)`, `name_for(q)`, `store` | an exchange |
| `X:offer(to, l)` | a player, a list | sends the list; the id its answers carry |
| `X:on_message(msg)` | a delivered message | `"asking"`, `"waiting"`, `"declined"`, `"ready"`, `true` (files sent); or nil and why it was refused |
| `X:pending()` | | the questions waiting for the player |
| `X:answer(id, "yes" or "no")` | | yes: asks for the missing files only (or applies at once); no: sends nothing |
| `X:sent(id)` | | removes the bundle written for that answer |
| `exchange.prompt(q)` | a question | the prompt's lines: the question, the map, each entry's provenance |

A question `q` is `{id, sender, map, entries, missing, trusted}`.

## Messages

| Kind | Fields | Sent by |
|------|--------|---------|
| `list` | `text` (the list file) | the sharer |
| `want` | `hashes` (only those the store lacks) | the receiver, after yes |
| `files` | `files = {{name = <64 hex>, path}}` | the sharer |

Every message also has `from` (the transport's sender) and `id`.

## What is refused

- A want from anyone but the player the list was offered to, or for a
  hash that isn't in that list.
- Files nobody asked for, or from another sender; an attachment whose
  name isn't a hash this side asked for (so never a path).
- A list that isn't plain data (it is read, never run), or a file that
  doesn't match its hash: the whole list is refused.
