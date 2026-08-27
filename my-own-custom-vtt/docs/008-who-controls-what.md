# Who controls what

There is no fixed list of roles. There is a dial, and the program implements the
dial rather than four special cases with four code paths.

## The dial

| Position | What it commands | How it is driven | The familiar name |
| --- | --- | --- | --- |
| One body | A single thing | Keys. You are that body; forward is where it is facing. | A player |
| A few bodies | A named handful | Select and order, the way a strategy game does. | A party, or a commander |
| A region | Everything standing inside a named area, including areas nested inside it | Select and order | The tavern's commander. The forest's. |
| The map | Everything | Select and order, plus the ability to reach past sight | A GM |

Read down that table and it looks like four systems. It is two facts:

**A scope's membership is decided by one of two rules.** Either a written list of
things, or a region and everything inside it. "One body" is a written list of
length one. "The map" is a region that is the whole map. There is no third rule
and no fourth.

**A scope's driving style is a separate axis.** Whether you push a body around
with the keyboard or issue it orders is about input, and about how many bodies
there are, and it has nothing to do with what you are permitted to touch. A GM
can drive one goblin with the keys. A player with a party of four gets the
strategy-game interface for their four.

Separating those two axes is what makes the interesting cases fall out for free
rather than being built. The commander who owns the tavern and moves the coffee
cups is not a feature -- it is a region-membership scope over a region that happens
to contain crockery, driven the ordinary way, moving things that are the ordinary
[thing record](005-a-thing-in-the-world.md).

## The scope record

| Field | Type | Meaning |
| --- | --- | --- |
| `viewer` | `uint32_t` | Which connected participant holds this scope. `0` means it is unheld -- a defined and normal state, because the forest exists whether or not somebody is playing it today. |
| `membership` | `uint8_t` | `LIST` or `REGION`. Which of the two rules decides what is in it. |
| `region` | `uint32_t` | If `REGION`: the region index. Nested children are included via the region's parent chain. |
| `first_member` | `uint32_t` | If `LIST`: where this scope's slice of the shared membership pool starts. |
| `member_count` | `uint32_t` | If `LIST`: how long that slice is. |
| `style` | `uint8_t` | `DRIVEN` or `ORDERED`. A hint to the view about which interface to present, and to the command validator about which verbs to accept. |
| `flags` | `uint16_t` | The bits below. |
| `name_offset` | `uint32_t` | Offset into the string pool. "The Tavern", "The Forest", "Aelfwine". Shown to people; never used to decide anything. |

### The flag bits

| Bit | Name | Meaning when set |
| --- | --- | --- |
| 0 | `SEES_ALL` | This scope's sight is not computed; it sees the world. What a GM has. |
| 1 | `SEES_REGION` | This scope sees its whole region rather than only from its bodies' eyes. What the tavern's commander plausibly wants: they are the tavern, and the tavern knows where its own crockery is. |
| 2 | `MAY_EDIT_WORLD` | May move walls, place things, change regions. Distinct from commanding bodies, because "can move a goblin" and "can knock down a wall" are different powers and one table may want to hand out one without the other. |
| 3 | `MAY_SEE_HIDDEN` | Sees things flagged `HIDDEN` inside its membership. |

**A viewer may hold several scopes.** Being a player with a character and also
the commander of the forest is two scopes held by one connection, and neither
knows about the other. **A scope is held by at most one viewer**, which is what
makes "who moved that" answerable.

Multiple GMs are therefore not a special case either: two connections, each
holding a scope with `SEES_ALL` and `MAY_EDIT_WORLD` set. They do not share a
scope; they have one each.

## Permission is looked up, never claimed

A client cannot ask to be a GM. When a participant comes through
[the door](003-the-door-and-the-private-port.md), the server consults its own
configuration to find which scopes that participant holds, and then *informs*
them. The join request has no field for it, deliberately -- see the field table in
that document.

Every command carries a scope index, and the intake pass checks two things before
anything else happens: that the scope is held by the viewer the bytes arrived
from, and that the thing being commanded is a member of it. Both failures are
refused in words. See
[commands enter through one door](010-commands-enter-through-one-door.md).

## What this costs when the scope is large

A scope's sight is the union of what its bodies see. A commander with six goblins
runs the angular sweep six times per tick. A region commander over a busy tavern
could be running it thirty times, and a GM without `SEES_ALL` would run it for
every creature on the map, which is why `SEES_ALL` exists as a flag rather than
as an amount of patience.

`SEES_REGION` is the same kind of shortcut for the middle of the dial: computing
one region's interior once beats computing thirty overlapping wedges and unioning
them. Whether it is the *right* answer for a tavern's commander, or whether they
should genuinely be blind to the corner their crockery cannot see, is a design
question rather than a performance one, and it is not settled.

## The questions this raises

Three of them, and none is answered here:

**When a goblin patrol walks out of the forest and into the tavern, whose is it?**
Region membership is evaluated from the thing's current region, so mechanically
the answer is "the tavern's commander, the moment it crosses". Whether that is
what anybody wants is a different matter -- the forest's commander may have been
walking that patrol for ten minutes with an intention.

**Is "usually weaker but not always" a rule or a convention?** Whether the program
should enforce anything about the strength of a commander's bodies, or whether
that is entirely the GM's business when handing out scopes.

**Can a scope be handed over mid-session, and what happens to orders in flight?**

All three are in [open questions](016-open-questions.md), to be worked through one
at a time.

## Read next

- [What a viewer is allowed to know](009-what-a-viewer-is-allowed-to-know.md).
- [Commands enter through one door](010-commands-enter-through-one-door.md).


## Owning a piece is not a fence around it

The question this document could not answer for six phases: a commander owns the
forest and its goblin patrols, another owns the tavern, and a patrol walks out of
the forest and through the tavern door. **Whose is it?**

It is the forest's. It obeys the forest's commands. And the tavern's owner can
spring a trapdoor under it, poison its drink, refuse it mead, or put a bounty on
its head.

> Player ownership refers to the ability to move the pieces on the board and
> wield them to do things. It does not determine who is able to affect other
> things — you can absolutely kill the goblins, tavern-owner. **But you better
> explain how.**

### Two questions that had one gate between them

| Question | The gate | The answer |
| --- | --- | --- |
| May I **move** this? | membership | Only if it is in a scope you hold. |
| May I **act on** this? | sight, then the ruleset | If you were told it is there, you may try. The ruleset says what happens. |

The first is every verb this project had. The second is one verb, `interact`,
carrying an intent number the **ruleset** catalogues — because the server has no
opinion about what acting on something means and therefore nothing with which to
tell one kind from another.

A ruleset that wants twelve kinds gives them twelve numbers. A ruleset with no
`on_interact` hook means a table where you cannot poison a drink, and that is
correct rather than a gap: a server that allowed something it could not describe
would be having an opinion by the back door.

### The gate is what you were told, and that is not a shortcut

It would have been easy to work visibility out again inside the command path.
That would be a **second answer** to *can this person see that*, and two answers
to a permission question is how a model develops a hole nobody can find.

So the outbound filter — the one function allowed to put a thing on a socket —
records what it sent, and the gate reads that record. It is the same decision,
remembered. And it is free, because the answer was already computed this beat in
order to decide what to send.

Stated as the thing it actually is: **you may act on what you were told about.**
Which is a stronger and simpler sentence than any description of sight cones and
walls.

The record is cleared at the top of every update, for the same reason the buffer
is: an update is the whole picture. A body that walks out of sight stops being
actionable on the beat it leaves, rather than staying actionable because it was
visible once.

See issue [1201](../issues/completed/1201-commanding-is-not-affecting.md).
