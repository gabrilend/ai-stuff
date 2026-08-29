# The question window

A participant presses a key and a window opens. What they write goes **to the DM
first**, who either answers it or passes it to an AI holding tool calls into the
game.

| Key | Opens it for |
| --- | --- |
| `shift+space` | a player |
| `shift+~` | a commander |

## The pause is part of it

When the DM decides to build something rather than approve it, play stops for a
moment. That is normal at a table and it is not dead time -- it is where
characters talk to each other, and a large part of why people come.

The design does not try to remove it. It makes it visible, so nobody is waiting
on a still screen wondering whether the program has died.

## The AI gets the DM's verbs and no others

**It must be incapable of anything the DM could not have done by hand.** The DM
is delegating authority, so the tool surface *is* the authority delegated.

- The approval step means something: you are approving a request that will run
  with your permissions.
- Every AI action lands in the command log like a keystroke, and is undone by the
  rollback and the unwind that already exist.
- There is no second permission system to keep in agreement with the first.

## It is ignorant by computation, not by policy

Nobody has to remember to hide the locked drawer.

    result = A*B + (1-A)*C

A branchless select. With `A` at one the answer is `B`; at zero it is `C`; no
branch is taken either way. It is the dispatch-table principle written as
arithmetic -- the same reason this project prefers a table of functions to a
chain of `if`.

For a verb, `A` is *unlocked*, `B` is what opening does, `C` is what the drawer
does instead. **The AI is not told the drawer is locked. It evaluates the same
expression the player's action evaluates and finds a zero**, and learns what the
player learns at the moment the player learns it.

And `A` need not be zero or one. In between gives a drawer that is half stuck,
for free, by the same arithmetic -- the same shape as the reveal gradient in
[visibility is one equation](110-visibility-is-one-equation.md).

## It is the answer to what authored visibility gave up

Nobody glimpses a sliver of something the DM did not plan, because there is no
geometry deciding what is seen. The window puts discovery back in a form the
geometry never had.

*Is there a draft under the door. Does it smell of smoke. Would my character
recognise this crest.* A raycast cannot answer any of those. A conversation can.

## Undecided

**Which model, and running where.** A local runtime with a small model costs no
money and no network and gives up capability; a hosted call is the other way
round. The host of this program is somebody's laptop running a game for their
friends, which is what makes it a real question rather than a preference.
