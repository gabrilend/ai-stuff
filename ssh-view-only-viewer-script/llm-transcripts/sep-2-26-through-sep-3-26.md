# Conversation Summary: 66b27888-4f43-4a8f-af72-9b58f8ef77e6

Generated on: 2026-09-02 17:13:20

--------------------------------------------------------------------------------

### User Request 1

hi can you tell me what this project is about?


--------------------------------------------------------------------------------

### Assistant Response 1

I'll look at the project directory.


It's a seed — one file, no code yet. The whole project is a four-line note at
`vision` (which by your own convention would live at `notes/vision`, not the
project root):


> an ssh username with the other person's name as a password auto-generated

> temporarily

> upon receiving a certain kind of ping.

> a packet sent with a small arrangement

> I'm dreaming


Read against the directory name — **ssh-view-only-viewer-script** — that
describes a machine with three parts:


**The trigger.** A packet arrives with "a small arrangement" — a specific byte
pattern in its payload, or a specific sequence of connection attempts across
ports. That's port-knocking: a listener on the host watches traffic (a raw
socket, or an ICMP echo handler, or firewall log lines) and does nothing at all
until it sees the arrangement it was waiting for. Nothing is listening in the
sense of an open TCP port, so from outside there's no door to find.


**The credential.** On seeing that pattern, the host mints a login that did not
exist a moment earlier: username is one party's name, password is the *other*
party's name. The pairing is the interesting part — neither person alone holds
a whole credential, and it's temporary, so it decays back to nothing after a
window closes.


**The grant.** "View-only viewer" — what the credential buys is watching, not
doing. In SSH terms that's a forced command in `authorized_keys` or a login
shell that isn't a shell: it attaches you to a terminal multiplexer session in
read-only mode, or replays a recorded terminal stream, and your keystrokes go
nowhere. The visitor sees the screen; the screen does not see the visitor.


Two things the note leaves open, and both change the build:


1. **What carries the arrangement?** An ICMP echo payload is invisible to most
   port scans but needs a raw socket and root to read. A knock sequence across
   TCP ports is readable straight out of firewall logs with no privilege at all,
   but it's slower and noisier. Which one you dream of decides whether this is a
   daemon or a log-tailing script.


2. **Where do the two names come from?** For the host to check "the other
   person's name" as a password, it has to already know the pair. So is there a
   table of who may watch whom, or is the name itself derived from the packet
   — meaning the arrangement *is* the identity, and the credential is just a
   readable form of it?


--------------------------------------------------------------------------------

### User Request 2

we should deliver the contents of the files, to be viewed and such using the
viewer's local environment capabilities. We can do this using rmail, but I'm not
sure if it's the right fit yet - feel free to pitch me a design. there's a
vision-2 document btw.


--------------------------------------------------------------------------------

### Assistant Response 2

`rmail` isn't on this machine — only `/usr/bin/mail`, which is a symlink to
`mailx`. So this would be a new dependency, not something already sitting there.


## What rmail actually does


`rmail` is the last link in the old UUCP mail chain. It reads one complete
message from standard input — headers, blank line, body — takes recipient
usernames as command-line arguments, and hands the message to the local delivery
agent, which appends it to `/var/mail/<username>`. That spool file is **mbox**
format, and mbox is almost nothing: messages concatenated into one plain text
file, each starting with a line that begins `From ` (no colon) followed by a
sender and a date. That separator line is the entire structure.


The appeal is real and it's exactly what you said — you never write a viewer.
You push bytes into the recipient's spool and whatever that machine already has
(mailx, mutt, Emacs Rmail mode, a five-line shell script) becomes the viewer.
Delivery and viewing are separated by a file format instead of by an API.


## Where it breaks for this vision


**mbox only grows.** Your vision-2 is about rotation — "every 30 minutes
they'd switch", "every 3 minutes they'd change N% of the files". mbox has no
concept of expiry. To rotate you'd have to rewrite the spool file in place, and
rewriting an mbox while a reader has it open is the classic corruption case:
reader and writer race over the same byte offsets, and locking (dotlock, flock,
both, disagreeing) is where mail implementations have historically gone to die.


**8 GB through mail is bad on the metal.** Mail bodies are text. Anything binary
gets base64'd, which is a 4/3 inflation — your 8 GB becomes 10.6 GB on the
wire and on disk. Most readers also materialize a whole message in memory to
display it.


**Mail gives up control at delivery.** A message in someone's spool is *theirs*.
They keep it, edit it, delete it, archive it forever. Your first vision says
view-only, and the ephemeral credential in it retains control — revoke and the
view is gone. Mail can't do that. It's a handoff, not a window.


