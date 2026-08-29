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
| `access` | one of a few values | **almost always open** |
| `facts` | a small list | who owns the roof, what the ground floor trades in, whether the stair is shared |
| `houses` | list | the dwellings inside — see [407](407-a-house-has-no-geometry.md) |

### Access, and where the restriction actually sits

**It is rare for a building to be closed.** The largest are entirely free to
enter — public areas are for the public.

The restriction lives one level down. Houses are almost always restricted, because
someone lives there. A building is a shell you may walk into; a dwelling inside it
is not.

That asymmetry is worth holding onto, because the obvious design puts access on
the building and would make the whole city feel locked. Here the city is largely
open and the *homes* are private, which is both truer to a medieval city and more
interesting to move around in.

### The facts fill in forever

Ten thousand buildings, each with a few small facts, is another campaign. It runs
on the same terms as house events: **a building with nothing recorded is a
building nobody has looked into yet**, not an error and not a gap to be filled
before anything works.

See [806](806-houses-fill-in-forever.md), which sets the same expectation one
level down.

## Suggested implementation steps

1. Extend the building record with access, facts and houses.
2. Default access to open; make closed the exception that must be stated.
3. Allow facts to be absent everywhere, and never treat absence as an error.
4. Have [309](309-the-coverage-report.md) count buildings with no facts, as work
   remaining rather than as faults.
5. Test that a building with no facts and no houses still selects, still shows in
   the tome, and still hit-tests.

## Related documents and tools

- [The places of the city](../docs/003-the-places-of-the-city.md)
- [The vision](../notes/vision) — walls are heavy, and hard to move
