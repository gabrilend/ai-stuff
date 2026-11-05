# What rmail provides, and what it does not

guide-feature uses rmail (`/home/ritz/programs/r-mail/`) to move canvases
between the four machines. This document lists the rmail behaviours the
design relies on and the limits it works around. rmail's own documentation
is the authority, and each fact names where it comes from, so this page can
be checked again when rmail changes.

## What the design relies on

**A message is a file.** A file written into a mailbox's `outbox/` is sent.
Its first lines are `to: <contact>`, one per recipient, then a blank line,
then the body. The file name is the subject. (rmail `README.md`, "How it
works".)

**A living message.** When the author edits their outbox file, the new body
is sent to every recipient and replaces their inbox copy. kuvalu keeps one
outbox file, `the-canvas`, addressed to all three voices, and rewrites it
for every version. Each voice keeps one outbox file, `canvas`, addressed to
kuvalu, and rewrites it every turn. Each inbox therefore holds one current
file per author, not a growing pile. (rmail `README.md`, "Editing works one
way".)

**Hooks run on arrival** (rmail `docs/scripting-tutorial.md`, "Hook
interface"):

| Hook | When | Arguments | Blocks rmail? |
|---|---|---|---|
| `on_receive` | a new message has been written to `inbox/` | sender, subject, inbox file path | no, it runs in the background |
| `on_update` | the author's edit has arrived, before it is written | sender, inbox file path (old body still in it), new body | **yes**. What it prints replaces the new body; printing nothing keeps it |

The first canvas from an author arrives through `on_receive`, and every one
after that through `on_update`, because it is an edit of the same living
message. Both hooks are set on every mailbox, and on both kinds of machine
they do the same thing: put the new body where a Lua program will take it,
start that program in the background if it is not running, print nothing,
and exit at once. On a voice, the turn itself takes seconds to minutes, far
too long to hold `on_update`, which would hold up rmail.

**Owed edits are delivered late, not lost, and only the newest.** An edit to
an offline recipient is delivered when it is reached, and intermediate
versions are skipped. Each voice only ever needs the newest canvas, so this
is the right behaviour. The voice's turn counter shows the gaps on kuvalu's
side.

**Encryption.** AES-256-GCM with a shared secret per pair of mailboxes, kept
in each mailbox's `contacts` file, outside this repository.

## What it does not provide, and what is done about it

**A recipient's edits do not travel.** No machine can edit another's
message. That is why each author owns exactly one living message, and kuvalu
alone builds the shared canvas.

**Delivery is paced by rmail's timers.** By default each contact is sent to
at most every 30 seconds or so, and backs off after failures (rmail
`docs/protocol.md`, "Sync timing"). A contact that has just delivered to a
mailbox is due at once, so kuvalu answers a voice's canvas with the next
version straight away, but the voice's next canvas waits for its own timer.
The rehearsal (305) measures this. The owner's view: "we can adjust things
like this on a per-implementation basis." The pacing lives in rmail's own
code and settings, and in the hook scripts and Lua programs, which are meant
to be edited per setup.

**Turns overlap with new canvases.** A new canvas can arrive while a voice's
turn is running. The turn hook keeps only the newest waiting canvas, and the
turn runner starts again on it when the current turn ends
(`docs/datapath-voice-turn.md`). A voice never runs two turns at once.

**Three voices send kuvalu the same subject.** rmail names an arriving
message after its subject, and when another sender's message already has
that name it uses `<subject>-from-<sender>` (rmail `rmail.lua`,
`handle_deliver`). In the guide mailbox, the first voice's canvas is
therefore `inbox/canvas` and the others' `inbox/canvas-from-fg-sora-2` and
so on. `on_update` passes only the inbox file, so the arrival and turn
hooks read the subject back from both forms. A name numbered `-2`, `-3`
is a different message and is left alone (issues 302, 305).

**rmail's own needs on the mini-computers.** LuaJIT (or Lua 5.3/5.4),
LuaSocket and OpenSSL, normally compiled by rmail's `scripts/install.sh`. The
mini-computers have a BusyBox userland, so installing rmail there is its own
piece of work (phase 7).

## How the mailboxes are made

Every mailbox, kuvalu's guide mailbox, the voices' and the rehearsal's
stand-ins, is made by `scripts/make-mailboxes` from a mailbox set
(`input/mailboxes`; `src/031-mailboxes.lua`, issue 301). It writes rmail's
`config` and `contacts` files as rmail reads them (rmail `README.md`,
"Configuration"), with a new secret for each pair of mailboxes, and adopts
a mailbox already there without overwriting anything in it. The config
turns rmail's port mapping off (`auto_port_forward = false`): the router's
ports are the owner's.

Both hooks run the mailbox's own `hooks/guide-hook` with a first word,
`receive` or `update`, written into the config line. rmail runs a hook
path through the shell without quoting it (rmail `rmail.lua`, `run_hook`),
so that word reaches the hook as its first argument, and the hook never
has to guess which call it is from the shape of the others.

rmail's check of its public address has no switch to turn it off (rmail
`rmail.lua`, `check_public_ip`). `docs/network.md` wants one; it is
rmail's to add.
