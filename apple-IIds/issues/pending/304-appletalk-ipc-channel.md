---
name: AppleTalk-style IPC channel
phase: 3
status: pending
blockedBy: [201]
---

# 304 — AppleTalk-style IPC channel

A bidirectional message channel between the two emulated IIdses. To
GS/OS code on either side, the channel looks like an ordinary
AppleTalk socket. Underneath, the broker routes between them.

## current behavior

The two instances cannot speak to each other. Coordinated-pair
programs (phase 13+) have no transport.

## intended behavior

- Each IIds sees the other as a peer on a tiny AppleTalk network
  (network number 0, two nodes). Standard `OpenSocket`,
  `WriteSocket`, `ReadSocket` calls work.
- The broker implements an in-memory message-passing layer that
  delivers packets between the two instances. Implementation detail
  underneath: a pair of Unix-domain socketpairs or in-process queues.
- AppleTalk semantics are honored as far as IIds software cares:
  packets, sockets, named services via NBP (Name Binding Protocol)
  if requested.
- Packet size limits match real AppleTalk's DDP: 586 bytes per
  packet. Larger messages chunk.
- Latency target: ≤1 ms one-way for a same-frame send-and-receive
  between the two instances. This is much faster than real
  AppleTalk; we're not pretending to be a slow network, we're
  pretending to be a network at all.
- A diagnostic command in the broker shows the current AppleTalk
  packet log (last N packets, types, sizes, sockets).

## suggested implementation steps

1. Read GS/OS's AppleTalk implementation. The source release should
   include it. Note where it talks to the LocalTalk hardware.
2. Write a GSplus patch that replaces the LocalTalk hardware
   emulation with a stub that hands packets to the broker.
3. Write the broker side: receive a packet from instance X, deliver
   it to instance Y. Maintain per-socket queues.
4. Add NBP support for at least the basics: registration, lookup.
   This lets one IIds program advertise a service that the other
   can find by name.
5. Test with a synthetic "ping" program: write a small IIds program
   that opens a socket, sends "hello," and prints any reply. Run
   it on screen A and a complementary version on screen B.
6. Document the packet log diagnostic.

## related documents

- `docs/001-architecture-overview.md` — broker IPC channel
- `docs/004-roadmap.md` — phase 13+ uses this for coordinated pairs
- `issues/305-conflict-resolution.md` — the IPC channel is one of
  the mechanisms for conflict notification

## known design questions

- Pretend to be AppleTalk, or invent our own protocol? Defaulting
  to AppleTalk because:
  1. GS/OS code already knows how to use it; no IIds-side reinvention.
  2. The original AppleTalk shape (sockets, packets, NBP names) is
     a fine fit for coordinated-pair programs.
- Should non-IIds (broker-internal) processes be able to address
  the channel? Yes — the broker may want to send status updates to
  the IIdses. NBP names like `Broker/Status` give it a clean address.

## notes

- This is one of the most "alive" pieces of the architecture: the
  moment the two instances can talk, the project stops being
  "two emulators that happen to share a screen" and starts being
  "a real dual-screen machine." It's worth investing in good
  diagnostics here.
- A nice future feature: log every AppleTalk packet to a file the
  developer can replay through a simulator. Useful for debugging
  coordinated-pair programs without running both halves on hardware.
