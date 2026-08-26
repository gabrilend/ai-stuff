# The door and the private port

Every participant gets a port of their own on the server. Not a shared port with
many sockets on it -- a distinct listening port per person. This document says how
a person gets one, what the arrangement buys, and what it costs, because it costs
something real and the cost should be written down rather than discovered.

## Getting in

There is one port that is always open and always the same. Call it **the door**.
Its number is configuration, read from `input/`, and it is the only number a
participant needs to be told in advance.

The sequence:

1. The client connects to the door and sends a **join request**: who it claims to
   be, and a secret proving it.
2. The server checks the claim. If it fails, the reply is a sentence saying what
   was wrong, and the socket closes. There is no silent drop -- a participant who
   mistyped a password must be able to learn that they mistyped a password.
3. If it succeeds, the server picks an unused port from a configured range, binds
   a listening socket to it, and records that this port belongs to this
   participant and to no one else.
4. The server replies with the port number, then closes the door connection. The
   door holds no session; it is a receptionist, not a room.
5. The client connects to the port it was given. The server accepts exactly one
   connection there and checks that it came from the address the join request came
   from.

From that point the participant's entire session is that one socket. The port
number *is* the identity.

### The join request, field by field

| Field | Type | Meaning |
| --- | --- | --- |
| `magic` | `uint32_t` | A fixed constant. A connection that does not begin with it is not our protocol and is closed immediately, so that a stray port scanner costs the server one comparison. |
| `version` | `uint16_t` | Protocol version. Mismatch is refused in words, naming both versions, because "it just disconnects" is the worst possible symptom of a version skew. |
| `name_length` | `uint16_t` | Byte length of the name. Bounded; a length past the bound is refused rather than clamped. |
| `name` | `char[]` | What this participant is called at the table. Display only -- never used to decide permission. |
| `secret` | `uint8_t[32]` | Proof of who they are. What this actually contains is an open question. |

Permission does **not** travel in the join request. A client cannot ask to be a
GM. The server looks up what this participant is allowed to command from its own
configuration, and the client is informed of the answer rather than consulted.
This is the difference between a permission model and a suggestion box. See
[who controls what](008-who-controls-what.md).

## What one port per person buys

**The port is the identity, resolved by the kernel.** When bytes arrive, the
operating system has already decided which socket they belong to, and the socket
was bound knowing whose it was. There is no session-token lookup in the receive
path -- no hash table, no scan, no chance of resolving to the wrong participant
because of a bug in that lookup. The identity question is answered before our
code runs, by code that has been correct for thirty years.

**The filtering context binds once.** Each participant's outbound stream is
filtered by what they are allowed to see. With a port per person, that filter is
attached to the socket at bind time and never re-selected. With one shared port,
every outbound message must carry "and who is this for?" and be right about it
every single time. One of those two designs can leak a secret through a
misthreaded parameter. The other cannot.

**Operations become legible.** `netstat` shows the table. Kicking a participant
is a firewall rule against one port. A packet capture on one port is one person's
session with nothing else interleaved.

## What it costs

**The host must open a range, not a port.** This is the real friction and there is
no way to argue it away. A host behind a home router forwards the door port plus
a contiguous range wide enough for the table. That is a longer conversation with
a router's web interface than forwarding one port is.

**Ports are a resource with a lifetime.** A participant who drops leaves a bound
socket behind. Without a reclaim policy the range fills up and the next person is
refused for no reason they can understand. So: a port is released when its socket
closes, and a port that was bound but never connected to is released after a
timeout. Both of those are things that must be *built*, not assumed -- and the
refusal, when the range really is full, says "the range is full" and names the
range, rather than saying "cannot join".

**The count of open ports leaks the size of the table.** Anyone who can scan the
host learns how many people are connected. Not who, not what -- just how many.
This is accepted rather than solved.

## The open question

Why one port per person at all, rather than one port and many sockets on it? The
reasons above are real, but they were assembled after the decision rather than
before it, and that is worth being honest about. The counter-case -- that one
listening socket with a well-tested dispatch is simpler, needs no port range, and
crosses NAT without a conversation -- has not been argued out yet. It is in
[open questions](016-open-questions.md) and it is not settled.

## Read next

- [Who controls what](008-who-controls-what.md) -- what the server looks up once
  a participant is through the door.
- [What a viewer is allowed to know](009-what-a-viewer-is-allowed-to-know.md) --
  the filter that binds to the socket.
