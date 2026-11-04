# rmail_hook.lua

The glue between `exchange.lua` and rmail (issues 609a, 609b). 609a wrote
it against an assumed contract. 609b read rmail and replaced the stub.
Which assumptions held is in `issues/completed/609b-rmail-glue.md`.

rmail's hooks are programs that it runs in the background, and they can't
answer it. So two small hook scripts note each share mail and each
arriving file in `<data>/share-mail/`, and the editor or launcher calls
`C:poll(X)`. Nothing calls it on a timer: share mail only comes when a map
is shared, so it is called when the editor or launcher opens, when the
person asks it to look, and after they answer a question (so the
list's consent forms are answered then). Between calls the notes just wait.

| Function | Takes | Gives |
|----------|-------|-------|
| `hook.connect{ config, data }` | rmail's config file, the player's data folder | a connection `C`, or nil and why |
| `C:install([chain])` | hooks to chain (default: those the config names) | the two config lines for the person to add; writes the scripts |
| `C:hooked()` | | true, or false and the hooks missing from rmail's config |
| `C:transport()` | | a transport for `exchange.new` that writes outbox files |
| `C:poll(X)` | an exchange | what happened: `{ event, from, id, result, err }` each (`event`: receive, consent, files, sent) |
| `hook.transport(rmail)` | an in-process `send` | a transport (the tests' fake) |
| `hook.on_receive(X)` | an exchange | an in-process `on_receive(mail)`: `"accept"`, `"decline"`, or nil |
| `hook.encode(msg)` / `hook.decode(mail)` | | a share message as a mail, and back (nil for anything malformed) |
| `hook.read_form(text)` | a consent form's text | `{ from, attached, file }`, or nil when it isn't pending |

A share mail's subject is `wete-share-list-<id>` (rmail turns spaces into
dashes): a list is the only share message. Its body is the list file,
after a first line `map: <hex>.<ext>` when the map goes with it. Its
attachments are the map and every file the list names, each named by
its hash's hex. Nothing is sent back: the receiver takes only the files
it lacks by answering their consent forms.

What `C:poll` does:

- It hands lists to the exchange, which asks the player once.
- It answers each consent form on a list's mail after the player's
  answer: accepted for a file (or the map) their store lacks, denied for
  the rest, and for all of them on no. A file the list doesn't name is
  denied at once. Forms on other mail are left alone.
- It holds the list mail until every file it wants has come, then hands
  them over together; the exchange checks the map against the list's
  hash and every file against its own, and keeps the list as a pack.
- It deletes share mail once handled, which tells the sender's rmail.
- It frees the sharer's copies once rmail drops the outbox file.
- It refuses mail from listen-only contacts, and want or files mails
  (no longer share messages).

The config is never edited here. A body over 128 KiB is refused, rather
than letting rmail turn it into an attachment.