**And there's a RAM problem underneath all of it.** tmpfs pages are real,
resident RAM. An 8 GB shelf on a mini-computer with 8 GB total will OOM the
machine. Whatever the shelf budget is, it has to be set from the actual free
memory on the *smallest* peer, not from the size of the corpus you want to
share.


## The design I'd pitch


Three layers, with generation and viewing kept strictly apart.


**The shelf.** On each machine, a fixed-slot RAM region —
`/dev/shm/sora-shelf/`, N slots, each one file plus a small sidecar holding its
metadata. A rotator wakes on a timer, picks K slots where K is your N-percent,
and replaces them from the source corpus. It deletes before it writes, so the
shelf's total byte count is bounded by construction rather than by hoping.
Memory assigned first, then worked through slot by slot.


**The manifest — this is your "small arrangement."** The shelf publishes a
plain-text index: slot number, name, byte size, content hash, and the time it
entered the shelf. A few kilobytes for thousands of slots. A peer holding the
manifest knows precisely what's on that shelf right now, and diffing it against
their previous copy gives the exact delta. Only the delta ever needs to move.
The manifest is small enough to be a packet.


**Delivery, in order of how likely I think each is to work:**


*SSH forced command, streaming tar.* The shelf account's `authorized_keys` entry
carries `command="/usr/local/bin/shelf-serve"`. When a peer connects, sshd
ignores whatever command the client asked for and runs that one instead —
there is no shell, ever. It reads a slot list from stdin and writes a tar stream
to stdout. The peer pipes it wherever: into their own tmpfs, or straight through
`tar xO | less`. This is view-only in the way that actually holds up, because
there is no code path in the server that accepts a write. And your "local
environment capabilities" requirement is met on the far side: once the bytes
land, they open them with their editor, their image viewer, their `grep`.


*Mail as the announcement channel, not the transport.* This is where rmail earns
its place. Every rotation, each peer gets a small message in their spool —
"shelf changed, 40 new slots, here are their names and hashes." Kilobytes. Their
mail reader is already a good UI for a rotation log: threaded, dated,
searchable, and present on every machine without you installing anything. The
gigabytes still travel over SSH on demand. You get the charm of rmail without
shoving 8 GB through an mbox.


*The shelf as a mounted filesystem.* SSHFS over the same connection, exported
read-only. The peer's file manager and editor see `/mnt/sora-1/` as ordinary
files, nothing is copied at all, and rotation becomes visible live — a file
someone has open simply ceases to exist at the next tick. That property is
either the most beautiful thing here or an endless source of I/O errors, and I
genuinely don't know which for your taste.


I'd take the first for bytes and the second for announcements: a manifest
channel that's small, textual and archival, and a byte channel that's large,
streamed, and leaves nothing behind.


## Questions this raises that I can't answer for you


- When a peer is mid-read on a slot and the rotator comes for it — does the
  slot get a grace period, or does it vanish under them? That single choice
  decides whether the shelf needs reference counting or can stay stateless.

- Is the rotation the same on every machine, or does each sora pick its own K
  independently? Synchronized rotation means one manifest describes the whole
  network; independent rotation means every pair needs its own diff.

- "sometimes all of them" — is a full swap just K = N, or is it a distinct
  event that peers should be told about differently?

- Does a peer keep what it fetched? If yes, the network slowly accumulates a
  full copy everywhere and the rotation is only about *attention*. If no,
  something has to reap on their side too, and that's software you'd be putting
  on their machine — which cuts against the whole "use their local
  environment" idea.


--------------------------------------------------------------------------------

### User Request 3

no that's not what rmail is, sorry that's a different thing. Check out
~/programs/r-mail/ for details.


--------------------------------------------------------------------------------

### Assistant Response 3

Read it. My earlier answer was about the UUCP `rmail` binary — wrong thing
entirely. **r-mail is your own program**: `/home/ritz/programs/r-mail/`, a ~229
KB Lua daemon, file-based messaging where a message is a plain text file in
`~/mail/inbox/`, you send by dropping a file in `~/mail/outbox/` with `to:`
lines at the top, and the filename is the subject.


That changes my answer. It's a much better fit than what I was arguing against
— but I found three things in your source that decide whether it works, and
one of them is a deliberate decision of yours that cuts directly against the
shelf idea.


## Why it fits


