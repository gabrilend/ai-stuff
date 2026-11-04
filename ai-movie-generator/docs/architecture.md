# Architecture — the shape of the machine

The ai-movie-generator turns a sound (a game soundtrack, a song, a recorded
monologue, or plain noise) plus a few words of theme into a short film made of
generated pictures. It is a pipeline of small machines, each one writing a
plain file that the next one reads. Every file between stages is something a
person can open, read and edit by hand, so any stage can be re-run on its own
— which is what makes rapid iteration possible: change one shot's wording,
re-render one clip, re-assemble the reel, and nothing else is redone.

The project separates **making data** from **looking at data** (see
CLAUDE.md). Stages 1–6 below make files; the viewers (contact sheets, the
reel player, the HTML documentation, the room) only read them.

## The pipeline, told as a story

1. **The ear listens.** The input sound is decoded to raw samples with
   ffmpeg, and a Lua listener measures it: how loud it is moment by moment
   (the loudness envelope), where the sharp attacks are (onsets — drum hits,
   cuts), where the character of the sound changes for a long stretch
   (sections — verse, chorus, battle theme, silence). The result is the
   **beat sheet**: a list of times with a strength and a label on each.
   (datapath: listening)

2. **The writers' room writes.** Three roles, each a call to a local language
   model through ollama, each with its own instructions:
   - the **creator** reads the theme and the beat sheet's sections and plots
     the arc — a path through *semantic space*, one waypoint per section,
     each waypoint a short phrase (calm → unease → revelation → rest);
   - the **writer** turns each waypoint into a scene: who is there, what
     happens, what is said;
   - the **director** turns each scene into shots: what the camera sees,
     how it moves, how long it lasts, and which beat it cuts on.
   The result is the **shot list**, one text file per film.
   (datapath: writers' room)

3. **The painter paints keyframes.** For each shot, the shot's picture
   description is sent to ComfyUI (the stable-diffusion server at
   /mnt/kaun/stable-diffusion) as a workflow graph, and one or more still
   keyframes come back as PNG files. The same seed and the same character
   description give the same face, which is how a character stays
   recognisable from shot to shot. (datapath: the image call)

4. **The animator moves them.** A still becomes a 3–6 second clip by one of
   a small, closed set of **motions**: a slow push-in or pull-out, a pan, a
   drift (a chain of low-strength image-to-image repaints of the previous
   frame, so the picture breathes without jumping), or a dissolve between
   two keyframes. Shots that a diffusion model renders badly — visions,
   energy, abstract noise, title cards — are handed to the **gif generator**
   (/mnt/mtwo/programming/ai-stuff/gif-generator), whose particle-light
   pictures are deterministic and never flicker. (datapath: shot to clip)

5. **The editor cuts.** Clips are laid end to end on the beat sheet's cut
   points, the original sound is laid under them, and ffmpeg writes one
   video file: the **reel**. (datapath: reel assembly)

6. **The monologue booth** is a second road through stages 3–5 for speech:
   one person, held on screen for the whole of a spoken passage however long
   it runs, with cutaways to rendered pictures whenever the speaker describes
   something ("today I had the strangest sith vision" → the vision, then back
   to the face). (datapath: monologue)

7. **The room** (the far end of the roadmap) is a browser-based VR space
   whose walls play reels and which re-generates its contents on its own as
   new reels finish. It is a viewer: it reads the reels folder and makes
   nothing.

## The files that pass between stages

| file | written by | read by | where it lives |
|---|---|---|---|
| input sound | the person | the ear, the editor | `input/` |
| theme / guidance | the person | the writers' room | `input/` |
| beat sheet | the ear | writers' room, editor | `tmp/shared-memory/<run>/` then kept in `output/<run>/` |
| shot list | writers' room (or the person, by hand) | painter, animator, editor | same |
| keyframes (.png) | painter | animator, contact sheet | same |
| clips (.mp4 / .gif) | animator, gif generator | editor | same |
| reel (.mp4) | editor | the person, the room | `output/<run>/` |
| goodbye receipt | every program, last | tests, demos, agents | `output/goodbye` |

The formats are defined in `docs/shot-list-format.md` and
`docs/beat-sheet-format.md`.

## Why files and not a single program

A film made of fifty shots fails in fifty places. If the pipeline were one
long call, one bad shot would mean starting over. With a file between every
stage, a bad shot is one line in the shot list to rewrite and one clip to
re-render. The design target is: **the time from "that shot is wrong" to
"here is the new reel" is the time to render one clip.**

## Where the work runs

- **GPU** (one GTX 1080 Ti, 11 GB): ComfyUI's diffusion, and ollama's
  language model. They share the card, so they take turns — see
  `docs/hardware-and-models.md`.
- **CPU, many threads** (12 cores): audio measurement, ffmpeg encoding,
  the gif generator. Independent clips are encoded in parallel through a
  thread pool (effil, at /home/ritz/programming/ai-stuff/libs/lua/effil).
- **RAM**: every intermediate file lives under `tmp/` until a run is kept.

## Language

LuaJIT throughout. Lua talks to ComfyUI and ollama over HTTP (luasocket, or
curl when luasocket is not available) and decodes JSON with dkjson; both are
in /home/ritz/programming/ai-stuff/libs/lua/.
