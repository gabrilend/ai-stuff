# 041-stand-in-carrier — info

rmail's part in the rehearsal (issue 305), played on one machine by
reading and writing the mailbox folders directly, by rmail's own rules
(main, and #215 for `on_update`). It is for the rehearsal and its tests;
the real machines run rmail.

- Outbox files are `to:` lines, a blank line and the body, and the file
  name is the subject. Dot names are skipped.
- A contact is reached by the `ip` and `port` in the sender's contacts,
  only on this machine (127.x or localhost). The receiver knows the sender
  as its contact holding the same token.
- The first delivery is `inbox/<subject>`, or `<subject>-from-<sender>`
  when another sender's message has that name, then `-2`, `-3` and so on,
  with `on_receive` in the background.
- Later changes are edits. Only the newest body is carried. `on_update`
  is waited for, with the body as an argument and on stdin (the argument
  is empty over 64 KiB). Its output replaces the body. A non-zero exit
  refuses the edit, which is tried again later.
- A receiver's deleted inbox file is not made again.
- Timers are per contact: due at the start, then `pace` ± `jitter`
  seconds after an exchange, and due at once for a contact that has just
  delivered.

| Function | Meaning |
|---|---|
| `new(opts)` | a carrier: `folders`, `pace`, `jitter`, `random`, `now`, `event`, `scratch` |
| `carrier:round()` | carries what is due now; the number of deliveries |
| `parse(text)` | an outbox file's `to:` list and body, or nil |
| `file_name(subject)` | rmail's file name for a subject |
