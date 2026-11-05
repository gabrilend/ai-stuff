# 042-test-stand-in-carrier — info

Tests the stand-in carrier (041) against rmail's file-and-hook contract.
It uses three mailboxes made by `scripts/make-mailboxes`, each with a hook
wrapper that records its calls.

What it checks:
- Outbox files: parsing and dot names.
- New inbox files and `on_receive`: its arguments, and that it runs in
  the background (a slow hook does not hold the round up).
- Edits through `on_update`: the arguments, the body on stdin, an empty
  argument over 64 KiB, the output replacing the body, and a failure
  refusing the edit until the next try.
- Only the newest body is carried.
- The second sender's `canvas` lands as `canvas-from-fg-sora-2`, and the
  sender is known by the token.
- Timers: the floor, the jitter, and due-at-once after a delivery.
- Nothing is carried to an unknown contact, another machine, or a
  receiver that does not know the token. Each of these is reported once.
- A deleted inbox file is not made again.

    luajit src/042-test-stand-in-carrier.lua [--dir ROOT]
