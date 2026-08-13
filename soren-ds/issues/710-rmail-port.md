# 710 — rmail port

## Current behavior

rmail is a token-authenticated, AES-256-GCM-encrypted peer
protocol originally designed for the open internet, with its
source at `/home/ritz/programs/r-mail/` and documentation
mirrored under `/mnt/mtwo/programs/r-mail/`. The original
implementation opens TCP connections against addresses resolved
through DNS. Neither TCP nor DNS exist in the Soren DS launch
networking stack; rmail won't compile against it as-is.

## Intended behavior

A port of rmail runs on Soren DS with the network stack swapped
out. The high-level surface — "send a message to peer X with
this body and these attachments; receive messages addressed to
me" — is preserved. The underneath swaps:

- **TCP → UDP plus rmail's own acknowledgement layer.** rmail
  already has a sequence-and-ack protocol for messages too large
  to fit one packet; the launch port runs that layer over UDP
  via the transport abstraction (709). Reliability is rmail's
  responsibility, not the network's.
- **DNS → the peer table (705).** Addresses are friendly names,
  resolved by the peer table at send time.
- **TLS-style transport encryption → unchanged.** rmail's
  AES-256-GCM encryption sits inside the application-layer
  protocol, not in a transport-layer wrapper, so it ports
  unmodified.
- **Cross-platform threading and IO → the soramech runtime.**
  rmail's threading abstraction is replaced with box functions
  on the runtime. Async IO becomes "fire a box when the
  network receive event happens."

The port produces a small `rmail_t` API exposed as soramech
boxes:

- `rmail-send` — inputs: peer name, message body bytes,
  optional attachment file path. Output: success-or-error.
- `rmail-receive` — emits an event when an addressed message
  arrives, with the sender's friendly name and the message
  body.
- `rmail-fetch-history` — read the local persisted message
  history for a peer.

Messages are persisted under `/messages/<peer>/` per the
filesystem doc.

## Suggested implementation steps

1. Identify rmail's transport-layer abstraction in the original
   source. Document the seam in
   `notes/rmail-port/000-transport-seam.md`.
2. Implement the seam against the Soren DS transport abstraction
   from 709.
3. Replace rmail's threading abstraction with soramech box
   wrappers.
4. Compile against the kernel-image-side libc subset (the same
   that other box source compiles against, per 409).
5. The three high-level boxes as ordinary box sources, catalogued by
   the generator because of where they live.

## Related documents

- `docs/006-transport-and-networking.md` — rmail section.
- `/mnt/mtwo/programs/r-mail/docs/` (the parent project's docs).

## Blocked by

709 (transport surface rmail builds on), 408 (settings for
peer identity), 406 (read-path for history retrieval).

## Blocks

711.
