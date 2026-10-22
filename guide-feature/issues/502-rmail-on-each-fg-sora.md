# 502 — rmail on each fg-sora

phase 5, bringing up the fg-sora machines

## Current behavior

Nothing listens on the fg-sora ports.

## Intended behavior

On each fg-sora, an rmail daemon serving one mailbox named after the
machine, on its port (10101 on .11, 20202 on .12, 30303 on .13), with the
guide mailbox on kuvalu (192.168.1.100, port 1223) as its only contact,
started on boot.

rmail needs LuaJIT, LuaSocket and OpenSSL, normally compiled by its
`scripts/install.sh`. On a BusyBox system without a compiler, they are built
on kuvalu for the machine's C library (501) and copied over. rmail's
`scripts/make-mailbox-drive.sh`, which makes a trimmed self-contained copy,
may be the right starting point.

## Suggested implementation steps

1. Decide build-here-or-there from the survey.
2. An install script run from kuvalu that copies, configures (using the
   contacts generator from 301) and starts the daemon on each machine.
3. Check from kuvalu: each port answers, and a test message goes each way.

## Related documents

- `docs/rmail-constraints.md`, "rmail's own needs on the fg-sora machines"

## Blocked by

301, 501.

## Blocks

504.
