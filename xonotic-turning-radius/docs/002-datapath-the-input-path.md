# Datapath — From Keypress to View Angle

A trace of what happens between a key going down on a laptop and the player's
view rotating, through the two source trees cloned under `source/`. Every claim
below is a reading of that source, with the file and line it came from.

The purpose of this trace is to answer one question: **which layer can host each
of the three behaviors the vision asks for?** The answer turns out to be
different for each of them, which is why the trace is worth writing down.

---

## The four stages

```
  key event   ->   button state   ->   angle arithmetic   ->   sent to server
  (keys.c)         (kbutton_t)         (CL_AdjustAngles)       (cl.cmd)
      |                                        |
      |                                        |
      +--> CSQC_InputEvent()                   +--< setproperty(VF_CL_VIEWANGLES)
           game code sees the raw                  game code can overwrite the
           key event and may consume it            result before it is sent
```

Two of the four stages have a seam the game code can reach. That is the whole
reason a choice of layer exists.

---

## Stage 1 — the bind table

`binds-xonotic.cfg` is the stock keyboard layout, a flat list of `bind <key>
<command>` lines. It is a plain data file with no logic in it. The engine parses
each `+name` command into a press/release pair.

The commands the vision's layout needs already exist in the engine. Nothing has
to be invented:

| Layout key | Action wanted | Existing engine command |
|---|---|---|
| `i` / `k` | move forward / back | `+forward` / `+back` |
| `s` / `f` | strafe left / right | `+moveleft` / `+moveright` |
| `h` / `l` | turn left / right | `+left` / `+right` |
| `e` / `d` | pan view up / down | `+lookup` / `+lookdown` |
| `a` | crouch | `+crouch` |
| `;` | jump | `+jump` |
| `space` | shoot | `+fire` |

**This means the entire keyboard layout is a configuration file and no code at
all.** That confirms the instinct in the vision: the binds are a config patch.

### The collisions the layout has to clear

The stock file already uses six of those keys for other things, so a laptop bind
file cannot simply add lines — it has to displace what is there:

| Key | Stock meaning | Becomes |
|---|---|---|
| `a` | strafe left | crouch |
| `s` | move backward | strafe left |
| `d` | strafe right | pan view down |
| `e` | grappling hook | pan view up |
| `i` | show server info | move forward |
| `k` | **suicide** | move backward |

The last one is the one that matters. In the stock layout `k` kills you on press.
In the laptop layout `k` is the key you walk backward with, which you will hold
for whole seconds at a time. If the bind file forgets to displace it, laptop mode
is unplayable in a way that looks like a crash bug. The suicide command needs a
new home in the laptop layout, and that is a decision, not a detail.

---

## Stage 2 — button state, and the timestamp that is not there

The engine tracks each movement command with a small struct — `kbutton_t`,
defined in `client.h` around line 1243. It holds exactly two things: the key
numbers currently holding the button down (up to two, so a command can be bound
to two keys), and a three-bit state field. Bit zero is "down right now," bit one
is "was pressed during this frame," bit two is "was released during this frame."

`CL_KeyState()` (`cl_input.c:315`) collapses that bitfield into a single fraction
describing how much of the current frame the key was held: one if held the whole
frame, a half if pressed partway through and still down, three-quarters if
released and re-pressed, a quarter if pressed and released entirely inside the
frame, zero if untouched.

**The structure records no press time.** It answers "was this down during the
last frame" and nothing more. The moment the frame ends, the impulse bits are
cleared (`cl_input.c:354`) and the history is gone.

This is the single most consequential finding in the trace. Two of the three
behaviors the vision wants are *functions of how long a key has been held*:

- acceleration needs the elapsed hold duration to compute a rate
- tap-versus-hold needs the duration at release to classify the press
- the double-tap gesture needs the time since the previous release

None of those durations exist anywhere in the engine's input state. Whichever
layer implements the mechanic has to introduce and maintain that timing state
itself. The engine is not "almost there" — it is missing the entire notion of
how long.

The quarter-value that `CL_KeyState` returns for a press-and-release inside one
frame is *not* a tap detector, despite looking like one. It only fires when the
whole press fits inside a single rendered frame, which at sixty frames per second
means a press shorter than about sixteen milliseconds — far faster than a human
can tap. At a hundred and forty frames per second it is faster still. It is a
frame-timing artifact, not an input classification.

---

## Stage 3 — the angle arithmetic

`CL_AdjustAngles()` (`cl_input.c:431`) is the whole of Quake's keyboard turning,
and it is about forty lines. Its shape:

- Compute a per-frame scale: the real elapsed frame time, multiplied by
  `cl_anglespeedkey` (default one and a half) if the run key is held.
