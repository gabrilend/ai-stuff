# frame-hand.c

The fabricated frame, by hand, running the same boxes as the map.

- **Usage:** `./frame-hand serial | systems | levels | systems-spin |
  levels-spin | systems-hybrid | levels-hybrid | jobs  FRAMES THREADS
  BACKGROUND`.
- **The barrier ways:**
  - `systems`: one self-balancing parallel loop per stage, with a barrier
    after each;
  - `levels`: one loop per dependency level;
  - `-spin`: the barriers spin;
  - `-hybrid`: they spin for `SPIN_US`, then sleep.
- **`jobs`:** a job system (issue 515j).
  - Jobs carry dependency counts; finishing one releases its dependents
    onto the thread's own queue.
  - Queues are per thread, spin-locked; the owner pops the newest, thieves
    take the oldest.
  - Idle helpers spin for `SPIN_US`, then sleep; the main thread works and
    never sleeps.
  - The frame ends when nothing is outstanding.
- **Settings:** `FRAME_SPIN_US` overrides the spin (default 50);
  `run-frame.sh` picks each way's best by trial.
- **Background decodes** go to a dedicated thread.
- **Output:** the same columns as `frame-host.c`. The regions marked
  THREADING are what gets counted.
