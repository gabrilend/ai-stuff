# Datapath: a run, from input to goodbye

How one run of the program starts, keeps time, takes input and ends. Applies
to the window (`./run-game`) and to headless runs (`./run-headless`,
`./run-many-battles`) alike.

```
input/*.lua ──┐
              ├─► run options ──► seed ──► named streams (003)
command line ─┘        │
                       └──► script: events sorted by simulated time (019)

config.def (001) ──► + config.lua ──► configuration
assets/catalogue + mods ──► checked catalogue (004)

        ┌──────────── each frame (window) / as fast as possible (headless) ─┐
        │ real time → accumulator → for each tick that is due:               │
        │    script events due at this tick ──► the same input handlers     │
        │    held keys + pending clicks ──► intent (one record)             │
        │    match tick (017) ──► battle tick (014)                         │
        └────────────────────────────────────────────────────────────────────┘

quit (escape, window close, --quit) ──► wait for pending screenshots
        ──► receipt (018) ──► output/goodbye   ◄── the last act
run-game, after the window closes ──► scripts/file-screenshots
        ──► development-history/NNN-name.png + .info.md + .fingerprint
```

## The pieces

| Step | File | Carries |
| --- | --- | --- |
| run options | src/018-input-and-goodbye.lua | seed (integer), mode (string), region (string), first_person (boolean), script (list), perks (list of names), mods (list of names), report (boolean), receipt (path or false) |
| script | src/019-the-script.lua | events: { t (seconds, number), kind (string: key_down, key_up, mouse_down, mouse_up, mouse_move, screenshot, quit), and the kind's fields } |
| the clock | src/029-the-front-desk.lua | ticks of config.tick.seconds; at most config.tick.max_per_frame per frame, the rest dropped |
| intent | src/029-the-front-desk.lua | forward, side (numbers −1..1), guard (boolean), swing ("swing", "overhead" or false), u_delta (number), dodge (boolean) |
| receipt | src/018-input-and-goodbye.lua | `name: value` lines: ended, seed, mode, ticks, seconds, frames, rounds, result, every battle counter, draws per stream, screenshots |

## Why it is shaped so

- Scripted events are delivered on the tick their simulated moment arrives,
  through the handlers a person's input reaches, so a script means the same
  thing at any frame rate and with no window.
- The receipt is a reading of counters the battle keeps anyway; nothing is
  counted twice. A run that crashes writes none, so a stale receipt is the
  crash report.
- A batch (`./run-many-battles`) is one process per core, never a loop on
  one thread; its receipts are totalled by `scripts/total-receipts`.
