# Roadmap

Phases are clusters of functionality, numbered by what builds on what — not
a calendar. The aim from phase 1 onward is **rapid iteration**: from the end
of phase 2, a person can hand-write a shot list and get a reel, and every
later phase only automates a step a person could already do by hand.

## Phase 1 — the image call and the run

The foundation every other phase stands on: talking to ComfyUI, and the
shape of a run.

- the project's run script: ${DIR}, RAM tiers, reads `input/` first, writes
  the goodbye receipt to `output/` last;
- the ComfyUI client: start-check, upload, queue, wait, fetch;
- workflow templates with placeholders (text-to-image, image-to-image,
  text-to-image with control), chosen by a dispatch table;
- the picture request and the render log;
- the contact sheet viewer (reads PNGs, writes one tiled PNG).

**Ends with:** the phase-1 demo renders a dozen station stills from a list,
shows them as a contact sheet, and prints seconds-per-picture and
pictures-per-minute read from the render log.

## Phase 2 — shots into motion

- the shot-list sandbox (film, cast, place, shot);
- prompt assembly from cast and place;
- the camera motions (still, push in, pull out, pan) by ffmpeg;
- drift (chained image-to-image) and dissolve;
- the gif-generator bridge for the shots diffusion renders poorly;
- reel assembly with sound, and the one-shot re-render loop.

**Ends with:** a hand-written 30-second station film, rendered, then one shot
rewritten and re-rendered alone; the demo shows both reels and the time each
iteration took.

## Phase 3 — the ear

- decoding and the threaded loudness envelope;
- onsets, sections, tempo;
- the beat sheet and its viewer;
- snapping shot cuts to onsets.

**Ends with:** a game soundtrack in, its beat sheet drawn as a picture, and
the phase-2 film re-cut to it.

## Phase 4 — the writers' room

- the ollama client and the GPU handoff;
- role instruction files;
- the creator's arc, measured in semantic space with embeddings;
- the writer and the director;
- the checker loop that sends errors back to the role that made them.

**Ends with:** a brief and a sound file in, a reel out, with no hand-written
shot list. The demo shows the arc's step sizes beside the music's energy.

## Phase 5 — the monologue booth

- the speech source (recording or synthesised voice);
- the held portrait with voice-driven life;
- automatically found cutaways;
- mouth shapes switched by loudness.

**Ends with:** "death star personnel daily report log MNL" — a staff member's
report and the therapist's reply.

## Phase 6 — the room

- the generator loop that keeps making films unattended;
- the room server and the WebXR corridor of screens;
- live appearance of new reels;
- several visitors sharing the room.

**Ends with:** the room open in a browser, a new reel appearing on a wall
while it is watched.
