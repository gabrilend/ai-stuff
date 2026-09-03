# 006-the-arrangement.lua

Decides whether an arriving packet is a genuine request for a look at
this machine, and who is asking. Creates nothing, opens nothing,
remembers nothing.

Returned by `dofile` as a table.

## Values

| name | type | meaning |
|---|---|---|
| `WINDOW_SECONDS` | integer | how long one time window lasts (30). **This is the replay exposure.** |
| `NAME_MAX` | integer | longest permissible name (24), leaving room for the grant's prefix |

## arrangement.name_is_permissible(name)

Whether a string may be used as an account name. Runs before anything
else on every packet, because the name is the one field that travels from
a stranger's datagram toward a command line.

| | type | meaning |
|---|---|---|
| in `name` | string | candidate |
| out | boolean | true only for `^[a-z][a-z0-9_-]*$`, 1 to 24 characters |

An allowlist, so an unconsidered character is refused by default. Refuses
a leading digit, a leading hyphen (which every command would read as an
option), uppercase, spaces, newlines, shell metacharacters, path
separators, NUL, and the pipe used as the digest separator.

## arrangement.window_of(unix_seconds)

| | type | meaning |
|---|---|---|
| in | number | unix seconds |
| out | integer | `floor(seconds / WINDOW_SECONDS)` |

## arrangement.acceptable_windows(unix_seconds)

| | type | meaning |
|---|---|---|
| out | array of 2 integers | the current window and the previous one |

The future is never honoured — that would let a fast clock mint a
longer-lived packet.

## arrangement.digest(secret, name, window)

`sha256(secret .. "|" .. name .. "|" .. window)`, 64 lowercase hex.

Raises rather than returning on an impermissible name or an empty secret.
The secret reaches `sha256sum` on standard input, never as an argument,
because arguments are visible in the process list.

## arrangement.password_for(secret, name, window)

The password the account will be given — **derived, never sent.**

| | type | meaning |
|---|---|---|
| out | string | 32 lowercase hex characters (128 bits) |

`sha256(secret .. "|password|" .. name .. "|" .. window)`, truncated. The
literal label is why this can never equal the knock digest that
travelled on the wire.

## arrangement.digests_match(left, right)

Constant-time comparison. Walks the whole string every time, so how long
a rejection takes says nothing about how much of a guess was right.

## arrangement.build(secret, name, unix_seconds)

The sending half. Returns the packet string. Kept beside the checking
half so the two cannot drift apart.

## arrangement.verdict(secret, packet, unix_seconds)

The decision.

| | type | meaning |
|---|---|---|
| in `packet` | string | as received |
| out 1 | string or nil | the name, if genuine |
| out 2 | string | present only on refusal: why |

Refusal reasons are **for the machine's operator only** and must never be
sent back — telling a stranger which field was wrong is how a secret is
found one field at a time.

Refuses: non-text, over 256 bytes, not three space-separated fields, an
impermissible name, a digest that is not 64 hex characters, a
non-integer window, a window outside the honoured pair, and a digest
that does not match.

## Notes

- LuaJIT (5.1). No fallbacks — an unrunnable `sha256sum`, an empty
  secret, or an impermissible name raise rather than degrade.
- Tests in `009-test-the-arrangement.lua`.
