# 609 — Inter-app link declarations

## Current behavior

The inter-app linkage system the apps overview and input model
docs describe says each app exposes named exits with target apps
and value types. No code yet captures those declarations or
makes them addressable from the system's perspective.

## Intended behavior

Each app's map directory contains a `links.json` file at its
root. The file declares the app's outgoing exits:

```json
{
  "exits": [
    { "name": "to messenger",
      "target": "messenger",
      "value_type": "text" },
    { "name": "to files",
      "target": "files",
      "value_type": "text" }
  ]
}
```

At map load time (303), the loader reads `links.json` alongside
the other map files and populates a per-app `exit_table_t`:

```c
typedef struct {
    const char *name;        // human label
    const char *target_app;  // which app to switch to
    int         value_type;  // tag from a small enum
    int         entry_box;   // which input box on the target
                             // receives the value
} app_exit_t;
```

The `entry_box` field is resolved at the time the link is
followed (610), not at declaration — the target app may not
even be loaded yet when the source app declares the exit.

Drawer-content sub-maps (608) read the exit table to render the
list of available links. A radial-menu chord on a link entry
emits a `follow-link` event carrying the exit definition; the
link transition (610) consumes it.

A reverse mapping exists too: every app declares which entry
boxes accept inter-app deliveries. An app receives a link by
naming an entry box that the runtime delivers the value to. The
convention: an app's `/apps/<name>/entries.json` lists the
named entry boxes the app exposes for inbound links.

## Suggested implementation steps

1. `links.json` and `entries.json` format documentation in
   `notes/inter-app/000-format.md`.
2. Loader extension in 303 to read these files into per-app
   `exit_table` and `entry_table`.
3. Drawer-content integration: the drawer's option list reads
   the exit table.
4. A default empty exit table for apps that don't declare one.

## Related documents

- `docs/004-input-model.md` — inter-app linkage section.
- `docs/008-apps-overview.md`.

## Blocked by

303, 608.

## Blocks

610.
