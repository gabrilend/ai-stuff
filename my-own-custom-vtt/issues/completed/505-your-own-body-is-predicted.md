# 505 -- Your own body is predicted

**Phase:** 5, the bridge and the browser
**Blocked by:** [504](504-drawing-between-two-ticks.md)
**Blocks:** [508](508-the-phase-five-demo.md)
**Documents:** [the dynamic picture](../docs/012-the-dynamic-picture.md)

## Current behaviour

Everything is drawn one beat behind live.

## Intended behaviour

The body you are driving moves on your screen the instant you press a key, before
the server has confirmed anything.

**Without prediction the controls feel dead**, and "feels like a video game" is
mostly a statement about whether the controls feel dead. A fiftieth of a second
is imperceptible when watching somebody else move and very perceptible when it
sits between your hand and your own character.

### It is the one place the client shows unconfirmed state

That is worth saying plainly, because everything else in this project insists the
client is never trusted.

It is not an exception to that rule. **Predicting where your own character is
reveals nothing you did not already know** -- you pressed the key. The client is
not being told a secret; it is guessing at the consequence of its own action.

Three constraints keep it honest:

- **Only a body the viewer commands.** Never anybody else's, and never anything
  they merely see.
- **Always overwritten** by the server's answer when it arrives.
- **Never affects what is sent.** Prediction is a drawing state, and a command
  reports what was pressed rather than where the client thinks it ended up.

### Reconciling without a visible snap

When the server's position differs from the predicted one -- because a wall
stopped the body, or a rollback happened -- the correction must not teleport.

Ease toward the truth over a few frames rather than jumping. But **cap it**: past
a certain distance, jump. A large disagreement means the prediction was wrong
about something structural, and easing across a room looks worse than a snap and
takes longer to stop being wrong.

`OP_RECALL` discards the prediction outright. A rollback throws all of it away at
once, and the correction will be large and visible rather than the usual
imperceptible nudge -- which is honest, because something visible did happen.

## Suggested implementation steps

1. Apply held keys to the local copy of the commanded body each frame.
2. On each update, compare and ease -- with the cap, and a comment saying why the
   cap exists.
3. Discard prediction entirely on `OP_RECALL`.
4. Never predict anything else, and put that in a comment where somebody would
   otherwise generalise it.
5. Write the companion `.info.md`.
