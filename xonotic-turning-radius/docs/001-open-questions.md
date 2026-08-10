# Open Questions

Questions raised by the vision that have not been answered yet. Each one is
stated with the mechanism behind it, because most of them are not preferences —
they are forks where two designs are both coherent and produce different games.

Nothing here is rhetorical. The project is not finished while any of these is
open, and answering them one at a time is the work.

---

## Resolved

### The kill key — answered

Stock Xonotic binds `k` to suicide. The laptop layout makes `k` the
walk-backward key, held for whole seconds at a time, so the stock binding cannot
survive unchanged.

**Answer: three times in a row.** Suicide fires on a triple tap rather than a
single press.

This is a better answer than any of the three that were offered, because it does
not move the command at all. The key that means "kill" in muscle memory goes on
meaning kill; what changes is the *effort* required, and the effort scales with
how much you should have to mean it. It also extends the gesture vocabulary from
two levels to three, which makes the whole input language more regular rather
than less:

| Gesture | Meaning |
|---|---|
| hold | the continuous action (turn, walk) |
| tap | the quantized action (quarter turn) |
| double tap | the compound action (one-eighty, crouch latch) |
| **triple tap** | **the irreversible action (suicide)** |

Reading the ladder downward: the more taps, the less recoverable the outcome.
That is a real principle and it should be written down as one, because it will
answer future questions about where to put things without having to ask.

The follow-on conflict this creates is open — see section G.

---

## A. Where the double-tap gestures went

The gestures were specified against the arrow cluster: *double up* is a
one-hundred-eighty degree turn, *double down* latches crouch until the next jump.
The layout has since moved and the arrow cluster is gone, so both gestures are
currently homeless.

### A1. Which keys carry the two gestures now?

The literal translation is `e` (pan up) and `d` (pan down), since those inherited
the arrow cluster's vertical pair. But `e` and `d` are on the *left* hand and the
one-hundred-eighty is a *yaw* action, so the gesture would be performed by the
hand that does not control yaw. The alternative is to put both gestures on the
yaw keys — double-`h` and double-`l` — which puts the turn on the hand that turns,
at the cost that a double-`h` is ambiguous with two quarter turns left (see D3).

### A2. Crouch now has two homes. Which does what?

`a` is a crouch key under the left pinky. The gesture is *also* crouch, but
latched. So there are two crouch affordances with different lifetimes:

| Affordance | Lifetime |
|---|---|
| hold `a` | crouched while held, stands on release |
| the double-tap gesture | crouched until the next jump, hands free |

Is that the intent — a hold and a latch as separate tools? Or should `a` itself
carry both, where holding crouches and double-tapping latches? The second is
tidier and frees a gesture slot, but it means the pinky does two jobs whose
difference is a timing distinction the pinky is the worst finger to make.

### A3. "Until next jump" — jump is now `;`.

Confirming the obvious reading: the latch releases when `;` is pressed. Not on
landing, not on a timer. If the player never jumps, they stay crouched
indefinitely.

### A4. Does the spacebar gesture survive?

The question that ended the original sketch — *"ah double spacebar... good
enough?"* — was never resolved, and space has since become shoot. A double-tap on
shoot is dangerous by default: firing twice quickly is the single most common
thing a player does in a shooter, so any gesture on that key would fire constantly
by accident. Recommendation is that space stays a pure trigger, but it is your
sketch and worth a deliberate answer rather than a silent drop.

---

## B. What a quarter turn actually means

### B1. Relative or absolute?

Two readings of "tap it to quarter turn":

- **Relative** — add exactly ninety degrees to the current heading. Predictable
  from anywhere: a tap always turns you the same amount, regardless of where you
  were pointing.
- **Absolute** — snap to the nearest multiple of ninety degrees in world
  coordinates. This *aligns you to the map*. Arena shooter geometry is largely
  right-angled, so absolute snapping would leave you square to corridors and
  doorways every time, and four taps would visit exactly four headings forever.

Absolute is the more interesting mechanic and the more fragile one: it is only
useful on maps whose architecture is axis-aligned, and it silently does nothing
useful on a map built at forty-five degrees. Relative always works and never
surprises.

### B2. Instant, or swept?

An instantaneous ninety-degree jump is cheap to implement and disorienting to
receive — the player loses track of what was where, because nothing moved through
the intervening space; it teleported. A sweep over roughly a tenth of a second
reads as a very fast turn and preserves the spatial continuity, at the cost of
being interruptible and of needing state that persists across frames.

Same question, more sharply, for the one-hundred-eighty: a snap-180 is a
well-established shooter convention, so precedent argues for instant there even if
the quarter turn sweeps.

---

## C. The shape of the acceleration

### C1. Does the ramp apply to pitch, or only yaw?

Yaw is unbounded — it wraps, so a long hold can spin freely. Pitch is clamped at
straight-up and straight-down, roughly ninety degrees each way from level. An
acceleration ramp on pitch therefore spends most of its curve against a wall: by
the time the ramp has ramped, you are already looking at the ceiling. Leaving
pitch linear and reserving acceleration for yaw is the mechanically honest option.

### C2. What curve, between what endpoints?

The engine's existing keyboard turn is a flat rate — a cvar in degrees per second,
multiplied by frame time. Acceleration replaces the constant with a function of
how long the key has been held. Three candidate shapes:

- **Linear ramp** — start slow, climb steadily to a ceiling over some hold
  duration. Easy to reason about; feels mechanical.
- **Exponential** — slow start, sharply increasing. Feels most like mouse
  acceleration; hard to control in the middle of the curve.
