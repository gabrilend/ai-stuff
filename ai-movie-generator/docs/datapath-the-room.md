# Datapath — the room (reels into a shared space)

The vision ends with "make it into a VR chat room, one that's dynamically
updating automatically". This is the far end of the roadmap and is
deliberately only a viewer.

## In

The `output/` folder: every kept run's `reel.mp4`, `contact-sheet.png`
and `arc.lua`.

## Through

1. A small HTTP server (Lua, luasocket) serves a WebXR page built with a
   browser 3D library, plus the reels.
2. The page is a corridor — the station — with screens on the walls. Each
   screen plays one reel. Walking the corridor is browsing the films.
3. The page asks the server for the list of reels every few seconds; a new
   reel appears as a new screen. That is the "dynamically updating".
4. A **generator loop**, separate from the room, keeps making films: it
   picks a sound from a pool, writes a brief from a list of themes, runs the
   pipeline, and keeps the run. The room never calls the generator; it only
   notices new files.
5. Several visitors in the same room (the "chat" part) share position and
   text through the same server.

## Out

A page that opens in a VR headset's browser or a desktop browser.
