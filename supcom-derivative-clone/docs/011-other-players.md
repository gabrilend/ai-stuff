# 011 — Other Players

The multiplayer framework: how two machines hold one match, what crosses the
wire, and what is known and not yet known about the wire on the handheld.

## Lockstep, and why

Every machine in a match runs the **whole simulation**, and the only thing that
crosses the wire is **intent**: the commands each player issued, stamped with
the tick they take effect at. No positions, no health, no snapshots. Two
machines that start from the same seed and apply the same commands at the same
ticks compute the same match, tick for tick, and each one draws its own copy.

This is the model the parent game used, and it is chosen here for three reasons
that are specific to this design rather than inherited:

- **Commands are rare and small.** A player places a factory, draws a pattern,
  presses one of four buttons, moves a truck, launches a plane. Nothing is
  driven. A match's entire command log is a few kilobytes, and a tick with no
  commands in it — nearly every tick — sends an empty batch.
- **Everything is already queued.** The vision's invariant means every command
  takes effect at a later tick anyway. Scheduling it a few ticks further out so
  that it can reach every machine first costs the player nothing they were not
  already paying.
- **The wire is a radio.** The handheld reaches its peers over an ad-hoc link
  with no router, no internet, and a bandwidth that is not yet measured. A model
  that sends a few bytes a second fits any link that works at all; a model that
  reconciles state needs one that works well.

The alternative — one authority, the rest reconciling — was chosen by a sibling
project whose game has driven bodies and constant commands. It is the right
choice there and the wrong one here, and the [open questions](016-open-questions.md)
page records the direction as set.

## What lockstep demands

**Determinism.** Same seed, same commands, same result, on every machine and
every build. The [tick document](003-the-tick-and-the-timers.md) lists the three
rules — named streams, array order, identical arithmetic — and the
reproducibility test runs on every build. The one thing not yet known is
whether double-precision arithmetic agrees across the two targets, a desktop
processor and the handheld's ARM cores. It is marked awaiting evidence, and the
evidence is a run of the same match on both with the hashes compared. If they
disagree, positions become fixed-point integers, which the flat-array design
allows without touching any rule.

**A delay.** A command issued at tick T is stamped for tick T plus a delay, and
sent to every peer at once. A machine may advance tick T only when it holds
every peer's batch for T — including empty ones. The delay is in ticks, from the
catalogue, and is the [open question](016-open-questions.md) that the radio's
measured latency will answer.

**A stall rule.** A machine that has not received a peer's batch for the next
tick waits. If it waits longer than a threshold, it says so on screen — "waiting
for X" — and keeps waiting. Nothing is guessed. A peer that never comes back is
handled below.

## Commands are scheduled for a later tick

The command door already accepts a command with a tick stamp and applies it at
that tick. Lockstep adds one rule at the door: **a command for a tick that has
already run is refused**, loudly, because applying it would fork the match. On a
single machine the delay is one tick and the refusal never fires; on the network
it is what makes a late packet a diagnosable event rather than a silent
divergence.

<!-- toy: lockstep -->

## A desync is named, not hidden

Every machine fingerprints its world at the end of every tick. Every so many
ticks, the fingerprint is sent along with the command batch. A machine that
receives a fingerprint for a tick that disagrees with its own **halts the match
and says which tick**, writes its snapshot of that tick and the one before to
the RAM tier, and offers the replay for diagnosis. It does not resynchronise, it
does not pick a winner, and it does not carry on. A desync is a bug in the
simulation, and the only correct response to a bug is to catch it with its
evidence intact.

## Dropping and rejoining

A peer that drops leaves its last acknowledged tick behind. The match stalls at
that tick for the others. When the peer returns, it asks for the command log
from its last tick to now, replays it locally at full speed — the same replay
the [snapshot system](003-the-tick-and-the-timers.md) already supports — and
rejoins at the current tick. The others resume. Nothing was ever sent but
commands, so nothing was ever lost but time.

## Finding each other

A machine looking for a match announces itself — a name, the seed it proposes,
the tick rate — and listens for the same. Machines that hear each other form a
**lobby**: a list of peers, a shared seed, and a start tick agreed on by the
one that announced first. The announcement repeats on a counter until the match
starts, and a peer that stops announcing is aged out of the list — the
[pair of integers](003-the-tick-and-the-timers.md), on the wire.

## The transport on a computer

On a computer the wire is **UDP** on a local network, through the socket
library LuaJIT already ships with. A batch is one datagram: sender, tick, a
count, and the commands. Discovery is a broadcast on a fixed port. There is no
internet play and no server, on purpose: the match is a room of machines that
can hear each other, which is what the handheld's radio is too.

Lost datagrams are the normal case, not the exception. A machine that is waiting
for tick T's batch from a peer asks for it again after a short wait, and a peer
keeps every batch it has sent until every other has acknowledged the tick. That
is all the reliability the model needs, because a batch that arrives late is as
good as one that arrived on time until the delay runs out.

## The transport on the handheld

The handheld's operating system, a sibling project called Soren DS, designs its
networking as a **transport abstraction**: an application names a *peer* — "the
handheld called X" — and the system delivers a datagram to a named port on that
peer over whichever link currently reaches it. The links are an ad-hoc WiFi
radio and a USB-C cable that presents as a network adapter. What is written down
about the radio, in that project's documents:

- The radio runs in **ad-hoc (IBSS) mode**: no router, no access point. Every
  handheld uses one fixed network name and one fixed channel, so they form a
  single mutual peer group.
- Addresses are **link-local**, self-assigned, and announced with a short "I am
  here, my name is X" broadcast every few seconds. Peers that stop announcing
  age out of the peer table.
- Applications send **UDP datagrams to a peer's named port**, and receive them
  from any transport into one box. The cable is preferred over the radio when
  both reach a peer.
- The link layer is **unencrypted**; a messaging layer above it (rmail) encrypts
  end to end for the applications that want it.

That is a good fit for this game: discovery is done for us, the datagram is the
unit of transfer, and a peer name is a better address than a number. The
lockstep layer above it is the same code as on a computer, with the socket
swapped for the transport's send and receive boxes.

**What is not written down**, and what this design is pending on — **design
pending details on soren-ds wifi capabilities**:

- Whether the handheld's radio chip supports ad-hoc mode at all. That project
  names it as the single largest hardware risk of its networking phase, and it
  is unconfirmed on real hardware.
- The measured bandwidth, latency, and loss rate of the link between two
  handhelds in a room, which decide the input delay and the resend interval.
- The largest datagram the link carries, which decides whether a batch ever
  needs splitting. A batch is small, but a rejoining peer's catch-up is not.
- How many peers one radio can hear, which bounds the match size.
- What sustained sending costs in battery.

None of those change the model. All of them change the numbers, and the numbers
live in the catalogue. The handheld transport issue is written as a blueprint
with those five things marked as inputs it does not yet have, and its
implementation waits on the sibling project's radio phase.

## Encryption

Nothing on the wire in a match is secret — every machine already has the whole
world — so the game sends commands in the clear. Whether to sit above the
handheld's encrypted messaging layer anyway, for the sake of one code path, is
[open](016-open-questions.md).

Related: [the tick](003-the-tick-and-the-timers.md) · [the handheld](012-the-handheld.md) ·
[the roadmap](015-roadmap.md)
