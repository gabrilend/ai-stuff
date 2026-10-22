# What rmail provides, and what it does not

guide-feature uses rmail (`/home/ritz/programs/r-mail/`) to move text between
machines. This document lists the rmail behaviours the design relies on, and
the limits it works around. rmail's own documentation is the authority; the
references below say where each fact comes from, so this page can be checked
against rmail when rmail changes.

## What the design relies on

**A message is a file.** A file written into a mailbox's `outbox/` is sent.
Its first lines are headers, `to: <contact>` one per recipient, then a blank
line, then the body. The file name is the subject. (rmail `README.md`, "How it
works".)

**A living message.** When the author edits the body of an outbox file, the
new body is sent to every recipient and replaces their inbox copy. The thinker
uses this for its frame and the page keeper uses it for the page, so each
side's inbox always holds exactly one current file per author, not a growing
pile. (rmail `README.md`, "Editing works one way".)

**Hooks run on arrival.** rmail calls a script, with plain arguments, when
something arrives (rmail `docs/scripting-tutorial.md`, "Hook interface"):

| Hook | When | Arguments | Blocks rmail? |
|---|---|---|---|
| `on_receive` | after a new message is written to `inbox/` | sender (string), subject (string), path of the inbox file (string) | no, runs in the background |
| `on_update` | when the author's edit arrives, before it is written | sender (string), path of the inbox file still holding the old body (string), the new body (string) | yes; whatever it prints replaces the new body, printing nothing keeps it |

The first frame from a voice arrives through `on_receive`; every frame after
that is an edit and arrives through `on_update`. The page keeper's hooks
therefore handle both, and must hand the frame over without waiting for the
page keeper to finish, because `on_update` holds rmail up while it runs.

**Owed edits are delivered late, not lost.** An edit to a recipient that is
offline is kept and the newest version is delivered when the recipient is
reached. Intermediate versions are skipped. For guide-feature this is the
right behaviour: only the newest frame is valid anyway.

**Encryption.** Every message is encrypted with AES-256-GCM using a shared
secret per contact pair, kept in each mailbox's `contacts` file. That file is
not encrypted, and it stays out of this repository.

## What it does not provide, and what is done about it

**Edits by a recipient do not travel.** A voice cannot edit the page and a
kuvalu edit to a voice's frame does not reach the voice. This is why there is
no shared document. Each author owns one living message, and the page keeper
rebuilds the page from the newest frame of each voice.
(`docs/architecture.md`, "Why rmail carries the messages".)

**Delivery is paced, not instant.** Each contact is sent to at most every 30
seconds, with plus or minus 30 seconds of random spread. A failed contact
waits 6 more minutes per failure, up to 2 hours. A change in the outbox is
noticed at once, but it still waits for that contact's timer. (rmail
`docs/protocol.md`, "Sync timing".) The page therefore advances on a rhythm of
tens of seconds. A thinker that writes faster than that only means some of its
frames are replaced before they are sent.

**Intermediate frames can be skipped.** Because only the newest owed edit is
delivered, the page keeper may never see some frames a voice wrote. Each frame
carries its own number so the page keeper can count the gaps
(`docs/frame-format.md`), and the gap count goes into the goodbye receipt.

**Body size.** Listen-only contacts are limited to 64 KiB per body. The
voices and kuvalu are ordinary contacts, but the page is still kept well under
that size so it fits in a small language model's context on the voices (see
`docs/datapath-thinker.md`).

**rmail's own needs on the fg-sora machines.** The rmail daemon needs LuaJIT
(or Lua 5.3/5.4), LuaSocket and OpenSSL, compiled by its `scripts/install.sh`.
The fg-sora machines have a minimal BusyBox userland, so the install is its
own piece of work, covered in phase 4.
