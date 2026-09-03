# Blockers

Things outside this project that would stop it, recorded so they are not
rediscovered.

## r-mail: installing several mailboxes on one machine collides

**Status: not blocking the chosen design. Blocking a variant we rejected.**

r-mail's installer gives every mailbox the same service name, the same
service file path, and the same log file. Installing a second mailbox on
one machine does not add a second service — it silently replaces the
first, and the first mailbox stops being served with no error at install
time or run time. On systemd the replacement happens during the install
while a success message prints; on runit and OpenRC the running daemon
survives until its next restart, which can be weeks later.

Verified against the current source, not just the issue file. Every
service path and the log path are still literal in all five init-system
branches; there is no service-name variable. The mailbox-path slug that
would fix it already exists and is used for the config filename only.

There is a second, sharper edge: two mailboxes on one machine sharing an
identity name causes mail addressed between them to be **delivered into
the sender's own inbox**. The daemon compares each `to:` line against its
own identity before any contacts lookup, so a name collision self-delivers
silently — no error, no retry, and the tracking state marks the recipient
satisfied. For a project whose entire purpose is machine-to-machine
delivery, that failure would look like the network being broken.

**Why it does not block us.** The chosen topology puts one mailbox on each
viewer machine and one on the server — one per machine, never several.
Nothing collides.

**When it would come back.** If the design ever moves to hosting the
viewers' mailboxes on the server (the jails-on-one-server topology), it
needs three mailboxes on one machine and this becomes a hard blocker.

**What we are doing about it: nothing.** r-mail development belongs to its
own team. This is recorded here so that if the topology changes, the cost
is known in advance rather than discovered by a mailbox quietly going
dark.

Tracked upstream as r-mail issue #377, status Open, written 2026-08-25 and
not implemented. Its blueprint is sound — service name and log path from
the existing slug, a scan before writing, port and identity checked
against sibling configs.
