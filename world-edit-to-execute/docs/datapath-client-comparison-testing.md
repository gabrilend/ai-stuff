# Datapath: comparing the real WoW client with the open client

**Feature:** W04 (the comparison rig)
**Status:** Designed, not built. Update this file when W04 changes the flow.

---

## Idea in one paragraph

Set up one small situation on a throwaway AzerothCore server (a creature
standing, then walking, then casting, then dying). Show that situation in the
real WoW client and, at the same time, in our open client (our engine's W03
renderer, and later the custom-client project). Record both screens to video.
Line the two recordings up in time. Measure how different they are with plain
image statistics, and then ask a vision LLM to describe *what* differs
(pose, timing, colour, size, missing effect). The real client is the answer
key; the open client is the student.

## The whole path

```
 scenario file (Lua table)
      │
      ├──▶ [1 server populator] ──SOAP/console──▶ AzerothCore worldserver (test DB)
      │                                              │ spawns, moves, casts, kills
      │                                              ▼
      ├──▶ [2 real client runner] wine Wow.exe on a virtual display ─┐
      │                                                              │ ffmpeg x11grab
      │                                                              ▼
      │                                               frames A (PNG per frame, tmp/shared-memory)
      │
      └──▶ [3 open client runner] our engine replays the same scenario ─▶ frames B
                                                              │
                     [4 align] by start marker + server event timestamps
                                                              ▼
                     [5 measure] per frame pair: SSIM, silhouette overlap,
                                 colour histogram distance   (numbers, multi-threaded)
                                                              ▼
                     [6 judge] worst-scoring pairs → vision LLM → structured verdicts
                                                              ▼
                     [7 report] JSON (generator) ──▶ HTML side-by-side page (viewer)
```

## Stages

| # | Stage | Input (type) | Output (type) |
|---|-------|--------------|---------------|
| 1 | Populate | scenario: map id (uint32), camera pose (position 3×float, yaw/pitch float, distance float), actors (creature entry uint32 or display id uint32, position, facing), timeline (list of {time_ms uint32, actor, action string, args}) | GM commands sent to the worldserver; a log of server-side event times (ms) |
| 2 | Real client | launcher config, test account | frames A: folder of PNGs, fixed rate (e.g. 30 fps), plus the time of the start marker |
| 3 | Open client | the same scenario | frames B, same rate and resolution |
| 4 | Align | frames A, frames B, event log | list of (frame A index, frame B index) pairs |
| 5 | Measure | frame pairs | per pair: SSIM (float 0-1), silhouette intersection-over-union (float 0-1), histogram distance (float) |
| 6 | Judge | the K worst pairs (K small, e.g. 12) + the scenario text | per pair: aspect (`pose`/`timing`/`colour`/`scale`/`effect`/`missing`), verdict (`same`/`differs`), confidence (float), explanation (string) |
| 7 | Report | all of the above | `report.json`; `report.html` with frames side by side, a score-over-time chart, and the LLM notes |

## Why numbers first, LLM second

A vision LLM asked "are these two pictures the same?" gives different answers
on different runs and cannot notice a 3-frame timing shift across a whole
video. Image statistics are repeatable and cheap, so they decide pass/fail and
pick *which* frames are worth a closer look. The LLM is then used for what
statistics cannot do: say in words that "the open client's orc is holding the
axe in the wrong hand". A test fails on the numbers; the LLM's text explains
the failure.

## Machine requirements found on 2026-09-23

| Tool | Present | Needed for |
|------|---------|------------|
| wine | yes (`/usr/bin/wine`) | running Wow.exe |
| ffmpeg | yes (`/usr/bin/ffmpeg`) | recording |
| Xvfb (virtual X display) | **no** | running the client without taking over the desktop |
| xdotool (synthetic keyboard/mouse) | **no** | typing the login at the client's login screen, which addons cannot touch |