**Deletion propagates backwards, and that is the rotation primitive.** My whole
objection before was "mail hands over a copy and you lose control." r-mail
doesn't. Delete the outbox file and every recipient's copy is removed. Remove a
single `to:` line and just that peer's copy goes. That is simultaneously
vision-1's revocable window *and* vision-2's rotation — the sender rotates by
deleting and rewriting, and the peers' inboxes follow without anybody running a
reaper over there.


**"The viewer's local environment capabilities" is r-mail's thesis already.**
Your README: "read and write message files with whatever tools you already use
— vim, nano, VS Code, Notepad, cat, anything." You write no viewer. There is
nothing to write.


**One outbox file with several `to:` lines is the sharing topology.** "share it
with whoever wants to see you too" is literally three `to:` lines. And because
`attach:` lines bind to the `to:` line above them, one file can hand sora-2 a
different slice of the shelf than sora-3.


**The LAN case makes most of your README irrelevant.** Contacts hold an ip and
port; nothing requires them to be public. Put the soras' LAN addresses in each
other's contacts files and the entire port-forwarding, UPnP, dynamic-IP,
hairpin-NAT apparatus is dead weight — the outer router never learns these
machines talk. That matches vision-2 exactly.


## Three frictions, from reading the source


**1. Deleting a message does not delete its attachment — on purpose.**
`rmail.lua:1576`:


> `#355: we intentionally do NOT cascade inbox-message deletions into
> attachment-file deletions. Attachments are files the user owns — deleting a
> message shouldn't vapourise its PDF or photo. The previous helper
> (delete_inbox_attachments) was removed along with its four call sites.`


This is the load-bearing problem. Bodies cap at 128 KB, so an 8 GB shelf *must*
travel as attachments — and attachments are exactly the thing your revocation
doesn't reach. Rotate for an hour and every peer has accumulated the whole
corpus on disk. The rotation becomes decorative: the inbox churns, the bytes
pile up.


The comment even names the escape hatch: *"if disk cleanup is ever needed we can
add a separate user-invoked tool."* This project is that tool. But note the
tension — #355 decided attachments belong to the recipient, and a shelf
decides they don't. That's a real conflict between two of your own designs, and
it's yours to settle, not mine.


**2. The `on_delete` hook can't tell you what was deleted.** Every call site
(`rmail.lua:1716, 1750, 3289, 3304, 3934, 4385`) passes exactly one argument —
the other party's name. No subject, no filename, no message id. So a
receiving-side reaper gets told "sora-1 deleted something" and has no idea which
slot. Either you widen that hook to pass the subject, or the reaper works by
diffing: list the attachments directory, list the inbox, delete any attachment
no surviving message claims. The diff approach needs no change to r-mail; the
hook change is two lines and makes the reaper trivial. I'd widen the hook.


**3. Consent is manual, per attachment, and your rotation is every three
minutes.** The recipient has to open the consent file and delete either the
`accept` or the `deny` line. At N% of a shelf rotating every 3 minutes that's a
person editing files forever. The `on_receive` hook is the bridge — it runs in
the background with the sender, subject, and on-disk path, so a short script can
recognize a shelf-slot consent request from a known sora and write `accept`
itself. That turns consent from a per-file decision into a standing policy,
which is the only way this runs unattended.


It's also where the OOM guard belongs, and that's the sharpest hardware problem
here. Attachments land in `~/mail/attachments/` (disk) with in-flight chunks in
`/tmp` (config key `attachment_pending_dir`). To honor "take 8gb of my memory
into ram" you'd point both at `/dev/shm/`. But then a transfer holds the zipped
chunks *and* the extracted files in RAM at once — peak is roughly twice the
slot size, on a mini-computer whose entire RAM may be 8 GB. The auto-accept
script is the thing that says "no, I don't have room right now" and writes
`deny`. The viewer decides its own budget. That's the correct place for that
decision and it's the answer to how the shelf doesn't kill the machine.


## The design


**Contacts.** Each sora runs a daemon, every sora is a contact of every other,
LAN ip/port, a distinct token per pair. Trial decryption means nothing
identifies a sender in cleartext — an unknown machine on that network sees
encrypted TCP to a random high port and no way to tell who's talking. That's
your vision-1 "small arrangement" surviving in a different mechanism: the token
*is* the arrangement, and the ephemeral credential becomes a rotated token,
which the contacts file supports as an ordinary text edit.


**A slot is one outbox file.** Shelf lives in `/dev/shm/sora-shelf/slot-NNN/`.
The outbox file for it:


