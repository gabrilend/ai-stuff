# 070-scope

Is this thing inside this scope? One question, asked constantly — every command
runs it, every outbound record runs it. It allocates nothing.

## The dial is two facts, not four roles

Reading the four positions — one body, a few bodies, a region, the map — looks
like four systems. It is:

**Membership is one of two rules.** A written list, or a region and everything
inside it. "One body" is a list of length one; "the map" is a region that is the
whole map. **There is no third rule.**

**Style is a separate axis.** Whether you push a body with keys or give it orders
is about input and has nothing to do with what you may touch. A GM can drive one
goblin; a player with a party of four gets the strategy interface.

The moment those two constrain each other, four positions collapse back into four
roles.

## The functions

| Function | Purpose |
| --- | --- |
| `scope_contains` | The membership question. |
| `scope_is_held_by` | **One integer comparison, and the load-bearing permission check in the project.** |
| `scope_of_viewer_containing` | Which of a viewer's scopes holds a thing, or 0. |
| `scope_style_allows` | Whether a verb suits a style. |
| `scope_size` | A list reads a field; a region walks the world, because its size is a question about now. |
| `scope_eyes_of_viewer` | Bodies with eyes, gathered. Returns the true count even when it exceeds capacity. |
| `viewer_has_flag` | Any scope of theirs with the flag. |
| `scope_unhold_all` | On departure. **The scopes remain** — an unheld scope is normal. |
| `scope_make_list` / `scope_make_region` | Building them, because members must be consecutive and getting that wrong is silent. |

## Eyes are gathered by walking things, not scopes

So a body in two of somebody's scopes is swept **once**. Sweeping is the
expensive pass, and doing it twice for the same eyes would be paying for nothing.

## The patrol crossing

Region membership is read from a thing's **current** region, so a patrol walking
from one commander's ground into another's changes hands on the beat it crosses.

That is what the mechanism does, and it is **not settled that anybody wants it** —
the first commander may have been walking that patrol for ten minutes with an
intention. Open question 6.1. A test pins the behaviour so that changing it later
is a deliberate act with a failing test attached, and the phase 6 demo shows the
moment it happens.

## An unheld scope is normal

`viewer` of 0. The forest exists whether or not anybody is playing it tonight.

## What this made true elsewhere

Gate 1 of the outbound filter stopped being a stub. It had returned "admits
nothing" — the direction that cannot leak — so the geometry decided everything.
Now it means **you always know about what you command**, which is why a commander
does not lose track of a goblin that walks behind a pillar.

That also answered open question 6.5 without anything being added: since gate 1
passes everything below it, a GM sees hidden things inside their own scope. Your
own ambush is not hidden from you.
