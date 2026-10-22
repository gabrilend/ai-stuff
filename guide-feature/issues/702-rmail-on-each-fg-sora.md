# 702 — rmail on each mini-computer

phase 7, bringing up the mini-computers

## Current behavior

Nothing listens on the mini-computers' ports.

## Intended behavior

On each mini-computer, an rmail daemon serving one mailbox named after the
machine, on its port (10101 on .11, 20202 on .12, 30303 on .13), with the
guide mailbox on kuvalu (192.168.1.100, port 1223) as its contact, started
on boot, made by the same mailbox setup script as everything else (301).

rmail needs LuaJIT, LuaSocket and OpenSSL. On a BusyBox system without a
compiler they are built on kuvalu for the machine's C library (701) and
copied over. rmail's `scripts/make-mailbox-drive.sh` makes a trimmed
self-contained copy and may be the starting point. The public-address check
and port mapping are turned off if rmail allows it (`docs/network.md`).

## Suggested implementation steps

1. Build here or there, decided from the survey.
2. An install script run from kuvalu: copy, configure, start on boot.
3. Check from kuvalu: each port answers, and a test message goes each way.

## Related documents

- `docs/rmail-constraints.md`
- `docs/network.md`

## Open questions

- rmail's outside requests (`docs/open-questions.md`, 8).

## Blocked by

301, 701.

## Blocks

704.