```

to: sora-2

to: sora-3

attach: /dev/shm/sora-shelf/slot-007/


slot 007 — name, byte size, sha256, entered 14:32:06

```


Body is that slot's manifest line, comfortably under the 128 KB cap. The
directory is the payload — r-mail zips directories recursively.


**Rotation is delete-then-write.** The rotator removes slot-007's outbox file,
r-mail propagates the removal to every peer's inbox, then the rotator writes a
fresh slot-007. Outbox changes are caught by inotify immediately, so rotation
never waits on the adaptive 5-minute timer. The receiving-side reaper (friction
1) then takes the orphaned attachment.


**Chunk math, because it decides your N.** Default chunk is 5 MB, so a full 8 GB
swap is 1,638 chunks, each its own AES-256-GCM round trip. On a LAN the wire
isn't the constraint — zip plus AES on a mini-computer's CPU is. A 30-minute
full rotation is comfortable; "every 3 minutes, N% of the files" needs N small
enough that the work finishes inside the window, or transfers overlap and the
shelf never settles. Measure one slot's compress-and-send time on an actual sora
before picking N. Also: if your corpus is already-compressed data, the zip step
burns CPU for nothing and you'd want to skip it.


## What I'd want answered before building


- **Does #355 stand?** If attachments belong to the recipient, a shelf can't
  rotate them, and the honest version of this project is "the shelf grows on
  every peer and rotation only changes what's *announced*." That might actually
  be the better idea — but it's a different idea, and you should pick it
  deliberately rather than discover it.

- **Should `on_delete` learn what it deleted?** Widening it to pass subject and
  message id makes the reaper three lines instead of a directory diff, and it's
  a change to r-mail proper, not to this project.

- **Is auto-accept a policy you want to exist?** Once a script writes `accept`
  on your behalf, any contact holding a valid token can push bytes into your RAM
  up to whatever budget the script enforces. The budget check is the whole
  safety mechanism.

- **When a peer is reading a slot and the rotator comes for it** — grace
  period, or does it vanish under them? Same question as before; r-mail doesn't
  answer it either way.

- **Is `/tmp` a tmpfs on the soras?** If it is, in-flight chunks are already RAM
  and the peak-memory math above applies as written. If it isn't, chunks hit
  disk and the "8gb into ram" premise is only half true.


--------------------------------------------------------------------------------

### User Request 4

we should make it so that if a file is deleted from the viewer's end then a new
one is randomly supplied. I think we can do this by making a deletion hook
script which will notice when something is deleted from the outbox on the server
computer. We're going to need a new mailbox for this, so make sure that the
recent efforts (review the llm-transcripts) toward making the install script
idempotent are working - then we just need to create a new mailbox, and make a
system that, upon delete, syncs a new random file into the mailbox. We should
have three mailboxes, one for each system that we're SSH'ing into to view
randomly. Also this script doesn't have anything to do with sora we're working
on the vision-2 document right now - we should build the actual script which
handles the user-name / password exchange, then see how we can implement it by
integrating it with rmail - not integrating on rmail's side, but an
implementation of rmail with the ssh-view-only-viewer-script applied. So we'd
sync a random file to the rmail inbox, then when a viewer deletes it (they have
only access to that directory tree, which is auto-populated) a new one is copied
into the outbox of the server, delivered to the inbox of the viewer system, and
then we wait for more deletions. Essentially it's someone saying "I read this,
next one please?" and it gives them one completely randomly. But the viewer
script doesn't need rmail at all, so we have two separate visions here - one for
the tooling, and one for the implementation. Let's make sure they're considered
separate, but related enough to be part of the same project.


--------------------------------------------------------------------------------

### Assistant Response 4

Starting with the gate you named — the install script's idempotency. Let me
review the transcripts and the script itself.


Gate check first: **the idempotency work is not implemented.** It exists only as
a blueprint. Let me confirm the details before I report.


Confirmed the gate fails. Now let me preserve the current state before
restructuring, so both versions are in the record.


Baseline is in the record. Now the structure and the vision split.


Let me verify the one mechanism the whole refill loop depends on — that a
recipient's deletion fires a hook back on the server.


Loop verified end to end. Let me record the new vision material, then put the
blocking questions to you.


Verification done. Three things block the build, and they're all yours to
decide.


**[Asked the user]**


*Q1 — Topology:* Where do the three mailboxes live, and who SSHes into whom?

- Three jails on one server — The server runs three r-mail mailboxes and three
  chrooted SSH accounts, one per viewer. Viewers SSH in and land in a tree they
  cannot leave. This matches "they have only access to that directory tree" —
  but it puts three mailboxes on one machine, which is exactly the collision
  bug.

