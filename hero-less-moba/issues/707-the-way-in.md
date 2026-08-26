# 707 — The Way In

| | |
| --- | --- |
| Phase | 7 — Watching It Happen |
| Blocked by | 701, 802 |
| Blocks | 906 |
| Reads | [the viewing layer](../docs/017-the-viewing-layer.md) |
| Open questions | none |

## Current behavior

The game starts by being run with a scenario or a match configuration. There is
no way in that does not involve a command line.

## Intended behavior

The screens before the match: a **main menu**, and the road from it to a lobby
and into a game.

Small, and it should stay small. What it owes:

- **Play** — into the lobby from issue 802, or straight into a single-player
  match against the bots from phase 9.
- **Scenarios** — the list from issue 110, loaded and held at the gate. This is
  how anybody who is not at a command line looks at the middle of a match.
- **Replays** — open one and watch it, with the same viewer the live game uses.
- **Settings** — and one of them matters more than the rest here: the resource
  display types. Every bounty colour has its own shape as well as its own hue
  (F30), and a player who needs that dialled further needs it in this menu.
- **Out.**

### The rule this screen has to obey

**Nothing here is game state.** The menu is a viewer that writes commands, like
every other part of the viewing layer — it chooses a match to start and then gets
out of the way. It does not hold a partially-built world, it does not keep a
"current game" of its own, and the simulation never knows it existed.

That is the same line drawn in [the viewing layer](../docs/017-the-viewing-layer.md)
and it is easiest to cross here, because a menu feels like the thing that owns
the game. It is not. It is a thing that picks a file.

### And it is skippable, always

**Every path this menu offers must also be reachable without it.** A flag that
boots straight into a named scenario or a named match configuration, held at the
gate, with no menu drawn at all.

Not a convenience — a requirement. Development, the batch runner from issue 804,
and every automated test start a game thousands of times without a person
present, and a menu that cannot be bypassed is a menu that gets bypassed by a
second code path nobody tests.

## Suggested implementation steps

1. Build the menu as a viewer state, sharing the window and input handling from
   issue 701. Not a separate program and not a separate loop.
2. Add the boot flags first — `--scenario <name>`, `--match <file>` — and make the
   menu call exactly those, so the bypass is the primary path and the menu is a
   caller of it.
3. Wire the scenario list from `scenarios/`, read at startup, with the same
   validator refusing a broken one by name rather than hiding it.
4. Put the resource display-type settings in, and default them to the shapes
   rather than to hue-only. A colourblind player should never have to find this
   screen to play; it should already be readable.
5. Write a test that boots to a named scenario with the menu disabled and reaches
   the gate, so the bypass is covered by something other than habit.

## Related documents and tools

- [The viewing layer](../docs/017-the-viewing-layer.md)
- Issue 110 — the scenarios this lists
- Issue 802 — the lobby it leads to
