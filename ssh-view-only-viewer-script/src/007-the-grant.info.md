# 007-the-grant.lua

Brings a temporary view-only account into existence and takes it away.
**Produces plans; does not act.** Running a plan is separate and must be
armed.

## Values

| name | type | meaning |
|---|---|---|
| `PREFIX` | string | `view-`; why a packet naming a real user cannot reach that user |
| `GROUP` | string | `viewonly`; membership is the test for "we made this" |
| `LIFETIME_SECONDS` | integer | 900 |
| `NOLOGIN_SHELL` | string | `/usr/sbin/nologin` |

## grant.account_for(asked_as)

Prefixes a name. **Raises** rather than truncating if the result exceeds
32 characters, because a silently shortened name is how two visitors
share one account.

## grant.account_exists(account) / grant.account_is_ours(account)

Read-only inspection. `account_exists` asks `getent`, not `/etc/passwd`,
because an account can live in a directory service the file knows nothing
about. `account_is_ours` tests group membership, not the prefix — a
prefix is a convention anything could adopt.

## grant.creation_plan(account, password, home)

| | type | meaning |
|---|---|---|
| out | array of step | ordered commands |

A **step** is `{ command = string, because = string }`.

Three steps: ensure the group, create the account with no usable shell
and no home made, set the password. The password does **not** appear in
the plan text — the command reads `$VIEWER_PASSWORD`, supplied through
the environment at run time.

Raises on an empty password or a relative home.

## grant.removal_plan(account)

One step, safe to run twice — absence is the desired state, so an account
already gone is success. Does not remove the home directory; that is the
room, and it belongs to root.

## grant.expired(records, now)

| | type | meaning |
|---|---|---|
| in `records` | array of record | live grants |
| out | array of record | those at or past their expiry |

A record expiring exactly now **is** expired; the boundary belongs to
removal rather than to one more tick of access.

A **record**: `account`, `asked_as`, `window`, `granted`, `expires`.

## grant.record_for(asked_as, window, now) / grant.describe(plan)

`record_for` builds a record. `describe` renders a plan as readable text.

## grant.run(plan, armed, environment)

The one place a plan executes.

| | type | meaning |
|---|---|---|
| in `armed` | boolean | false does nothing |
| in `environment` | map or nil | prefixed onto each command |
| out 1 | boolean | applied |
| out 2 | string | what happened |
| out 3 | integer | steps completed |

Stops at the first failure — carrying on past a failed account creation
would set a password on something that is not there. The third return
says how far it got, so a partial application can be undone.

## Notes

- Tests in `010-test-the-grant.lua`, all of which read plans rather than
  running them. The privileged part is tested by an unprivileged suite.