- A daemon on each viewer machine — Each of the three viewer machines runs its
  own r-mail daemon with its own inbox. The server runs one mailbox with three
  contacts. No mailbox collision at all — but then delivery is r-mail over the
  network and SSH isn't carrying files, so the two visions barely touch.

- Server jails, viewers also run daemons — Both. The server hosts the jails
  for people who want to SSH in and look, and the viewer machines that can run a
  daemon get delivery directly. Two front doors onto the same corpus.

→ **Answered:** A daemon on each viewer machine" selected preview:

SERVER                    VIEWER MACHINES

  one mailbox      --->     A: own daemon, own inbox

  three contacts   --->     B: own daemon, own inbox

                   --->     C: own daemon, own inbox


needs: nothing from #377

delivery: r-mail over LAN

ssh: not used for files at all, "The password is "the other person's name" —
which other person?"=(no option selected) notes: as long as it's viewing only,
and we promise not to keep any logs or anything... then authentication doesn't
really matter, right? we're creating a sandbox so that people can view the files
on my computer (albiet a random selection) while also testing the sora-fg
system, and rmail., "Installing three mailboxes collides today — issue #377 is
written but unimplemented. How do you want to get past it?"=(no option selected)
notes: add it as a blocker in our notes, don't implement it yet, leave rmail
development to their team. Read the answers carefully — they may request
clarification, changes, or that you not proceed — and follow what they
actually say.


*Q2 — Pairing:* The password is "the other person's name" — which other
person?

- Another viewer who is currently in — Viewer A's password is the name of
  whoever else holds a live session right now. You cannot get in alone —
  someone else has to already be looking. The credential is a function of who is
  present, which is what makes it genuinely temporary rather than just timed
  out.

- The server's own name — Every viewer logs in as themselves with the server's
  identity name as the password. Simple, always works, one shared secret. The
  "temporarily" part then has to come from an expiry timer rather than from the
  pairing.

- Carried in the knock itself — The packet that triggers the door contains the
  pairing. The arrangement in the packet IS the identity, and the
  username/password is just a human-readable form of what the packet already
  proved. No roster on the server at all.

→ *(no answer recorded)*


*Q3 — Install fix:* Installing three mailboxes collides today — issue #377
is written but unimplemented. How do you want to get past it?

- Implement #377 in r-mail first — Do the blueprint: derive service name and
  log path from the mailbox slug, stop repointing the root config symlink, add
  the existing-install scan, check ports and identity names against sibling
  configs. Cross-project work in the r-mail repo, but it unblocks every future
  mailbox, not just these three.

- Hand-write the three configs here — Skip install.sh entirely. This project
  writes the three config files and three service files itself, with names
  derived from each mailbox path. #377 stays open in r-mail; we just don't use
  the broken path.

- Only fix what three mailboxes need — A narrow slice of #377: service name,
  log path, and the identity-name uniqueness check — the three things that
  actually bite here. Leave the scan, the port check and the doc fixes for
  later.

→ *(no answer recorded)*


Answers recorded. Let me address your question directly, because it changes what
the script should actually protect.


**You're mostly right, and for the reason you gave** — the sandbox is the
guarantee, not the credential. If the jail holds, a stranger who gets in reads a
file you already decided to lend. The chroot is doing nearly all the work, and
the password is doing very little.


But one thing does change with weak auth, and it's specific to this design:
**deletion is the only verb, and deletion means "give me another."** So a
stranger doesn't read one random file — they sit there deleting, and the
refill loop feeds them as fast as they can ask. Random draw, repeated enough
times, is a full copy. What authentication buys here isn't confidentiality per
file; it's a bound on *rate and totality*.


Which moves the real decision off the credential entirely: the thing protecting
you is **the corpus boundary and whether the draw repeats**. If the corpus is a
directory you curated for lending, auth genuinely doesn't matter and you should
spend nothing on it. If the draw reaches into your real files, no password saves
you — the selection function does.


So I'm treating the random draw as the load-bearing component, shared by both
visions. Writing that up now.


Now the phase 1 issue file, before any code.


Issue filed. Now the implementation.


Now the tests — issue 100 step 6.


The test caught a real bug: `readlink -f` succeeds on a path whose final
component doesn't exist, so a missing file read as *inside* the corpus. `-e`
requires every component to exist.


Committed. Here's where things stand.


## The gate you named: it fails


