# 303 — Map loader

## Current behavior

The map representation (301) exists and the source format (302)
is pinned, but nothing yet turns a directory of JSON files into a
`map_t`. The runtime can't load a map.

## Intended behavior

`map_load(const char *source)` reads the source format from 302
and returns a fully populated `map_t` ready to run. The source
argument is a string the loader interprets as a path into a
statically-compiled-in source bundle (phase 3) or a path on the
SD card (phase 4, once the filesystem ships).

The loader does its work in passes:

1. Parse `meta.json` for name, entry-box-id list, src_dirs.
2. Walk `boxes/` and parse each box JSON. For each, look up the
   box descriptor by `ref` in 208's table. Refuse unknown refs.
3. Allocate a `box_instance_t` per parsed box. Each instance
   owns slot indices into the map's slot store, sized by the
   descriptor's input port count.
4. Hand off to 304 (wire connector) to populate
   `connections[]` linkages between box instances.
5. Hand off to 305 (encapsulation splicer) to flatten any
   `kind: "map"` boxes the parse turned up.
6. Hand off to 306 (cycle detector) to verify the flattened
   graph is a DAG of sub-pieces (cycles allowed only across
   long-running re-arming patterns; the detector knows which).
7. Identify the entry boxes by id list from `meta.json` and
   record them on the map_t.

If any step fails, the loader frees every allocation it made and
returns an error. Partial maps never enter circulation.

A minimal JSON parser ships alongside the loader. The parser
handles the subset of JSON that map files use — objects, arrays,
strings, numbers, booleans, null. No streaming, no full RFC 7159
edge cases, no Unicode escape decoding past ASCII.

## Suggested implementation steps

1. `json_parse()` — small recursive-descent over the subset.
2. `parse_meta()`, `parse_box()`.
3. `map_load()` — the pass orchestrator.
4. `map_unload()` — symmetric free.

## Related documents

- `docs/012-soramech-runtime.md`.

## Blocked by

108, 208, 301, 302.

## Blocks

304 (loader calls it), 305 (loader calls it), 306 (loader
calls it), 308, 311.
