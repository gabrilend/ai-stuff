# rmail_hook.lua

The glue between `exchange.lua` and rmail (issues 609a, 609b). 609a wrote
it against an assumed contract. 609b read rmail and replaced the stub.
Which assumptions held is in `issues/completed/609b-rmail-glue.md`.

rmail's hooks are programs that it runs in the background, and they can't
answer it. So two small hook scripts note each share mail and each
arriving file in `<data>/share-mail/`, and the editor or launcher calls
`C:poll(X)`. Nothing calls it on a timer: share mail only comes when a map
is shared, so it is called when the editor or launcher opens, when the
person asks it to look, and after they answer a question (so the map's
consent form is answered then). Between calls the notes just wait.

| Function | Takes | Gives |
|----------|-------|-------|
| `hook.connect{ config, data }` | rmail's config file, the player's data folder | a connection `C`, or nil and why |
| `C:install([chain])` | hooks to chain (default: those the config names) | the two config lines for the person to add; writes the scripts |
| `C:hooked()` | | true, or false and the hooks missing from rmail's config |
| `C:transport()` | | a transport for `exchange.new` that writes outbox files |
| `C:poll(X)` | an exchange | what happened: `{ event, from, id, result, err }` each (`event`: receive, consent, files, map, sent) |
| `hook.transport(rmail)` | an in-process `send` | a transport (the tests' fake) |
| `hook.on_receive(X)` | an exchange | an in-process `on_receive(mail)`: `"accept"`, `"decline"`, or nil |
| `hook.encode(msg)` / `hook.decode(mail)` | | a share message as a mail, and back (nil for anything malformed) |
| `hook.read_form(text)` | a consent form's text | `{ from, attached, file }`, or nil when it isn't pending |

A share mail's subject is `wete-share-<kind>-<id>` (rmail turns spaces
into dashes). A list travels as the body, and a want as one hash per
line. A files message names its files in the body, and the files are
its attachments. For "check out my map" the list's body starts with
`map: <hex>.<ext>`, and the map file, named so, is the list mail's one
attachment.

What `C:poll` does:

- It hands lists and wants to the exchange.
- It holds a files message until every named file has come, then hands
  it over.
- It holds a list mail that carries its map until the map has come (or
  isn't wanted), then hands the map over; the exchange checks it against
  the list's hash.
- It accepts a consent form only for a file the exchange asked that
  sender for, and denies the rest. A map's form waits until the player
  has answered, and is accepted only on yes when they don't hold that
  map already. Forms on other mail are left alone.
- It deletes share mail once handled, which tells the sender's rmail.
- It frees the sharer's bundle once rmail drops the outbox file.
- It refuses mail from listen-only contacts.

The config is never edited here. A body over 128 KiB is refused, rather
than letting rmail turn it into an attachment.
