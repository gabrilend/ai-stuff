# frame-hand.c

The fabricated frame, by hand, running the same boxes.

- **Usage:** `./frame-hand serial|systems|levels|systems-spin|levels-spin
  FRAMES THREADS BACKGROUND`.
- **The ways:**
  - `systems`: one self-balancing parallel loop per stage, a barrier after
    each;
  - `levels`: one loop per dependency level;
  - `-spin`: the barriers spin instead of sleeping.
- **Background decodes** go to a dedicated thread with a mutex-guarded
  queue.
- **Output:** the same columns as `frame-host.c`. The regions marked
  THREADING are what `run-frame.sh` counts.