The idempotency work was never implemented. Issue #377 in r-mail is a blueprint,
status Open, written Aug 25 — and I verified against the source rather than
trusting the file. All five init-system branches still write a service literally
named `rmail` to a fixed path, all five log to `/tmp/rmail.log`, there's no
service-name variable anywhere, and line 742 still repoints the project-root
config symlink on every run. The mailbox-path slug that would fix it exists and
is used for the config filename only.


Recorded in `notes/blockers.md`. I did not touch r-mail.


**It doesn't block you anyway** — your topology choice put one mailbox on each
machine, never several on one. The collision needs two mailboxes sharing a host.
The note says when it would come back (if you ever move the viewers' mailboxes
onto the server) so the cost is known in advance rather than discovered by a
mailbox going quietly dark.


The sharper half of that bug is worth knowing regardless: two mailboxes on one
machine sharing an identity name causes mail between them to be delivered into
the *sender's own inbox*, silently, because the daemon checks each `to:` line
against its own identity before any contacts lookup. For a project that is
entirely machine-to-machine delivery, that would have looked like the network
being broken.


## The refill loop is mechanically sound


I traced it rather than assuming. Three things in r-mail carry it, all existing,
none modified:


- When a recipient deletes, `remove_recipient_from_file` strips their `to:`
  line, and when the count hits zero it calls `os.remove` on the outbox file.
  One recipient per file means a viewer's deletion cleans the server's outbox
  completely.

- The branch commented *"recipient telling us they deleted something we sent"*
  fires `on_delete` with the recipient's name. That single argument is thin —
  no subject, no filename — but for a loop whose only question is *which
  viewer said next*, it is exactly enough.

- `attach:` binds to the `to:` above it, so one file goes to one viewer.


The friction is consent: r-mail asks before every transfer, which is a second
verb on top of deletion and breaks "delete is the only gesture." The viewer-side
`on_receive` hook can auto-accept, but that's software on their machine, which
was the thing the tooling vision was attractive for avoiding. Written up as an
open question, not decided.


## What I built


The draw — `src/006-the-draw.lua`, the one component both visions consume. It
answers *give me a file, at random, that I am allowed to lend* and knows nothing
about who asked. 22 tests pass.


Deciding whether one path is inside another turned out not to be the string
comparison it looks like. `lend-secrets` passes a naive prefix test against
`lend`. A symlink passes every string test there is. Each way out is a separate
test case because they fail independently.


**One test caught a real bug.** I resolved paths with `readlink -f`, which
succeeds when only the *final* component is missing — so a filename the corpus
never contained resolved cleanly and tested as lendable. `-e` requires every
component to exist. Reading didn't catch it; the assertion that a never-written
name is refused caught it immediately.


## What I did not build


**The username/password script you asked for first.** Your answer redirected it
— you said auth doesn't much matter here, and I argued the draw is the
load-bearing thing, so I built that instead. The credential is phase 2 and the
pairing rule is still undecided. If you want that script next, say so and I'll
build it; I didn't want to pick a pairing rule on your behalf when you'd
declined to.


**Steps 1 and 5 of issue 100.** No configuration reader — corpus root, ceiling
and ledger path are passed by the caller rather than read from anywhere. And the
ledger exists only as an in-memory map a caller keeps; nothing writes it to the
RAM tier, so nothing survives between processes.


## Open questions, unanswered


The task is in progress, not delivered, because these are outstanding:


- Does the roll rebuild while running, or does a restart go on being required to
  see new files?

- What's the repeat ceiling's default — one draw per file per viewer, or
  unlimited? That number is the difference between a sampler and a slow complete
  copy.

- Should the ledger survive a restart? It doesn't, so a restart lets every
  viewer see everything again — and if it should, it moves to disk and the
  no-logs promise needs re-reading.

- Does the viewer auto-accept r-mail's consent request, or accept by hand each
  time?

- Deleting a message doesn't delete its attachment — r-mail decided that
  deliberately. So the viewer's attachments directory accumulates everything
  ever drawn, and "one file at a time" is only true of the inbox, not the disk.
  Who cleans that up?

- What does the server send when the draw runs dry? Sending nothing leaves an
  unexplained empty inbox; sending a message saying so means deleting *that*
  asks for another.

- The project promises no logs, but sshd writes auth records through the system
  logger regardless. As written, the promise isn't true.


One housekeeping note: the repo has uncommitted work from other projects
(hero-less-moba, gif-generator, enheim-tome). I staged only this project's paths
and left the rest alone.


--------------------------------------------------------------------------------
