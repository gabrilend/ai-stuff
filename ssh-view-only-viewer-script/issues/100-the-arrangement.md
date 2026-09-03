# 100 — The arrangement

## Current behavior

Built and tested. Forty-nine tests pass.

The module validates a name against a small allowlist, maps a moment to a
time window, computes and constant-time-compares digests, shapes a packet
for sending, derives the account password from the same secret, and
renders a verdict on a received packet. A packet built in one process is
accepted by another over UDP; every malformed, stale, edited or
wrong-secret packet is refused with its own reason.

The password derivation was added during the work and was not in the
original steps. It replaced a reply path: rather than the machine
inventing a password and sending it back, both ends compute it from the
secret and the window. The listening machine now never replies at all.

All four open questions below remain unanswered.

## Intended behavior

A module that takes the bytes of one received packet and answers a single
question: **should this cause a credential to be created, and for whom?**

It answers with a name, or with a refusal and a reason. It has no
side effects, touches no accounts, opens no sockets, and can be tested
without privileges or a network. Everything downstream fires on its
verdict, which is why it is phase one — a grant triggered by a wrong
"yes" is the worst outcome this project has.

## What a packet carries

Three fields, separated by single spaces, in one datagram:

```
<name> <window> <digest>
```

| field | type | meaning |
|---|---|---|
| `name` | string | who is asking; becomes the account name |
| `window` | integer | which time window the sender believes it is |
| `digest` | string | 64 lowercase hex characters, sha256 |

The digest is taken over the shared secret, the name, and the window
joined by a separator that cannot occur in a name:

```
sha256( secret .. "|" .. name .. "|" .. window )
```

The **window** is the unix time divided by a fixed period and rounded
down, so both ends compute the same number without having to agree on a
clock to the second. The receiver accepts the window it is currently in
and the one before it, which tolerates a sender whose clock is behind and
a packet that spent time in flight.

## Why this shape

**The secret never travels.** Only a digest of it does, so watching the
wire does not reveal it. A different name or a different window produces
an unrelated digest, so a packet cannot be edited into one for somebody
else.

**Replay is bounded rather than eliminated.** A copied packet stays valid
until its window passes. Making it single-use would mean the receiver
remembering every digest it has honoured, which is state that has to live
somewhere and be reaped — worth doing later, not worth doing before the
thing works. The window length is therefore the replay exposure, stated
out loud rather than hidden.

**The name is constrained before it is trusted.** It becomes a Unix
account name, so it is checked against a narrow pattern — lowercase
letters, digits, hyphen and underscore, first character a letter, capped
in length — before any digest is computed. A name that fails is refused
without further work. This check exists because the name is the one field
that crosses from the packet into a command line.

## Suggested implementation steps

1. **Name validation, written first and alone.** A function answering
   whether a string is a permissible account name. Tested against: empty,
   too long, leading digit, leading hyphen, uppercase, embedded space,
   embedded newline, a shell metacharacter, a path separator, a NUL byte,
   and the pipe character used as the digest separator.

2. **The window function.** Unix seconds to window number, and the set of
   windows a receiver will accept at a given moment.

3. **The digest.** Compute sha256 over the joined string. Compare with a
   comparison that does not return early on the first differing byte, so
   that how long a comparison takes says nothing about how much of a
   guess was right.

4. **Parse and verdict.** Split a received string into three fields,
   refuse anything with the wrong field count or a malformed digest, then
   run the checks in order — cheapest and most constraining first — and
   return the name or a reason.

5. **Tests.** Each refusal reason reached deliberately; a genuine packet
   accepted; the same packet accepted in the previous window and refused
   two windows later; a packet whose name is edited refused; a packet
   whose digest is edited refused; the sender and receiver agreeing when
   both are asked to build and check the same packet.

## Related

- [The arrangement](../docs/001-the-arrangement.md) — datapath
- [What this project is](../docs/000-what-this-project-is.md)
- Phase 2, [the grant](../docs/002-the-grant.md), consumes the verdict

## Open questions

- **How long is a window?** It is the replay exposure. Thirty seconds is
  short enough to be uninteresting and long enough to survive clock skew
  between machines that are not synchronised.
- **One secret, or one per visitor?** One secret means anyone holding it
  can claim any name, so the name is a label rather than an identity. A
  secret per visitor makes the name meaningful and means distributing and
  storing several.
- **Should honoured digests be remembered**, making a packet single-use?
  That is the difference between bounded replay and none, at the cost of
  state that must be reaped.
- **What carries the packet?** UDP needs a socket and an open port. An
  ICMP echo payload needs no port at all but needs a raw socket, and so
  needs privilege to listen. The vision says "a certain kind of ping",
  which suggests the second.

## Status

In progress. All implementation steps are done. The four open questions
above are unanswered, and the ICMP carrier the vision implies is not
built.
