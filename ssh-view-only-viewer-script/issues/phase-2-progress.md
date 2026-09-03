# Phase 2 — The grant

Bringing a credential into existence on a good verdict, and taking it
away when its time is up. The only part needing root.

## Where the phase stands

| issue | what it is | status |
|---|---|---|
| 200 | the grant | in progress — plans built and tested; nothing has ever been run armed |

Thirty-three tests pass, and **not one of them creates an account**.

## What the phase has taught

**Making the privileged part a value made it testable.** The grant
produces a plan — an ordered list of commands, each carrying the reason
it exists — and running one is a separate act that must be armed. Because
a plan is data, an unprivileged test suite can read every command that
would run, assert the password does not appear in it, assert the removal
is safe twice, and assert the account is placed in the right group,
without ever touching the system. The privileged code is the most tested
code here precisely because it does not execute.

**The prefix is not decoration.** Without it, the first person to knock
claiming an existing user's name would have had that user's password
reset. With it, they get a new account beside them. The 24-character name
cap in phase 1 exists solely to leave room for it, and prefixing that
would exceed what Linux accepts is refused rather than truncated —
because a silently shortened name is how two visitors end up sharing one
account.

**Group membership, not the prefix, is the test for ownership.** A prefix
is a convention anything could adopt; membership of the group is
something only a privileged act could have arranged. An account wearing
the prefix but outside the group belongs to somebody else and is left
alone.

**Expiry cannot be the running process's job.** A process can be killed,
and an account that outlives its visit is a door with nobody watching it.
So the sweep runs on the listener's heartbeat *and* at every startup, and
the startup sweep is the one that matters — it removes what a killed
doorman left behind. This is also why the listener's read has a timeout:
without one, a machine nobody knocks at would never sweep.

**Stopping at the first failed step matters more than it looks.**
Carrying on past a failed account creation would set a password on
something that is not there and report success for a grant that half
exists. The runner returns how far it got so the caller can undo.

## Open questions carried by this phase

- How long does a grant live? Fifteen minutes, unexamined.
- What happens to a session already open when its account expires?
  Removing an account does not close live sessions.
- One account per visitor, or one per knock? Re-knocking currently leaves
  a live grant alone; it could extend or refuse instead.
- Where should the secret live? It is in `input/secret`, and the doorman
  refuses to start if group or other can read it.
