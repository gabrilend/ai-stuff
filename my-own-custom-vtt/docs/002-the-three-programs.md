# The three programs

There are three programs and they are never merged. This document says what each
one is, what it is forbidden from doing, and why the middle one exists at all --
because the middle one is the piece that surprises people.

## The server

A single C process on the host's machine. It holds the world: every wall, every
thing standing in the space, every scrap of who-knows-what. It is the only place
in the entire system where a fact is true. Everything else holds a copy or a
filtered view, and knows it.

The server never draws anything. It has no concept of a pixel, a colour, or a
sprite. If you asked it what a goblin looks like it would not understand the
question; it knows the goblin is at a coordinate, that it belongs to a control
scope, and that it has a ruleset-defined record attached to it. Appearance is the
view's problem.

This is the generate-then-view split from
[strategems](../strategems/patterns-that-keep-working), applied at the largest
scale in the project. When a goblin is in the wrong place there is exactly one
program to look in, and when a goblin is in the right place but drawn wrong there
is exactly one other program to look in. Without the split those two bugs are
indistinguishable.

## The client

A small C program on each participant's own machine. It does exactly two things:

1. Holds one TCP socket open to the server, on that participant's private port.
2. Listens on a local port -- `12345` by default -- and serves the browser that
   the participant opens.

That is the whole job. It holds no authority. If the client and the server
disagree about where a goblin is, the server is right by definition and the
client discards what it thought.

### Why the client exists

The obvious design is to delete it: let the browser open a websocket straight to
the server. Here is what that costs, and why the extra program is cheaper than it
looks.

**The browser would need to be served from somewhere.** A browser will not open a
page out of nothing; the HTML, the script, and the assets have to arrive over
HTTP from a server that speaks HTTP. Making the C server speak HTTP means putting
a web server inside the authoritative simulation, which is the single largest
source of remote vulnerabilities you could choose to add to it. With the bridge,
the HTTP server is a separate process on the participant's own machine, serving
files to exactly one person -- itself. An HTTP bug there compromises the person
who already had the files.

**The connection would have to be secured.** A browser talking to a remote host
over a websocket wants TLS, which means certificates, which means either a real
domain name and a certificate authority, or teaching every participant to click
through a warning. A browser talking to `localhost` is exempt: browsers treat
loopback as a secure context, because the bytes never touch a network card. The
bridge converts a hard problem (public TLS) into a solved one (a local socket).

**The wire format would be stuck.** A browser can speak websockets and HTTP and
nothing else. The server-to-client link, running between two C programs, can be
whatever is best: a packed binary struct, a shared ring buffer, something with a
fixed header the CPU can branch-predict. The bridge translates. The server's
protocol is free to be efficient because no browser has to parse it.

**Per-person work would land on the server.** Each participant's view needs
filtering -- what they can see, what their fog remembers. Some of that must
happen server-side, because that is the whole security argument. But the parts
that are merely *presentational* per-person can happen in the bridge, on the
participant's own CPU, and the host's machine does not pay for them once per
participant.

The cost is honest and worth stating: **every participant installs and runs a
program.** Not just a URL. This is a real barrier and it is the price of the four
things above.

## The view

A browser, pointed at `localhost:12345`. It receives world state from the bridge
and draws it, animated. It turns keys and clicks into commands and sends them
back. It holds no truth, and it is never trusted -- see
[what a viewer is allowed to know](009-what-a-viewer-is-allowed-to-know.md).

The view is the only part of the system not written in C, and that is deliberate.
It is also the only part that can be thrown away and rewritten without touching
anything else. A terminal renderer that speaks the same protocol is a legitimate
second view, and building one is how the separation gets proven rather than
merely claimed. That test lives in [the roadmap](015-roadmap.md).

## What flows between them

```
   world state, filtered per person        world state, drawn
  ┌────────────────────────────────┐   ┌─────────────────────┐
  │                                ▼   │                     ▼
┌─┴──────────┐                  ┌──────┴─────┐         ┌───────────┐
│   server   │                  │   client   │         │   view    │
│    (C)     │                  │    (C)     │         │ (browser) │
│  the truth │                  │  a bridge  │         │  a screen │
└────────────┘                  └────────────┘         └───────────┘
     ▲   │                            ▲   │                  │
     │   └── binary, private port ────┘   └── localhost ─────┘
     │                                                       │
     └──────────────── commands, travelling back ────────────┘
```

Commands travel right-to-left and are *requests*. The view asks. The server
decides, and may refuse. A refusal comes back as a sentence, never as silence --
see [commands enter through one door](010-commands-enter-through-one-door.md).

## Read next

- [The door and the private port](003-the-door-and-the-private-port.md) -- how
  the socket in the middle of that diagram gets established.
- [The dynamic picture](012-the-dynamic-picture.md) -- what the view actually
  does with the state it is handed.
