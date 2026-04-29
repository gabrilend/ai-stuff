# tests/ — index

Each file in this directory is a standalone C program that exercises
exactly one piece of library functionality. The filename names the
behavior it tests, so a glance at the directory listing tells you
both what is tested AND (by absence) where the testing blind-spots
are.

Run the whole suite with `bash tests/run-all.sh`. Each test compiles
and runs independently; failures are reported with the test name.

## Conventions

- Filenames are `{INDEX}-{LIBRARY-OR-MODULE}-{BEHAVIOR}.c`.
- Each test creates its own pool / state and tears it down. Tests
  do not share fixtures or run order.
- A test exits 0 on pass, non-zero on fail. The runner script
  enforces a per-test timeout (default 10s) so a hung test is
  reported as a failure, not a hung suite.
- New tests added: also update this file and the "blind spots"
  section below.

## libs/900-task-pool — coverage

| Test file                                            | Behavior tested                                                                                          |
|------------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| `001-task-pool-sequential-actions.c`                 | A task with N actions runs them in order; `current_index` advances; `args` are routed to each action.    |
| `002-task-pool-cross-task-result-wait.c`             | Iter4 cross-task wait: action reads another task's result slot via `pool_result_slot`; BLOCKs while pending; advances once filled. |
| `003-task-pool-mid-task-block.c`                     | An action returning `ACT_BLOCK` suspends and resumes at the same `current_index`; iter4 demote-on-block raises priority on retry.  |
| `004-task-pool-self-rescheduling.c`                  | A task whose final action `pool_spawn`s a fresh copy of itself can iterate N times.                      |
| `005-task-pool-priority-cycler.c`                    | High-priority (1) tasks complete before, but do not starve, low-priority (10) tasks under the cycler.    |
| `006-task-pool-result-slots.c`                       | An action writes to its own `result_slots[k]`; later actions and external callers can read it back.      |
| `007-task-pool-block-promotes-blocker.c`             | Iter4 promote-on-block: when A blocks on B with `block_on=B_id`, B's priority is raised and A's lowered. |
| `008-task-pool-result-filled-vs-null.c`              | `result_filled[]` distinguishes "action k hasn't run" from "action k ran and chose to write NULL." All four `slot_status_t` values produced. |

## Known blind spots (no test coverage yet)

- `ACT_JUMP` semantics (jumping forward, jumping backward to form a
  loop, jumping past `n_actions` to terminate). Should add when
  any caller starts using JUMP for real control flow.
- `pool_ref` / `pool_unref` correctness — currently exercised
  incidentally by test 003, but no test specifically validates
  refcount accuracy or the "last drop frees" guarantee.
- `pool_destroy` with tasks still in queue (the documented "leaks
  on purpose" behavior). Should add a test that verifies destroy
  does not crash even with live tasks.
- Stress / many-task / many-worker scaling. The current tests are
  correctness-only; no perf or contention tests.
- Registry behavior past 4096 simultaneous live tasks (the
  asserted-on full case). Iter5 (issue 124) replaces this with
  a stable-index dense pointer array.
- Tight-loop spin under iter4 when a single waiter sits at
  priority 10 in an otherwise-idle pool. Tests 002/003 incidentally
  show this — block-action retry counts climb into the tens of
  thousands during a 50ms B-side sleep. Behavior is correct (the
  task does eventually advance), but the CPU burn is real. Known
  property; mitigation if it bites is a brief `nanosleep` on
  priority-10 BLOCK retries.
- Iter5's stable-index task storage (issue 124).
- Iter6 / issue 123 frame-based periodics.

When any of the above gets exercised by a real caller, add a test
file here and remove the entry from this list.
