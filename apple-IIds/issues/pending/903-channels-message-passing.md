---
name: channels and message passing
phase: 9
status: pending (pending soramech)
blockedBy: [901, 902]
---

# 903 — channels and message passing *(pending soramech)*

A typed message-passing primitive. Tasks send messages to channels;
other tasks receive them. Lifted from soramech.

## current behavior

Tasks (from issue 901) can run concurrently but cannot communicate
except through shared memory + locks (issues 902). No higher-level
coordination.

## intended behavior

- Channel primitives:
  - `channel_create(capacity) → C` — make a channel with bounded
    capacity (0 = unbuffered, blocking on both ends).
  - `channel_send(C, msg)` — block until space, then enqueue.
  - `channel_recv(C) → msg` — block until a message, then dequeue.
  - `channel_try_send`, `channel_try_recv` — non-blocking variants.
  - `channel_close(C)` — wake all blocked tasks with an
    end-of-stream signal.
- Messages are small (8 bytes by default; larger messages pass a
  pointer to data the sender owns).
- Channel implementation uses the locks from issue 902 internally
  but presents a higher-level API that's easier to reason about.
- Selectors (wait on multiple channels at once) — defer to a
  follow-up unless soramech's design includes them out of the box.

## suggested implementation steps

1. Translate soramech's channel implementation to 65C816 assembly.
2. Implement the data structure (ring buffer + sender wait list +
   receiver wait list).
3. Implement the API.
4. Test with a producer/consumer scenario: one task fills a
   channel, another drains it; verify no messages lost, no
   deadlock.
5. Test with a closed channel: receivers see end-of-stream
   correctly.

## related documents

- `issues/901-scheduler-primitives-asm.md`,
  `issues/902-locks-atomics.md` — the substrate
- Soramech source (external)

## known design questions

- Message size: 8 bytes is small but fits the common case
  (events, command codes, small data). Anything larger needs a
  pointer indirection. Documents the convention.
- Channel buffer location: typically heap-allocated. Each channel
  carries the buffer's size.
- Are channels typed (each channel has a fixed message type) or
  generic (any 8-byte payload)? Soramech-aligned: typed at the
  API level (the channel knows the type), but the runtime treats
  all channels as 8-byte payloads. Type safety is a compile-time /
  design-time concern.

## notes

- Once channels exist, all higher-level coordination becomes
  expressible. The broker's IPC (issue 304) could rewrite to
  ride on channels in the bare-metal era. So could the AppleTalk
  emulation. Big leverage from a small primitive.
