# 030-map-builder

Builds the path graph. Nothing walks anywhere until this has run.

## What it is for

There is no map editor and no hand-editable map file. A map that has been
hand-tweaked cannot be regenerated, and a map that cannot be regenerated is a map
nobody dares change. So this takes the shape parameters and emits the ground.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `build(parameters)` | the parameter record | The map record, below. |
| `dump(map)` | a map | The graph as a printable coordinate list. |

It also exports named constants for node kinds (`NODE_PLAIN`, `NODE_JUNCTION`,
`NODE_TOWER`, `NODE_SPAWN`, `NODE_LIBRARY`) and structure kinds
(`STRUCTURE_LANE_TOWER`, `STRUCTURE_BASE_TOWER`, `STRUCTURE_LIBRARY`), so that no
other file writes the bare integer.

## The map record

| Field | Type | Meaning |
| --- | --- | --- |
| `node` | array of node structs | The ground. Ids are indices. |
| `lane` | array of lane structs | Three of them. |
| `site` | array of structure sites | Where stone stands. The world turns these into structures. |
| `library_node` | integer[2] | Each team's library node id. |
| `bounds` | table | `min_x`, `min_y`, `max_x`, `max_y` — what the camera frames at rest. |

### node

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | integer | Its own index. |
| `x`, `y` | double | Position in paces. Used for drawing and weapon range only. |
| `kind` | integer | 1 plain, 2 junction, 3 tower site, 4 base spawn, 5 library site. |
| `lane` | integer | 1–3, or **0** for a connector. |
| `milestone` | integer | 0–8 if this node is a milestone, **0** otherwise. Read together with `kind`, never alone. |
| `team` | integer | 0 neutral, 1, or 2 — which half of the field it sits in. |
| `neighbour` | integer[] | Node ids reachable in one step. |
| `structure` | integer | Id of the tower or library here, or **0**. |

**No field is ever nil.** A node with no structure holds the integer zero. Whether
the builder got that right is [the validator's](031-map-validator.info.md)
question, asked once at load, not the movement loop's asked a thousand times a
tick.

### lane

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | integer | 1 top, 2 centre, 3 bottom. |
| `path` | integer[] | Node ids in order, **team 1's library to team 2's**. |
| `path_index` | table | Node id → its position in `path`. |
| `milestone_node` | integer[0..8] | Node id for each milestone. |
| `milestone_index` | integer[0..8] | Position in `path` for each milestone. |
| `step_length` | double[] | Distance from `path[i]` to `path[i+1]`. |
| `junction` | integer[] | Exactly one: the milestone-4 node. |
| `length` | double | Total path length. |
| `width` | double | Paces across. |

### site

`team`, `kind`, `lane`, `milestone` (counted from the **owning** team's end, so
team 2's outer tower at lane milestone 5 records a 3), and `node`.

## The fact that makes the builder short

**Milestone 4 is exactly the bend.** The two libraries are mirror images about the
junction diagonal, so a side lane's two legs are the same length, so the bend falls
at exactly half the lane's length — which is where milestone 4 goes. Every pair of
consecutive milestones is therefore joined by a **straight line**, and placing nodes
between them is linear interpolation rather than walking a polyline by arc length.

## Three things a reader tends to ask

**Why do `step_length` and `path_index` exist?** So the move pass never computes a
square root and a body joining a lane never scans for its position. Both are
answers that cannot change, so the map works them out once.

**Why do milestones 0 and 8 store zero?** They are the two library nodes, shared by
all three lanes, so they cannot carry any one lane's milestone index. Read them
through `kind`.

**Why are `bounds` computed rather than written down?** So that changing the field
size reframes the camera with no second edit anywhere.
