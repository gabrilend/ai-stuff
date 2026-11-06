# 104 — Input Can Be Scripted On A Timeline

| | |
| --- | --- |
| Phase | 1 — The spine |
| Blocked by | 103 |
| Blocks | 105, 106, 407, phase demos |
| Files | `src/019-the-script.lua` |

## Current behavior

Built in `src/019-the-script.lua` as a table of options, each with its
argument count. Beyond the planned options it gained `--right-hold SECONDS
LENGTH` (the guard and the shield wall are held buttons), `--perk NAME` and
`--mod NAME` (for lone battles in the demos), `--report` and `--receipt`.
Events at one moment keep the order given. The front desk delivers due
events to the same handlers as a person's input. Tested in
tests/031-the-spine.lua.

## Intended behavior

Run options script the player's input on the simulation's clock:

| Option | Meaning |
| --- | --- |
| `--seed N` | the run's seed |
| `--key SECONDS NAME` | press key NAME at that moment |
| `--release SECONDS NAME` | release key NAME |
| `--hold SECONDS NAME DURATION` | press, then release DURATION later |
| `--click SECONDS X Y [BUTTON]` | mouse press and release at a screen point |
| `--mouse SECONDS DX DY` | relative mouse motion |
| `--screenshot SECONDS NAME` | capture the screen to tmp/shared-memory/screenshots/ |
| `--quit SECONDS` | end the run cleanly (writes the receipt) |
| `--first-person` | begin the battle in the front rank |
| `--mode NAME` | match, battle or duel |

The script is a list of events sorted by time. Each tick, every event whose
time has been reached is handed to **the same handler a real key, click or
mouse motion goes to** (the front desk's input dispatch), so a scripted run
exercises exactly the code a person's run does. Scripted time is simulated
time, so a script means the same thing at any frame rate and headless.

## Suggested implementation steps

1. Parse the arguments into option and event lists; an unknown option or a
   missing argument stops the run naming it.
2. Keep a cursor into the sorted events; `due(now)` returns the events whose
   time has come.
3. Test: parsing each option; events come out in time order; two events at one
   moment both fire.