- Add and subtract `cl_yawspeed` (default a hundred and forty degrees per second)
  scaled by that factor and by the left/right key fractions.
- Do the same for pitch with `cl_pitchspeed` (default a hundred and fifty).
- Wrap yaw into a signed range and clamp pitch between `in_pitch_min` and
  `in_pitch_max`.

Note the shape of the rate: **a constant, multiplied by frame time.** Speed does
not depend on anything except which cvar and whether the run key is down. Turning
acceleration is precisely the replacement of that constant with a function of
hold duration — which is the state stage two does not keep.

It is called from `CL_Input()` at `cl_input.c:489`, before the movement fields
are filled in, and again at `cl_input.c:718`.

The pitch clamp is worth noticing for the acceleration question: pitch has a hard
stop looking straight up and straight down, so an acceleration ramp on pitch
spends most of its curve pressed against a limit. Yaw wraps and has no such
ceiling.

---

## Stage 4 — the seam the game code can reach

Two separate hooks let client-side QuakeC into this path.

**Reading events.** The engine calls `CSQC_InputEvent` (`csprogs.c:476`) for every
key press, key release, and mouse motion. Xonotic already implements it, at
`qcsrc/client/main.qc:496`. It receives an event type and two values, and its
return value decides whether the engine goes on to process the event normally or
treats it as consumed. Game code can therefore see every press and release as it
happens — and can stamp each one with the current time, which is exactly the
state the engine does not keep.

**Writing angles.** `setproperty` with `VF_CL_VIEWANGLES` (`clvm_cmds.c:1089`)
copies a vector straight into `cl.viewangles` — the same variable
`CL_AdjustAngles` writes, and the same one packed into the movement message for
the server. There are single-axis variants for pitch, yaw and roll at the three
following lines, and a matching `getproperty` to read the current value at
`clvm_cmds.c:918`.

So game code can both observe the timing and set the resulting angle. The
mechanic is implementable there.

### What the game-code route does not have

There is **no `CSQC_Input_Frame`** in this engine — neither tree contains the
symbol. That is the hook other Quake-derived engines use to let game code rewrite
input once per movement frame, and its absence is deliberate rather than
accidental: a comment at `clvm_cmds.c:16` records the missing piece as a known
gap, noting that a builtin to set the view angles was added *instead of* the
input-globals mechanism.

The practical consequence is a timing difference. Angle writes from game code
happen during the render frame rather than the movement frame. At normal frame
rates that is a fraction of a frame of latency on a turn, which for a
half-second sweep is invisible — but it is a real difference, and it means the
mechanic's timing is tied to the rendering rate rather than to the fixed
movement tick.

---

## Stage 5 — the mode switch already exists in miniature

The button described in the vision has an almost exact precedent in the menu.

`KeyBinder_Bind_Reset_All()` (`qcsrc/menu/xonotic/keybinder.qc:444`) implements
"reset all bindings" in three console commands: unbind everything, execute the
stock bind file, and cancel any zoom state left over. That is structurally the
same operation as "apply laptop mode" — the only difference is which file gets
executed. A laptop layout that ships as its own bind file inherits this mechanism
for free.

The confirmation dialog that calls it, `dialog_settings_bindings_reset.qc`, is
twenty lines: a label, a yes button wired to the reset function, a no button
wired to close. It is a complete and very small template for any new dialog.

The button itself would join the column built in `dialog_settings_input.qc` at
lines seventy-three through eighty-eight, which currently holds "Change key...",
"Edit...", "Clear" and "Reset all."

For the save-slot half of the one-slot undo, the engine already knows how to
serialize the current bindings: `Key_WriteBindings()` (`keys.c:1681`) is what
writes them into the config file, and the `bindlist` and `in_bindlist` console
commands (`keys.c:1726` and `keys.c:1720`) dump them for inspection. Which of
these the undo slot should be built on is an open question, because they differ
in where the output goes.

---

## What the trace concludes

The three behaviors do not live in one place, and pretending otherwise would
produce a worse system than accepting the split:

| Behavior | Layer | Why |
|---|---|---|
| the keyboard layout | **configuration only** | every command it needs already exists; it is a bind file |
| the laptop-mode button | **menu game code** | a near-copy of the existing reset-all button, plus a dialog of twenty lines |
| acceleration, tap-quantizing, gestures | **engine C, or client game code** | needs press timing that neither layer currently keeps; both can be made to keep it |

Only the third row is a genuine choice, and it is a choice between two costs.
Engine C puts the logic where the existing turn arithmetic already lives and runs
it on the movement tick, but requires the player to run a binary built here.
Client game code gets press timestamps for free from the event hook and ships as
data a player can drop into a stock install, but writes angles on the render
frame rather than the movement frame.

The first two rows are not choices and can proceed regardless.
