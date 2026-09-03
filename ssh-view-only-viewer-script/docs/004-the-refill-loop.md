# The refill loop

The second vision: the draw delivered by
[r-mail](../../../programs/r-mail/README.md), with no SSH involved.

## Topology

One mailbox on the server. Three contacts, one per viewer machine. Each
viewer machine runs its own r-mail daemon with its own inbox, on the LAN,
with LAN addresses in the contacts files — no port forwarding, no public
IP, nothing the outer router ever learns about.

```
SERVER                            VIEWER MACHINES
  one mailbox                       A: own daemon, own inbox
    outbox/  <-- written by hook    B: own daemon, own inbox
    contacts: A, B, C               C: own daemon, own inbox
                    \
                     ---- AES-256-GCM over LAN TCP ---->
```

Because each viewer's mailbox is on its own machine, there is exactly one
mailbox per machine and the multiple-mailbox install collision does not
arise. See [the blockers note](../notes/blockers.md) for why that matters
and when it would come back.

## The cycle

```
  1. hook asks the draw for a file for viewer A
  2. hook writes  outbox/<subject>  containing:
                      to: A
                      attach: <the drawn path>
                      <one line naming the file>
  3. inotify on outbox fires; daemon delivers immediately
  4. A's daemon raises a consent request in A's inbox
  5. A accepts (by hand, or by an on_receive hook on A's side)
  6. chunks transfer; file lands in A's attachments directory
  7. A reads it. A deletes the message from their inbox.
  8. A's daemon POSTs /delete to the server
  9. server strips the "to: A" line from the outbox file.
     It was the only recipient, so the outbox file is removed.
 10. server fires on_delete with "A"
 11. back to step 1
```

## The three mechanisms this leans on

All three already exist in r-mail. None of them are modified.

**Backward deletion propagation.** When a recipient deletes a message
from their inbox, their daemon tells the sender, and the sender strips
that recipient's `to:` line. When the last `to:` line goes, the outbox
file itself is deleted — `remove_recipient_from_file` in `rmail.lua`
calls `os.remove` on the file at that point. With one recipient per
outbox file, a viewer's deletion cleans the server's outbox completely,
leaving an empty slot for the next draw.

**The delete hook fires on the sender's side.** In `handle_delete`, the
branch commented *"recipient telling us they deleted something we sent"*
runs `on_delete` with the recipient's name before removing them. That
single argument — who deleted — is exactly and only what the refill needs
to know. The hook does not need to know which file; it needs to know
which viewer to feed.

This is worth stating plainly because the same hook is too thin for other
purposes: it passes no subject, no filename, and no message id. For a
loop whose whole question is *which viewer said next*, thin is sufficient.

**Per-recipient attachments.** An `attach:` line binds to the `to:` line
above it, so one outbox file gives one viewer one file. The refill never
needs to reason about who else is receiving what.

## Consent is the friction

r-mail asks the recipient before transferring any file: a consent request
appears in their inbox with `accept` and `deny` lines, and they delete one.
For a loop that fires every time someone wants the next file, that is a
second manual gesture on top of the deletion — which breaks the promise
that delete is the only verb.

The `on_receive` hook on the *viewer's* side closes this: it runs in the
background with the sender, subject, and on-disk path, so a short script
can recognise a consent request from the server and write `accept` itself.

That is software on the viewer's machine, which is a real cost — the
tooling vision was attractive partly because it required nothing on their
end. Whether the viewers run an auto-accept hook, or accept by hand each
time, is unsettled.

## Open questions

- **Does the viewer auto-accept?** Without it, "delete is the only verb"
  is false — there are two verbs, and one of them is editing a consent
  file. With it, the viewer runs our script, and the vision of a machine
  that needs nothing installed is gone.
- **Where do the received files go, and who removes them?** Deleting the
  message does not delete its attachment; r-mail decided deliberately that
  attachments are user-owned files. So the viewer's attachments directory
  accumulates every file ever drawn, and "one file at a time" is only true
  of the inbox, not of the disk.
- **What does the server do when the draw runs dry?** Sending nothing
  leaves the viewer holding an empty inbox with no explanation. Sending a
  message that says so means the well running dry looks exactly like an
  ordinary delivery, and deleting *that* asks for another.
