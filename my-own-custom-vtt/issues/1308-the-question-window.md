# 1308 -- The question window, and the DM is its gate

**Phase:** 13, the world becomes solid
**Blocked by:** [1303](1303-visibility-is-one-equation.md)
**Blocks:** [1309](1309-the-phase-13-demo.md)
**Documents:** [the question window](../docs/111-the-question-window.md),
[the rules layer](../docs/011-the-rules-layer.md),
[who controls what](../docs/008-who-controls-what.md)

## Current behaviour

There is no chat. A participant sends commands and receives filtered updates, and
everything they might want to *ask* -- is there a draft under the door, does this
crest mean anything to my character, can I reach the sconce -- has nowhere to go.

The rules layer can answer questions the ruleset anticipated. It cannot answer a
question nobody wrote down.

## Intended behaviour

**A window a participant opens with a key, whose contents go to the DM first.**

| Key | Opens it for |
| --- | --- |
| `shift+space` | a player |
| `shift+~` | a commander |

The DM reads the request and either answers it themselves, or passes it to an AI
that has tool calls into the game.

### The pause is not a failure

When the DM decides to build something rather than approve it, **play stops for a
moment**. That is normal at a table and it is not dead time -- it is where
characters talk to each other, and it is a large part of why people come.

The design should not try to eliminate it. It should make it obvious that it is
happening, so nobody is waiting on a frozen screen wondering whether the program
has crashed.

### The AI gets the DM's verbs and no others

**The AI must be incapable of anything the DM could not have done by hand.** The
DM is delegating authority, so the tool surface is exactly the authority being
delegated.

Three things follow:

- The approval step means something. You are approving a request that will be
  executed with your permissions.
- Everything the AI does lands in the command log like every other command, and
  is undoable by the rollback phase 3 built and the unwind phase 12 built.
- There is no second permission system to keep in agreement with the first.

### The AI is ignorant by computation, not by policy

Nobody has to remember to hide the locked drawer from it.

> every AI could tell that you can open a drawer. This one has a lock on it,
> which the player AND THE AI learn when it's pulled and it's "open" verb hits a
> 0 in the unlocked part of it's calculation equation. A*B+(1-A)*C foreverrrr

`A*B + (1-A)*C` is a branchless select: with `A` at 1 the result is `B`, with `A`
at 0 it is `C`, and no branch is taken either way. It is the dispatch-table
principle written as arithmetic -- the same reason this project prefers a table
of functions to a chain of `if`.

Applied to a verb, `A` is *unlocked*, `B` is what opening does, and `C` is what
the drawer does instead. **The AI does not read the world and get told the drawer
is locked. It evaluates the same expression the player's action evaluates, and
finds a zero.** Its ignorance is a consequence of the arithmetic rather than a
rule somebody has to maintain.

And because `A` need not be 0 or 1, the same expression gives partial states for
free: a drawer that is half stuck is `A` somewhere in between, and it blends. The
same shape as the reveal gradient in
[1304](1304-the-reveal-is-a-distance-field.md).

### It is the answer to what authored visibility gave up

Authored visibility means nobody glimpses a sliver of something the DM did not
plan. The window puts discovery back, in a form geometry never had: a raycast
cannot answer *is there a draft*, *does it smell of smoke*, *would my character
know this crest*. A conversation can.

## Suggested implementation steps

1. The window in the view, and a message type on the wire. Both keys open the
   same window; which one was pressed is what the request carries.
2. The request queue on the DM's screen, with approve, answer, and refuse.
3. The verb table, shared by the DM's own controls and the AI's tool surface.
   **One table. If they are ever two tables, this is broken.**
4. Every AI action enters the command log through the same door as a keystroke.
5. The pause, shown to everybody, so a table knows it is waiting on a person.
6. A test that the AI cannot name a verb the DM does not have, and a test that an
   AI action is undone by an ordinary rollback.

## Open, and blocking the build rather than the design

**Which model, and running where.** "A local AI" reads as something on the host's
machine rather than a hosted call, and those are different programs: a local
runtime and a small model, against an HTTP client and a key.

It matters more than it looks, because this project's host is somebody's laptop
running a game for their friends. A local model costs no money and no network and
gives up capability; a hosted one is the other way round. If it is hosted, the
approval gate is a first-class thing in the tool-calling loop rather than
something to build -- the loop offers a per-turn hook for exactly this, so the
DM's approval sits between the model asking and the tool running.

Not decided. See the open questions.
