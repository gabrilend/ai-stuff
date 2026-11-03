# rmail_hook.lua

The glue between `exchange.lua` and rmail (issue 609a). rmail lives in its
own repository, not attached here, so this is written against an
**assumed** hook contract (written out in the 609a issue). `hook.connect()`
is a stub that says so. When rmail is read, only this file should change.

| Function | Takes | Gives |
|----------|-------|-------|
| `hook.connect()` | | nil and why (the stub) |
| `hook.transport(rmail)` | rmail's `send` | a transport for `exchange.new` |
| `hook.on_receive(X)` | an exchange | rmail's `on_receive(mail)`: `"accept"`, `"decline"`, or nil for mail that isn't ours |
| `hook.encode(msg)` / `hook.decode(mail)` | | a share message as a mail, and back (nil for anything malformed) |

A share mail's subject is `wete-share <kind> <id>`. A list travels as the
body, a want as one hash a line, files as attachments named by hash.
