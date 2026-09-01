# 406 — A Building, and Its Facts

| | |
| --- | --- |
| Phase | 4 — The Places |
| Blocked by | 307, 401 |
| Blocks | 407, 607 |
| Reads | [the places of the city](../docs/003-the-places-of-the-city.md) |
| Open questions | — |

## Current behavior

Buildings exist as rough zones with a name. They carry nothing else.

## Intended behavior

A building is one freestanding stone structure, and it is **what roots people**.

> The building is stone, and can't adjust easily, meaning it's what roots people.

That sentence is the design rather than a description. People move; stone does
not; and everything rigid about life in this city grows in the gap between those
two facts. It rhymes with the vision's own line — *walls are heavy, and hard to
move when the city expands* — so the same physical truth governs how the city
grows and why a person's life does not.

### The record

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | what it is called |
| `block` | integer | which block it stands in |
| `zone` | a few points | the rough shape from [307](307-placing-a-buildings-rough-zone.md) |
| `access` | one of a few values | **almost always unrestricted** |
| `facts` | a small list | who owns the roof, what the ground floor trades in, whether the stair is shared |
| `houses` | list | the dwellings inside — see [407](407-a-house-has-no-geometry.md) |

### Access, and where the restriction actually sits

**It is rare for a building to be barred.** The largest are entirely free to
enter — public areas are for the public.

The word here is deliberately not *open*. In [the scaffold](../docs/009-the-scaffold.md)
open means open to *being changed*, which is a different property: a building can
admit anyone and take on nothing.

The restriction lives one level down. Houses are almost always restricted, because
someone lives there. A building is a shell you may walk into; a dwelling inside it
is not.

That asymmetry is worth holding onto, because the obvious design puts access on
the building and would make the whole city feel locked. Here the city is largely
unrestricted and the *homes* are private, which is both truer to a medieval city
and more interesting to move around in.

### The facts are not written, they accumulate

Ten thousand buildings, each with a few small facts, was once planned as another
writing campaign. It is not one. A building accumulates its facts by being stood
in — see [the scaffold](../docs/009-the-scaffold.md) — and **a building with
nothing recorded is one where nothing has yet happened often enough to name**, not
an error and not a gap to be filled before anything works.

Most buildings are closed all the time, in the scaffold's sense of closed, so most
of them hold their natural character and accumulate nothing. That is expected: a
building that has taken on a character is a building something happened in.

## Suggested implementation steps

1. Extend the building record with access, facts and houses.
2. Default access to unrestricted; make barred the exception that must be stated.
3. Allow facts to be absent everywhere, and never treat absence as an error.
4. Have [309](309-the-coverage-report.md) count buildings with no facts, as work
   remaining rather than as faults.
5. Test that a building with no facts and no houses still selects, still shows in
   the tome, and still hit-tests.

## Related documents and tools

- [The places of the city](../docs/003-the-places-of-the-city.md)
- [The vision](../notes/vision) — walls are heavy, and hard to move
