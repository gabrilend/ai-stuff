# Blockers

Things outside this project that would stop it, recorded so they are not
rediscovered.

## r-mail: the installer cannot name a second service

**Status: not blocking. Relevant only to the example implementation, and
only at install time.**

Running several r-mail daemons on one machine is **designed behaviour**,
not a workaround. `docs/service.md` sets it out directly: one mailbox per
daemon, several daemons per machine — a personal mailbox, one for
automated notifications, one for syncing between devices — each pointed
at its own config, its own port, its own mail directory. This project
should assume that arrangement is available and wanted.

What does not work is the **installer**, and only the installer. Every
install generates a service named `rmail`, writes it to a fixed path, and
logs to a fixed file, so installing a second mailbox replaces the first
one's service rather than adding to it. Verified against the current
source: all five init-system branches still carry the literal name, there
is no service-name variable, and the mailbox-path slug that would supply
one already exists and is used for the config filename only.

Consequence for us: the second and third mailboxes must have their
service files written by hand, or by something of ours, rather than by
running the installer again. The daemons themselves are entirely happy
with the arrangement — it is the generated startup files that collide.

**Identity names must differ between mailboxes on one machine.** The
daemon compares each `to:` line against its own configured identity
before consulting contacts, so a recipient name matching your own is
delivered into your own inbox. That is the loopback path working as
designed, and it is what makes a mailbox able to address itself. It only
bites if two mailboxes are accidentally given the *same* name, at which
point mail meant for the sibling lands at home instead. The documented
example already avoids this by naming its mailboxes distinctly
(`alice-notifications` and so on). We do the same, and it is a naming
rule rather than a defect to route around.

**What we are doing about it: nothing.** r-mail development belongs to
its own team. Tracked upstream as issue #377, status Open — its blueprint
is sound: service name and log path derived from the existing slug, a
scan before writing, port and identity checked against sibling configs.
