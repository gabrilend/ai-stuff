# 507 — Settings application

## Current behavior

The handedness and drawer-swap settings live in `/settings/`
files (408) but no input-stream code reads them. Every event
fires under the device's default handedness regardless of what
the user set, and the four center buttons always map to the same
drawer regardless of the swap flag.

## Intended behavior

A small `settings-applier` box reads the two relevant settings at
boot and re-reads them whenever the settings file changes. It
applies them to the event stream:

- **Handedness.** A boolean: left-handed or right-handed. The
  applier rewrites the *semantic role* of button events: in
  right-handed mode the D-pad is "navigation" and ABXY is
  "action"; in left-handed mode they swap roles. Physical button
  identity is unchanged; only the semantic-role tag the event
  carries changes. Apps subscribe to either the physical-tag
  events (the raw stream) or the semantic-tag events (the
  applier's output) depending on what they need.
- **Drawer-swap.** A boolean: standard or swapped. The applier
  rewrites the *target screen* on the four center-button events.
  Under the standard mapping (`start1`→bottom-left,
  `select1`→bottom-right, `select2`→top-left,
  `start2`→top-right), the rewriter passes through. Under the
  swap, `start1`+`select1` events get retagged with the top
  screen and `start2`+`select2` events get retagged with the
  bottom.

The applier subscribes to a `settings-change` event box that
fires whenever a relevant setting file is written. On change,
the applier re-reads from disk through `read-path` (406) and
updates its in-memory state with release ordering so any worker
reading the state sees a consistent before-or-after, never a
torn half-read.

The applier sits in the input-poll map (501) between the raw
event boxes from 502–504 and the consumer maps in phase 6
onward.

## Suggested implementation steps

1. `settings_applier_box()` — the rewriter.
2. `settings_change_event` — wires up to a watch on
   `/settings/` writes from 408.
3. Wire the applier into the input-poll map (501).
4. Document the physical-tag versus semantic-tag distinction in
   `docs/004-input-model.md` if it isn't already explicit.

## Decisions (2026-11-05)

Each one is a choice Ritz can overturn. Where the owner's own words
answer a question, they win over this issue's wording.

1. **The meaning rides beside the raw event, which is kept whole.** A
   `struct role_event` is the button event's frame, buttons and
   durations, plus four masks (navigate, act, modify-navigate,
   modify-act), each the part of `buttons` that has that role now, and
   the drawers the event's center buttons open. One event a frame, as
   502's are. An app wanting physical buttons hangs off `button_down` /
   `button_up`; one wanting meaning hangs off `roles_down` / `roles_up`.
2. **The sides are docs/004's.** Right-handed (the default): the D-pad
   and left stick navigate, L1 and L2 modify that, A B X Y and the right
   stick act, R1 and R2 modify that. Left-handed swaps every one. A
   stick's click goes with its stick, and the second triggers with the
   first, since docs/004 names "L triggers" and "R triggers" both.
3. **The center buttons have no side and no role.** They carry drawers
   instead, a bit each. Standard, as docs/004's table: start1
   bottom-left, select1 bottom-right, select2 top-left, start2
   top-right. Swapped, docs/004's words: "start1/select1 open the top
   screen's drawers and start2/select2 open the bottom screen's. Within
   each pair, the left button always opens the left drawer." So start1
   top-left, select1 top-right, select2 bottom-left, start2
   bottom-right. An up event names the drawer too; whether an app
   opens on down or closes on up is phase 6's.
4. **The sticks get roles as well.** `stick_roles` turns 503's
   left/right change into navigate/act: the left stick navigates
   right-handed, the right stick left-handed. Its changed bits follow
   the roles (bit 0 the navigating stick, bit 1 the acting one).
5. **Held events have no applier yet.** Nothing listens to them (502
   says why), so there is nothing to give meaning to. Adding one is one
   station off `button_held.2`.
6. **The settings are a dial on each applier, turned by a call.** The
   issue asked for a `settings-change` event box that re-reads
   `/settings/` through `read-path` (406) on every write. 406 (PR #35)
   and 408 (PR #48) are on stacks of their own, and a box cannot
   remember (docs/003), so the state has to be a port anyway. The
   applier's port 1 is a static port: a dial written under a sequence
   count (`034-ports.c`), so a box reading it sees the settings wholly
   before or wholly after a change, which is the issue's "consistent
   before-or-after, never a torn half-read". `input_settings_set`
   (`src/system/135-input-settings.h`) turns all three appliers. When
   this stack and 408's meet, 408's writer of `/settings/handedness` and
   `/settings/drawer-swap` calls it after each write, and whatever
   starts input-poll calls it once with the values read at boot. Until
   then the map's own settings stand: right-handed and standard,
   docs/004's default.
7. **The applier holds each setting as 0 or 1.** On disk they are `r` /
   `l` and `0` / `1` (docs/011); the caller converts. The call turns
   away anything else (`INPUT_SETTINGS_BAD_VALUE`) and changes nothing,
   so a bad setting never takes the input stations out of service. A
   garbled value that reaches an applier anyway refuses that station,
   detail 1 for handedness and 2 for the swap, said rather than guessed
   at.
8. **The three appliers turn one after another.** Every event answers
   to one whole pair of settings, but for the instant between two of
   them a button event and a stick change may answer to different
   pairs. A person changes these in a menu, not mid-press, so that is
   left as it is. All three are looked up before any is turned, so a
   program missing one is left wholly as it was. A station of the right
   name whose dial is not the settings stops the call where it stands,
   and the call answers `ENGINE_WRONG_SIZE`.
9. **Said on the developer line** until phase 6's apps listen
   (`say_roles_down`, `say_roles_up`, `say_roles_sticks`), beside the
   raw events' lines, which are unchanged: "say_roles_down: frame 6:
   act dpad-up; drawer top-left".
10. **The radial menu is untouched**, as 506 decided: it reads the
    physical buttons itself.

## What happened

Built on the twin as decided above.

- `src/boxes/134-input-roles.c` — `button_roles`, `stick_roles`, and
  `say_roles` and `say_stick_roles` for the developer line.
- `src/maps/input-poll.map` — `roles_down`, `roles_up` and
  `roles_sticks` off the down, up and stick-change events, and their
  three developer-line stations: 31 stations now.
- `src/system/135-input-settings.c/.h` — `input_settings_set`.
- `twin/tests/136-test-input-roles.c` (41 checks):
  - both hands, every role, the second triggers and the stick clicks;
    the raw event carried whole; the center buttons' drawers, standard
    and swapped, alone and together; handedness moving no drawer and
    the swap no role; the sticks by role, their changed bits included;
  - through the input-poll map: the map's own settings for downs, ups
    and sticks; the settings turned while it runs and the very next
    events under them; each setting turned on its own; a bad setting
    and a program that is not input-poll turned away by the call,
    changing nothing; an applier whose dial will not take the settings
    reported by the call; the raw lines said as before;
  - 200 presses while another thread turns the settings back and
    forth as fast as it can, each event under one whole pair;
  - a garbled handedness and a garbled swap refusing their appliers,
    saying which.
- `twin/tests/097` counts 31 stations.

Waiting for another stack: the call from 408's settings writer and the
boot read (decision 6).

## Related documents

- `docs/004-input-model.md`.
- `docs/011-filesystem.md` — the `/settings/` tree.

## Blocked by

408, 502.

## Blocks

508, phase 6.
