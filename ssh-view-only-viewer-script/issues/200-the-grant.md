# 200 — The grant

## Current behavior

Built and tested. Thirty-three tests pass, none of which create an
account — every test reads a plan rather than running one.

Account naming, existence and ownership inspection, the creation plan,
the removal plan, expiry selection, record building, plan rendering and
the runner are all present. The doorman wires them to the arrangement and
has been run end to end over UDP in unarmed mode: a real packet produces
a real verdict and prints the exact commands that would follow.

**Nothing has ever been run armed.** The plans are unexercised against a
real system.

The sweeper's persistence is partial: grants are appended to a file in
the RAM tier, but the doorman does not yet read that file back at
startup, so a doorman restarted after a crash sweeps only what it granted
since restarting. Step 5 is therefore incomplete in the way that matters
most — it is the case the sweeper exists for.

## Intended behavior

Given a name and the window its packet used, bring a view-only account
into existence, and take it away when its time is up.

This is the only part of the project that needs root, so it is written to
make the privileged step small, visible, and refusable. The module
**produces a plan** — an ordered list of commands with a reason attached
to each — and running that plan is a separate, explicit act. Anything
that reads the plan can therefore audit exactly what would happen
without anything happening.

## The safety properties, and what enforces each

**A visitor can never land on a real account.** Every granted name is
prefixed, so a packet claiming `ritz` produces `view-ritz`. The prefix is
not decoration: without it, the first person to knock as an existing user
would have that user's password reset.

**An account that is not ours is never touched.** Before acting, the plan
checks whether the target name already exists, and whether it belongs to
the dedicated group all granted accounts are placed in. An existing name
outside that group stops the grant with an error rather than proceeding.

**A credential does not outlive its visit.** Expiry cannot depend on the
granting process still being alive, because a process can be killed. Each
grant records its expiry to a file, and a sweeper — run on a timer and
again at every daemon start — removes anything past it. The daemon's own
timer is the fast path; the sweeper is the guarantee.

**Nothing is written to the account.** The home directory is the jail
described in phase 3, owned by root, and the shell is one that cannot
run.

## The shape of the data

**A grant record**, one per live account:

| field | type | meaning |
|---|---|---|
| `account` | string | the prefixed system account name |
| `asked_as` | string | the name from the packet, unprefixed |
| `window` | integer | the window the packet used |
| `granted` | integer | unix seconds when created |
| `expires` | integer | unix seconds after which it must be gone |

Records live in the RAM tier, so a reboot leaves none behind — a machine
that has just come up has no accounts owing removal, because it has no
accounts.

**A plan step**:

| field | type | meaning |
|---|---|---|
| `command` | string | one command, complete, already quoted |
| `because` | string | why this step exists, in a sentence |

## Suggested implementation steps

1. **Account naming.** Prefix, and a check that the prefixed result is
   still a permissible system name after prefixing — the length cap in
   phase 1 exists to leave room for this.

2. **Inspection, separately from action.** Functions answering: does this
   account exist, and is it one of ours. Both read-only, both usable by
   the sweeper as well as the grant.

3. **The creation plan.** Ordered steps: create the group if absent,
   create the account with no valid shell and the jail as its home, set
   the derived password, record the grant. Each step carries its reason.

4. **The removal plan.** Ordered steps to take an account away, written
   so that running it twice is harmless — a grant that was already
   removed must not turn the sweeper into an error loop.

5. **The sweeper.** Read the records, compare against now, and produce
   removal plans for everything past its expiry. Also removes records
   whose account has already gone, so the file cannot grow forever.

6. **The runner.** The one place a plan is executed, refusing unless
   explicitly armed, and stopping at the first failing step rather than
   carrying on. A partially applied plan is reported as such, because
   the alternative — carrying on past a failed account creation and
   setting a password on something that is not there — is how a grant
   half-exists.

7. **Tests.** Plans are generated and inspected without being run:
   prefixing; refusal on a foreign account; a removal plan that is safe
   twice; the sweeper picking exactly the expired records and no others;
   the runner refusing when not armed.

## Related

- [The grant](../docs/002-the-grant.md) — datapath
- [The arrangement](../docs/001-the-arrangement.md) — supplies the name
  and the window, and derives the password
- Phase 3, [the room](../docs/003-the-room.md), is what the account opens

## Open questions

- **How long does a grant live?** Long enough to log in and look around;
  short enough that a forgotten one is not a standing door.
- **What happens to a session already open when its account expires?**
  Removing an account does not close its live sessions. Killing them is a
  second, separate act, and whether to do it is undecided.
- **One account per visitor, or one per knock?** Re-knocking while a
  grant is live could extend it, replace it, or be refused. Each reads
  differently to somebody whose connection dropped.
- **Where does the secret live on the listening machine**, and what reads
  it? It is the one thing whose disclosure hands over the whole
  mechanism.

## Status

In progress. Steps 1, 2, 3, 4, 6 and 7 are done. Step 5 is half done: the
sweeper works within one run of the doorman but does not recover records
written by a previous one. Nothing has been run armed, and phase 3 does
not exist, so a granted account cannot currently log in.