- **Two-stage** — a precise low rate for the first fraction of a second, then a
  step to a fast sweep rate. Crude, but it maps directly onto the two things a
  player actually wants: fine aim, and getting around.

Needed either way: the start rate, the ceiling rate, and the time to reach the
ceiling.

### C3. The tap/hold threshold.

A release before the threshold is a tap and fires a quarter turn. A release after
it was a hold and fires nothing extra. The threshold has to be long enough that a
deliberate tap always lands inside it and short enough that a hold never does —
somewhere in the low hundreds of milliseconds, but the exact value changes the
feel more than any other number in the project.

### C4. The double-tap window.

Same class of number, same sensitivity. Too long and every pair of quarter turns
becomes an accidental gesture; too short and the gesture is unreliable.

---

## D. Collisions between the three behaviors

### D1. A tap inside a double-tap.

Tapping the turn key twice quickly is *both* two quarter turns and one double-tap
gesture. If both fire, the player gets a one-hundred-eighty from the gesture plus
a further one-hundred-eighty from the two quarter turns, and ends up back where
they started. Something has to win. The usual resolution is to delay acting on the
first tap until the double-tap window closes, which makes every single tap feel
sluggish by exactly the window duration — a real cost.

### D2. Does the mouse still work?

Presumably yes, additively, since laptop mode is for when the mouse is absent but
should not break when it is present. The follow-on: if a swept turn is in
progress and the player moves the mouse, does the sweep abort? Aborting respects
the player's intent; not aborting makes the sweep predictable.

### D3. Zoom.

A sniper zoom multiplies the effect of every angular input. A ninety-degree snap
while zoomed is almost never wanted. Should tap-quantization and the gestures
suppress themselves while a zoom is active?

---

## E. The mode switch

### E1. What counts as "saved"?

The button restores binds "to what they were before the previous time they were
saved." Xonotic writes binds to its config file at specific moments, not
continuously. Pinning which moment counts is required before the one-slot undo can
be built, because the slot's contents are defined relative to it.

### E2. Does laptop mode survive a restart?

Two designs. Either the mode is a *state* recorded in the config, restored on
launch and reflected in the button's label from the first frame; or the mode is a
*one-shot action* that writes binds and is thereafter indistinguishable from the
player having typed them. The second is far simpler and loses the label's memory
across sessions.

### E3. What counts as "the user changes a keybind"?

The label reverts to "laptop mode" when the player edits a bind. Does that mean
only edits made through the menu's bind list, or also a `bind` command typed at
the console? Menu-only is easy to detect. Console commands are harder to observe
and are how experienced players actually rebind.

### E4. Where does the button live?

Presumably the input settings page, next to the existing bind list. Worth
confirming, since it is the one piece of this that a player has to *find*.

---

## F. Delivery

### F1. A data file, or a whole build?

The two layers reach different audiences. Something that lives entirely in game
data ships as a single file a player drops into their existing Xonotic install.
Something that lives in the engine requires them to run a binary you compiled. The
source reading now in progress will report which layer can actually host each of
the three behaviors; this question is what to do if they turn out to be split
across both.

### F2. Servers.

In Quake-lineage netcode the client owns its own view angles and reports them to
the server, so client-side turning should work on any server without cooperation.
Worth confirming that no anti-cheat in Xonotic's competitive configuration objects
to angle changes at rates a mouse would not produce — a snap-180 looks, to a naive
detector, exactly like an aimbot.

---

## G. The triple tap sits on a movement key

Suicide now fires on three presses of `k` in a row. In the laptop layout `k` is
also walk-backward. So the question is whether three presses of walk-backward is
a thing a player does by accident.

It is, and here is the mechanism. Backpedalling in an arena shooter is not one
long hold — it is a series of taps, because a player retreating while shooting
alternates between backing off and standing to fire. Dodging is worse: rapid
alternation on the movement keys is the basic evasive motion. Both produce runs
of three or more presses of the back key inside a short window, which is exactly
the signature the triple tap is watching for.

The consequence of a false positive is not a mis-turn. It is death, at the
moment you were already under pressure, since being under pressure is what
produced the tapping.

Four ways out, and they are genuinely different in character rather than being
variations on a theme:

1. **Tighten the window.** Require the three presses much faster than combat
   tapping ever goes. Cheap, and it only narrows the failure rate rather than
   removing it — the tail of "sometimes you tap really fast" never reaches zero.

2. **Require the taps to be otherwise idle.** Suppress the gesture unless the
   player is standing still, or not firing, or not taking damage. Kills the false
   positive precisely where it lives, since every accidental run happens during
   motion or combat. Costs a condition that has to be read from game state, and
   makes the gesture refuse to work at the moment some players actually want it.

3. **Move the triple tap off the movement keys entirely.** Keep the principle —
   three taps for the irreversible thing — but put it on a key with no continuous
   meaning. This preserves the gesture ladder and gives up the pleasing property
   that `k` still means kill.

4. **Accept it.** Suicide in Xonotic costs a respawn and a point, not a match. If
   the false positive is rare enough, the cost of a bad frame may be less than
   the cost of the machinery that prevents it.

There is a related structural question underneath. A triple tap cannot be
recognized until the third press, so the detector must hold the first and second
presses in suspense — but those presses are also *walk backward*, which must
happen immediately or the controls feel broken. So the movement has to fire
straight away while the gesture watches from the side, and the gesture must be
able to fire without undoing the movement that already happened. That is a
different arrangement from the quarter turn, where the tap's meaning genuinely
has to wait. Worth deciding once, in general, rather than twice by accident:
**which gestures are allowed to act late, and which must act immediately and be
recognized in parallel?**
