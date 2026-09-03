# Phase 1 — The arrangement

What a valid packet looks like, and how the listening machine tells a
genuine one from noise, a guess, or a copy.

## Where the phase stands

| issue | what it is | status |
|---|---|---|
| 100 | the arrangement | in progress — built and tested; four open questions |

Forty-nine tests pass. A packet built by one process is accepted by
another over UDP, and every way of presenting a packet that is not
genuine is refused with its own reason.

## What the phase has taught

**A separator has to be a character the fields cannot contain.** Joining
the name and the window with a pipe is only unambiguous because a
permissible name may not contain a pipe. Without that, the name `ab` with
window `1` and the name `a` with window `b1` join to the same string and
produce the same digest — two different requests a receiver could not
tell apart. The check that forbids the pipe and the joining that relies
on it are one decision in two places, and a test asserts they agree.

**Deriving the password removed a whole component.** The first sketch had
the machine invent a password and send it back, which needed a reply
path, which needed the reply to be protected, which needed the visitor to
be reachable. Computing the password from the same secret and window on
both sides deleted all of that. The machine now never replies at all —
which also means a wrong packet produces silence, so from outside a
listening machine and a silent one are indistinguishable.

**The label in the password derivation is load-bearing.** Folding the
literal word into the hash is what stops the password equalling the knock
digest for the same name and window. Without it, the digest a stranger
watched cross the wire *would be* the password. It is one string in one
line, and leaving it out would have been invisible in review — which is
why there is a test asserting the two values differ.

**Refusing the future costs nothing and closes a hole.** Honouring only
the current and previous windows means a sender with a fast clock cannot
mint a packet that outlives a window. Accepting the next window would
have looked generous and been a way to double a packet's life.

## Open questions carried by this phase

- How long should a window be? Thirty seconds is the current replay
  exposure, untested against machines that actually drift.
- One secret, or one per visitor? One secret means the name is a label
  rather than an identity — anyone holding it can claim any name.
- Should honoured digests be remembered, making replay impossible rather
  than merely brief?
- What carries the packet? UDP is built. The vision says "a certain kind
  of ping", meaning ICMP, which needs a raw socket LuaSocket does not
  offer — so it would need a small C helper or a privileged capability.
