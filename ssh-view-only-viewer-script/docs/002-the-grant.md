# The grant

Bringing a view-only account into existence, and taking it away.

## It does not act — it writes down what acting would be

The grant produces a **plan**: an ordered list of commands, each with the
reason it exists attached. Running the plan is a separate act that has to
be armed. Unarmed — the default — the doorman does everything except the
privileged part, and prints the commands instead:

```
1. the group is how a granted account is later recognised as ours
     getent group 'viewonly' > /dev/null || groupadd 'viewonly'
2. no home is made: the room already exists and belongs to root
     useradd --no-create-home --home-dir '/srv/viewing/view-ritz' \
       --shell '/usr/sbin/nologin' --gid 'viewonly' 'view-ritz'
3. the password arrives by standard input, never on a command line
     printf '%s:%s' 'view-ritz' "$VIEWER_PASSWORD" | chpasswd
  not armed -- nothing was run
```

This is why the only part of the project needing root can be tested
exhaustively by an unprivileged test suite: a plan is a value, so a test
reads it instead of running it.

## The four safety properties

**A visitor can never land on a real account.** Every name is prefixed —
`ritz` becomes `view-ritz`. Without the prefix, the first person to knock
as an existing user would have that user's password reset. Prefixing that
would exceed what Linux accepts is refused rather than truncated, because
a silently shortened name is how two visitors end up sharing one account.

**An account that is not ours is never touched.** The test is membership
of a dedicated group, not the prefix. A prefix is a convention anything
could adopt; the group is something only a privileged act could have put
an account into. An account wearing our prefix but outside the group
belongs to something else, and the grant stops.

**The password never appears on a command line.** It reaches `chpasswd`
through the environment and then standard input. Command lines are
visible to every process on the machine through the process list;
standard input is not.

**A credential does not outlive its visit.** Expiry cannot depend on the
granting process still being alive, because a process can be killed. Each
grant is recorded, and a sweep runs on the listener's heartbeat and again
at every startup. The startup sweep is the one that matters — it is what
removes accounts left behind by a doorman that was killed rather than
stopped.

## Removal is safe to run twice

The sweeper will sometimes try to remove something a previous sweep
already removed. That race is not worth preventing, so the removal plan
treats absence as success rather than as an error — otherwise one stale
record would turn into a failure repeating forever.

The home directory is deliberately left alone, and `userdel` is told so
explicitly rather than relying on the default, which has differed between
distributions. The home is [the room](003-the-room.md): it belongs to
root, and it is shared configuration rather than this account's property.

## A plan stops at its first failure

Carrying on past a failed account creation would mean setting a password
on something that is not there, and reporting success for a grant that
half exists. The runner returns how many steps it got through, so a
partial application can be undone.

## Open questions

- **How long does a grant live?** Fifteen minutes at present. Long enough
  to connect and look; short enough that a forgotten one is not a
  standing door.
- **What happens to a session already open when its account expires?**
  Removing an account does not close its live sessions. Killing them is a
  separate act and it is not decided whether to.
- **One account per visitor, or one per knock?** Re-knocking while a
  grant is live currently leaves it alone. It could instead extend it, or
  be refused. Each reads differently to somebody whose connection dropped.
- **Where does the secret live, and what may read it?** It sits in
  `input/secret` and the doorman refuses to start if it is readable by
  group or other. Whether that is the right home is unsettled.
