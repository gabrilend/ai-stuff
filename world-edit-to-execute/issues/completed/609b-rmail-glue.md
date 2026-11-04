# Issue 609b: rmail Glue

**Phase:** 6
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 609a (the exchange and the assumed hook)
**Blocks:** 609c (the lobby prompt)
**Uses:** rmail (gabrilend/r-mail), its own repository; read, not changed

---

## Current Behavior

`src/share/exchange.lua` carries a shared list between two players over
any transport, and asks the player first. `src/share/rmail_hook.lua`
connects it to rmail, but it was written against an *assumed* hook
contract (see 609a's notes), because rmail wasn't attached to this
repository, and `hook.connect()` is a stub.

## Intended Behavior

- Lists, wants and files travel over the real rmail.
- Each of 609a's five assumptions is checked against rmail's code and
  docs, and the glue follows what rmail really does.
- The prompt on screen moves to 609c: it needs a screen to be checked.

**After the editor-and-client split (2026-11-04).** Playing happens in
the W client (issue 913), and using a list during a game, the lobby
prompt included, is the W client's (its 1110), for "come check out my
map", where the host's list comes with the join (609, "A list travels
only with its map"). The rmail glue stays here, for "check out my map":
the map and its list in one message, asked about once by the editor or
launcher, then stored.

## Suggested Implementation Steps

1. Read rmail's message, attachment and hook docs
   (`docs/.templates/attachments.md`, `docs/.templates/scripting-tutorial.md`).
   Check the five assumptions in 609a's contract.
2. Replace the `hook.connect()` stub with the real contract, keeping the
   transport interface so the tests still run against the fake.
3. Write up anything rmail lacks as a proposed rmail change (rmail itself
   is not changed here).

## Acceptance Criteria

- [x] A list sent over rmail arrives and is checked (through a fake of
      rmail's daemon that works on the same files rmail does; not yet run
      against a live rmail)
- [x] Each assumption is marked held or not, with the rmail file that shows it
- [x] The in-process fake from 609a still passes

## Implementation Notes (2026-11-03)

Read from a clone of gabrilend/r-mail at `c25a4a7`. Nothing was fetched
beyond it, and rmail was not changed.

- `src/share/rmail_hook.lua`: `hook.connect{ config, data }` gives a
  connection `C`. `C:install()` writes two hook scripts and gives the
  config lines for the person to add. `C:transport()` writes outbox files.
  `C:poll(X)` reads what the hooks noted, answers consent forms, and
  hands messages to the exchange. The in-process `hook.transport(rmail)`,
  `hook.on_receive(X)`, `encode` and `decode` stay for the fake.
- `src/share/exchange.lua`: one read-only method, `X:wants(id, from, hex)`,
  so the glue can answer a consent form before the files message is whole.
- `src/tests/test_share_rmail.lua`: 46 tests. Two mailboxes laid out like
  rmail's, and a fake of rmail's daemon that sends outbox files, runs the
  configured hooks with rmail's arguments, writes consent forms in rmail's
  words, reads the answers back, saves accepted files and drops a read
  message from the sender's outbox.
- `src/tests/test_share_exchange.lua`: still 32. The stub's test now
  checks the real `connect` on a missing mailbox, and the subject check
  uses the dashed form.

### The five assumptions, checked

| # | 609a assumed | Held? | Shown by (r-mail) |
|---|--------------|-------|-------------------|
| 1 | rmail calls `on_receive(message, rmail)` with a table, attachments saved | No | `docs/.templates/scripting-tutorial.md` (Hook interface); `rmail.lua` 2248 and 2153, 4973 |
| 2 | `from` is authenticated | Yes, except listen-only contacts | `rmail.lua` `trial_decrypt` 3006 and 7839–7890; `contactfile.listens` 1069; `README.md` (Listen-only contacts) |
| 3 | the hook sends with `rmail.send{...}` | In substance; by writing a file | `rmail.lua` `_scan_outbox_header` 2342, `parse_outbox_file` 3607; `README.md` |
| 4 | consent through `on_receive`'s answer | No | `rmail.lua` 4168–4214 (the form), `check_consent_pending` 4277; `helpers/raccept.sh`; `docs/.templates/attachments.md` (The consent flow) |
| 5 | free-text subjects, bodies to 4 MiB | No | `rmail.lua` `sanitize_filename` 588; 6027 (#308) |

1. **A hook is a program, not a function.** rmail runs the executable
   its config names with shell arguments: `on_receive` gets sender,
   subject and the inbox file. It runs in the background, and its output
   is ignored. Attachments come later, one `on_package` (sender, file
   name, saved path) per file, after the person's consent. So the glue's
   hooks only note each event in `<data>/share-mail/`, and the game reads
   those notes.
2. **The sender is authenticated.** rmail finds the contact by decrypting
   the request with each contact's token-derived key, so `$1` is a
   contact that holds the shared token. The exception is a contact marked
   `listen = true`: a public door whose token anyone may hold, which may
   only send plain messages up to 64 KiB and is never sent to. Its share
   mail is refused.
3. **Sending is a file.** A message is a file in `outbox/` named by its
   subject, with `to:` and `attach:` lines and then the body. Each `to:`
   gets the `attach:` lines below it. The text is held back until every
   attached path exists. An outbox file stays until each recipient has
   deleted their copy. Editing it sends an edit, which is why the glue
   never writes over one.
4. **No hook can answer consent.** Each attachment puts a form in the
   inbox (`<message>-<file>-consent-to-download-form`) ending in `accept`
   and `deny`. Deleting `deny` accepts, and deleting the form or `accept`
   declines. The glue answers the form as `raccept` does, and only for a
   file the exchange asked that sender for, on that files message.
5. **Subjects become file names, and bodies have a size limit.** rmail turns a
   subject into an inbox file name, and spaces into dashes, so
   "wete-share list <id>" arrives as "wete-share-list-<id>". An id is at
   most 64 characters, so names stay well under file-name limits. A body
   over 128 KiB is sent as an attachment needing consent (#308), so the
   glue refuses to send one that long.

### Decisions made while building

1. **Subjects are sent in the form rmail delivers them**
   (`wete-share-<kind>-<id>`). `decode` still reads 609a's spaced form.
2. **The hooks only take notes, and the game does the rest in
   `C:poll`.** rmail's hooks run in the background and can't reach a
   running game, so each writes one record, and the game polls. A record is
   written under a dot name and renamed, and one with a newline smuggled
   into a value has too many lines and is dropped.
3. **The config is never edited here.** `C:install()` writes the scripts
   and gives the two lines. The person adds them and restarts rmail, and
   `C:hooked()` says whether they're in. A hook the config already names
   is chained, so it still runs after ours (rmail has one script per
   hook).
4. **A files message waits for its files.** Its body names the files
   (each a hash's hex), because rmail doesn't tell `on_package` which
   message a file came with. A file is matched by sender and name, and the
   message goes to the exchange once every named file has come.
5. **Consent is answered only for what the exchange asked for.** A form
   is accepted when the exchange is waiting on that files message from that
   sender and asked for that file; otherwise it is denied. Forms on any other mail are
   the person's, and are left alone. Files for a list the player declined
   are refused, and their forms denied.
6. **Handled share mail is deleted.** Deleting is what tells the sender's
   rmail the message was read, and it then drops its outbox file. A files
   message is deleted only after its files arrive, and the files are
   deleted after the exchange has copied them, since rmail never deletes
   a message's files (#306). The sharer's bundle is freed (`X:sent`) once its
   outbox file is gone.
7. **Senders must be contacts and not listen-only.** A listen-only contact
   is a door anyone may knock on, and it can't be sent the want back.
8. **The data folder's path must be plain** (no spaces or shell
   characters). rmail runs a hook without quoting its path and expands glob
   characters in `attach:` lines, so `connect` refuses such a folder.
9. **Bodies are capped at rmail's 128 KiB** (`hook.MAX_BODY`). A longer
   list or want raises an error rather than becoming an attachment the
   other side would have to consent to by hand.
10. **State stays in memory, as in 609a.** A record waits in the drop
    folder and the mail in the inbox until the next poll, so a list that
    arrives while the game is closed is handled when it opens. A want or
    files message for an exchange from before a restart is refused.

### Proposed rmail changes (not made; rmail is its own repository)

1. **An `on_consent` hook**: sender, the message's inbox name, the file
   name, the expected size and the form's path, answering `accept`,
   `deny` or nothing (ask the person) on its output, synchronously. The glue
   could then answer consent without scanning the inbox for forms.
2. **The message on `on_package`**: a fourth argument with the message's
   inbox name or id, so a file is tied to its message without matching by
   sender and name.
3. **More than one script per hook** (a list in the config), so a program
   adds its hook without chaining the person's.
4. **A way to send that stays out of the person's view**, such as a
   hidden outbox or subjects routed to a folder of their own. Today share
   mail and its forms show in the inbox (and on the phone) until the game
   polls.

### After the editor-and-client split (2026-11-04)

Two things in these notes read differently under the owner's decisions
of 2026-11-04 (609, "Where each part runs" and "A list travels only with
its map"). The code is unchanged by this note.

- **Who reads the notes, and when.** Decision 2 has "the game" poll the
  hooks' notes. Playing is now the W client's, and the owner: "we only
  send models and such when the map that includes them is shared ... so
  we don't need to check the rmail inbox every 5 seconds." `C:poll` stays
  as the call that reads what the hooks noted; what calls it here is the
  editor or the launcher, not a game loop on a timer. When they call it is
  still to be settled.
- **The map travels with its list.** The glue sends a list that names its
  map by hash. For "check out my map" the map file and the list go in one
  message; adding the map file as an attachment of the list message is
  not built yet.
