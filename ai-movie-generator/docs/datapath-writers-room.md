# Datapath — the writers' room (theme and beats to shot list)

## In

- the **brief**: a text file in `input/` — the theme and any guidance, in the
  person's own words ("death star personnel daily report log MNL", "the
  soundtrack of a fantasy game; render the game");
- the beat sheet (sections and their energy labels).

## Through

Three roles, called in order, each one a request to ollama with its own
standing instructions (kept in `assets/roles/<role>.md` so they can be
edited without touching code) and the previous role's output.

1. **Creator — the arc.** Reads the brief and the list of sections. Writes
   one waypoint per section: a short phrase naming the feeling or idea of
   that stretch. The waypoints are then embedded (nomic-embed-text) into
   vectors, and the distance between neighbours is measured. Neighbours that
   are nearly identical mean the arc is standing still; a jump far larger
   than the music's energy change means the arc is lurching. The creator is
   asked to revise until the step sizes follow the music's energy changes.
   This is the "navigating through semantic space" of the vision: the arc is
   a path, and its steps are measured, not just written.
2. **Writer — the scenes.** For each waypoint: a scene with who is present,
   where, what happens, and any spoken lines. Recurring people and places
   are declared once as `cast{}` and `place{}`.
3. **Director — the shots.** For each scene: shots of 3–6 seconds, each with
   `sees`, `motion`, and timing laid onto the section's span and snapped to
   onsets. The director marks shots that diffusion will render badly
   (visions, energy, pure abstraction) as `by = "gif"` and writes a short
   description for the gif score. Spoken lines become `monologue{}` entries.

Each role's answer is checked before the next role sees it: the director's
output must load in the shot-list sandbox and every shot's timing must fit
the film's length. A failed check is sent back to the same role with the
checker's message (like a compiler error), a fixed number of times; then
the run stops with that message.

When the room is done, ollama is told to unload its model so ComfyUI has the
graphics card (hardware-and-models.md).

## Out

`arc.lua` (waypoints and their measured step sizes), `scenes.md` (the
writer's prose — kept because it is the most readable account of the film),
and `shot-list.lua`.

## Hand-writing instead

Every output here is a plain file. A person can write `shot-list.lua`
directly and skip the room; that is the fastest iteration loop and is what
phase 1 and 2 use before the room exists.
