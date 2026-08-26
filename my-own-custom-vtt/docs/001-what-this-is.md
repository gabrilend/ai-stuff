# What this is

A virtual tabletop. Several people sit at different computers and share one
imaginary space: a dungeon, a forest, a town with taverns in it. Things stand in
that space. People move the things. Some people can see more of it than others,
and that asymmetry is the point rather than an inconvenience.

It is **system-agnostic**. The program knows about space, sight, things, and
permission. It does not know what a saving throw is, what a hit point is, or how
initiative works. Those live in a ruleset that is loaded at startup, the same way
a font is loaded. Swapping the ruleset changes the game without recompiling the
server.

## The one-sentence version of each piece

**The world is geometry, not a picture.** A wall is a line segment with
coordinates, not dark pixels on a bitmap. This is the decision everything else
rests on: because a wall is a segment, sight can be computed from it; because
sight can be computed, fog can be per-person; because fog is per-person, the
server can refuse to send you what you cannot see.

**Sight is a security boundary.** When a player cannot see around a corner, the
bytes describing what is around that corner never leave the server. Not sent and
hidden by the client -- never sent. A client that has been tampered with learns
nothing, because it was never told anything.

**Control is a scope, not a role.** There is no fixed list of "player, GM". There
is a number: how much of the world does this connection command? One body, moved
with the keyboard. A handful of bodies, moved the way a strategy game moves them.
Every coffee cup and goblin patrol inside one tavern. The entire map. These are
positions on one dial, and the program implements the dial rather than four
special cases.

**The picture moves.** The client is not a viewer for a static map image with
tokens dragged across it. It draws a world that is animating: torches flicker,
patrols walk their routes, a door swings. What the server sends is world state,
and the browser turns state into motion.

**Everything that can be generated, is.** Maps, dungeons, props, patrol routes.
Nothing important is hand-placed in a file that nobody dares regenerate.

## The shape of the running system

Three programs, never two, never one:

| Program | Language | Where it runs | What it is responsible for |
| --- | --- | --- | --- |
| **The server** | C | One machine, the host's | The authoritative world. The only place where truth lives. Decides what each viewer is allowed to know. |
| **The client** | C | Each participant's own machine | Holds one socket to the server, and serves a browser on `localhost`. A bridge, not a brain. |
| **The view** | Browser | Each participant's browser | Draws the world, animates it, and turns keys and clicks into commands. Holds no truth. |

You do not host anything by joining. You run the client with the server's address
and your port; it connects outward; you open `localhost:12345` and you are at the
table. The world is on the host's machine the whole time. Described in detail in
[the three programs](002-the-three-programs.md).

## What the project is actually for

This is a software design project. It is not a product, and the measure of
success is not how many groups use it. The measure is whether the pieces above
stay separable: whether sight can be rewritten without touching the network,
whether the ruleset can be swapped without touching sight, whether the browser
can be replaced with a terminal renderer and the server not notice.

Every one of those is a claim, and claims get tested. See
[the roadmap](015-roadmap.md) for the order they get built in, and
[open questions](016-open-questions.md) for the ones that are not settled.

## Where to read next

- [The three programs](002-the-three-programs.md) -- the split, and why the
  client exists at all rather than the browser talking straight to the server.
- [The door and the private port](003-the-door-and-the-private-port.md) -- how a
  person becomes a connection.
- [The world and its tick](004-the-world-and-its-tick.md) -- what the server
  holds and how time passes in it.
- [Who controls what](008-who-controls-what.md) -- the dial.
