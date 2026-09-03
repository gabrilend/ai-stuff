# The arrangement

What a packet is, and how the listening machine decides one is genuine.

## The packet

Three fields, single spaces between them, one datagram:

```
ritz 59613176 83e247731033d6e9c044d22ce992f443664cb56de0c3c4accdb931ed28ecbde1
 |      |                              |
 |      |                              the digest, 64 hex characters
 |      the window the sender believes it is
 who is asking -- this becomes the account name
```

The digest is `sha256(secret | name | window)`. The secret never travels;
only a digest of it does.

## The window

Both machines divide the clock by a fixed period — thirty seconds — and
round down. That gives them the same number without needing to agree on
a second, which matters because two machines on a LAN are not
necessarily synchronised and nothing here should require them to be.

The receiver honours **the current window and the one before it**. The
previous one covers a sender whose clock is a little behind and a packet
that spent time in flight; without it, a packet sent in the last moment
of a window would be refused for no reason its sender could observe.

The *next* window is deliberately not honoured. Accepting a future
window would let anyone with a fast clock — or anyone who simply chose a
large number — mint a packet that stays good for longer than a window
lasts.

**This period is the replay exposure.** A copied packet works until its
window ends. Making a packet single-use would mean remembering every
digest already honoured, which is state that has to live somewhere and be
reaped; the window length is the cost of not doing that, stated plainly
rather than hidden.

## The name is checked before anything else

The name becomes a Unix account name, so it is the one field that
travels from a stranger's datagram out toward a command line. It is
checked against a small allowlist — lowercase letters, digits, hyphen,
underscore, a letter first, at most 24 characters — and anything else is
refused.

An allowlist rather than a list of forbidden things, so a character
nobody thought about is refused by default instead of permitted by
default. The leading-letter rule is not tidiness: a name beginning with a
hyphen would be read as an *option* rather than an argument by every
command it was ever passed to.

The 24-character cap exists to leave room for the prefix
[the grant](002-the-grant.md) adds, so that prefixing can never push a
name past what Linux accepts and force a silent truncation.

## The password is derived, never sent

This is the part that removes the need for a reply.

```
password = first 32 hex of sha256( secret | "password" | name | window )
```

Whoever shaped the packet already holds the secret and knows which
window they used, so they compute the password themselves at the moment
they knock. The listening machine computes the same value and sets it.
Nothing about the password crosses the network, and there is no return
channel to arrange, to block, or to spoof.

The literal word `password` is folded in so this can never equal the
knock digest for the same name and window. Without it, the digest a
stranger watched go past on the wire would *be* the password. And because
no permissible name may contain a pipe, no name can impersonate that
label.

## What the machine says back

Nothing. A wrong packet produces no reply at all, so from outside, a
machine that is listening and a machine that is not look identical.
Refusal reasons are printed for the machine's own operator and never
sent, because telling a stranger which field they got wrong is how a
secret is found one field at a time.

## Open questions

- **How long should a window be?** Thirty seconds is short enough to be
  uninteresting to replay and long enough to survive unsynchronised
  clocks. It has not been tested against machines that actually drift.
- **One secret, or one per visitor?** One secret means anyone holding it
  can claim any name, so the name is a label rather than an identity.
- **Should honoured digests be remembered**, making replay impossible
  rather than merely brief?
- **What carries the packet?** UDP works and is built. The vision says
  "a certain kind of ping", which means ICMP — and reading ICMP needs a
  raw socket, which LuaSocket does not offer, so it would need a small C
  helper or a privileged capability. Not built.
