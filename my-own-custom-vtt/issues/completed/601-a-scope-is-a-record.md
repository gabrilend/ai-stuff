# 601 -- A scope is a record

**Phase:** 6, control is a dial
**Blocked by:** phase 5 complete.
**Blocks:** everything else in phase 6.
**Documents:** [who controls what](../../docs/008-who-controls-what.md)

## Current behaviour

A viewer has one body, assigned by the server on joining. The outbound filter's
scope gate returns "admits nothing" because there are no scopes.

## Intended behaviour

The dial, as a record.

| Field | Type | Meaning |
| --- | --- | --- |
| `viewer` | `uint32_t` | Who holds it. `0` means unheld — a defined and normal state, because the forest exists whether or not somebody is playing it today. |
| `membership` | `uint8_t` | `LIST` or `REGION`. Which of two rules decides what is in it. |
| `region` | `uint32_t` | If `REGION`. Nested children included via the parent chain. |
| `first_member`, `member_count` | `uint32_t` | If `LIST`. A slice of a shared pool. |
| `style` | `uint8_t` | `DRIVEN` or `ORDERED`. |
| `flags` | `uint16_t` | Below. |
| `name_offset` | `uint32_t` | Shown to people; never used to decide anything. |

Flags: `SEES_ALL`, `SEES_REGION`, `MAY_EDIT_WORLD`, `MAY_SEE_HIDDEN`.

### Two facts, not four roles

Reading the dial's four positions — one body, a few bodies, a region, the map —
looks like four systems. It is two facts:

**Membership is one of two rules.** A written list, or a region and everything
inside it. "One body" is a list of length one. "The map" is a region that is the
whole map. There is no third rule.

**Driving style is a separate axis.** Whether you push a body with keys or issue
it orders is about input and about how many bodies there are. It has nothing to
do with what you are permitted to touch.

Separating those two is what makes the interesting cases fall out rather than be
built. **The commander who owns the tavern and moves the coffee cups is not a
feature** — it is a region-membership scope over a region that happens to contain
crockery, driven the ordinary way, moving the ordinary thing record.

### Scopes are world state

A scope is snapshotted and rolled back with everything else, because who commands
what is part of what a turn changed. The `viewer` field refers to a viewer index,
which is why those indices are stable even though the sockets beside them are not.

## Suggested implementation steps

1. Add the scopes block and the membership pool to the world.
2. Extend the validator: a `LIST` scope's slice inside the pool; a `REGION`
   scope's region real; a `viewer` that is 0 or a plausible index.
3. Extend the world file and the hash — a scope changing hands changes the world.
4. Write the companion `.info.md`.
5. Test that a scope survives a snapshot and a rollback.
