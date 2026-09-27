# Datapath: from a map file to a running program, and back

The route a program's description takes from text to stations and
wires (issues 305, 306, 307, 309), and back to text. Every step names the
file that does it.

## From box source to catalogue (build time)

```
  src/boxes/*.c ──→ generator (060, run by twin/tools/061) ──→ tmp/build/generated/
                                                                  catalogue.c   adapters, records, field tables,
                                                                                address → record rows
                                                                  catalogue-boxes.h
                                                                  maps.c        src/maps/*.map as strings
```

A failing run writes nothing; the previous catalogue stays (304).

## From text to program (load time)

```
  text ──→ 066 map_read        one logical line at a time, first word picks the reader;
       │                        problems collected, nothing built
       ▼
       description (stations, port lines, shortcuts, includes)
       │
       ▼
  068 plan_map                 look each box up in 070's catalogue by address;
       │                        read and plan every map placed inside (recursively);
       │                        check numbers, sources, values (067), both ends, widths
       │
       ├── any problems ──→ one report, sorted by line; nothing placed
       │
       ▼  none
  068 build, four sweeps over the whole tree:
       1 place    engine_place for every station (names prefixed inside placed programs)
       2 wire     engine_wire, one whole exit at a time, doors followed to inner ports
       3 sources  ring / none / depth, and door marks
       4 values   engine_configure static — this is what starts the program
       │
       ▼
  program record (068): stations, names, addresses, doors, children
```

## Afterwards

| call | what it does |
|---|---|
| `program_bring_up` | door numbering checked; any station not yet looked at is looked at once |
| `program_argument` / `program_result` | the outside's two doors |
| `program_unfinished` | the asked-for list of what cannot run yet |
| `program_write` (069) | the running program as text that reads back into the same program |
| `program_remove` | every station of it and its children, out of existence |
