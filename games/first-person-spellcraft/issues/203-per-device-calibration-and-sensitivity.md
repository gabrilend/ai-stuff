# 203 — Per-device calibration and sensitivity

> **Phase:** 2 — Dual-Mouse Aiming & Input
> **Difficulty:** medium
> **Depends on / blockers:** [202](202-per-hand-state-and-hand-role-assignment.md)
> (there must be per-hand state for calibrated deltas to land in);
> [201b](201b-per-device-evdev-read-loop.md) (raw deltas to shape).
> **Blocks:** 204 (geometry wants matched, calibrated hands to feel right).

## Current Behavior

None of this exists yet — greenfield. Raw device deltas would flow straight into
hand poses at whatever raw scale the hardware reports. Two different mice (a heavy
1600-DPI mouse and a twitchy 12000-DPI one) would feel wildly mismatched, and the
two hands of one boomstick would move at different speeds for the same physical
effort.

## Intended Behavior

Each mouse is calibrated **independently**, so the left and right hands feel
matched regardless of the two devices' native resolutions. A per-device
**calibration profile** sits between the raw delta (201b) and the hand-state
integral (202) and shapes the motion:

- **Sensitivity / scale.** A multiplier (and optional per-axis multiplier) turning
  raw counts into hand-motion units. This is the primary knob for matching two
  mismatched mice.
- **Dead-zone.** A small threshold below which a delta is treated as zero, to kill
  sensor jitter when a hand is meant to be still.
- **Axis inversion.** Per-axis flip, for mice mounted or held in unusual
  orientations (a boomstick peripheral may hold a mouse sideways).
- **Response curve.** An optional non-linear map (e.g. a gentle acceleration or a
  precision-favoring curve) applied to the magnitude — accel is "like magic," but
  it must be an explicit, inspectable curve, not a hidden constant.
- **Re-center offset.** Ties into 202's re-center so a hand can be zeroed to a
  comfortable rest pose.

Per project convention, these are **balance/knob values**: the shipped defaults
and the reasoning for each change belong in
[docs/balance-updates.md](../docs/balance-updates.md) (append-only), not in an
issue file. This issue builds the *mechanism*; the tuning log records the *turns*.

## Suggested Implementation Steps

1. **Define the calibration profile struct.** Per device: scale (and optional
   per-axis scale), dead-zone threshold, per-axis inversion flags, an optional
   response-curve descriptor, and any stored re-center offset. Small struct of
   primitives.
2. **Define the shaping function.** Input: a raw per-device delta. Output: the
   calibrated delta. Order of operations matters and should be commented: apply
   dead-zone → apply inversion → apply response curve to magnitude → apply scale.
3. **Wire it into the pipe.** The shaping runs in 202's "integrate tick into hand"
   step, before the delta is summed into the grip pose. Left and right hands use
   their own profiles.
4. **Persist profiles.** Load/save per-device profiles keyed by the same stable
   device key used for role binding, so a mouse keeps its feel across sessions.
5. **Interactive calibration helper (optional but recommended).** A small routine
   that measures a device's motion over a known physical gesture and suggests a
   scale so both hands match — writes its suggested defaults into
   `docs/balance-updates.md`'s record when accepted.
6. **Tests.** Feed known raw deltas through a known profile and assert the shaped
   output (dead-zone eats small jitter; inversion flips sign; scale multiplies;
   the curve is monotonic). Pure function, trivially testable.

## Structures & Functions By Role

- A **calibration profile** record (per device).
- A **shape raw delta → calibrated delta** function (pure).
- **Load / save profiles** keyed by stable device key.
- An optional **suggest calibration** helper that proposes matched scales.

## Design Notes To Record As Comments

- Why per-device and independent: two identical-looking mice can report different
  counts-per-inch; matching them is the whole reason this layer exists.
- Why the operation order is fixed: dead-zone before scaling (so the threshold is
  in raw sensor units), curve before final scale (so the curve reshapes feel and
  the scale sets overall speed). Reordering changes feel subtly — document before
  changing.

## Related Documents / Tools

- Datapath: [datapath-dual-mouse-input.md](../docs/datapath-dual-mouse-input.md)
  — the "calibration seam" inside stage [3].
- Sits inside: [202 — per-hand state and hand-role assignment](202-per-hand-state-and-hand-role-assignment.md).
- Tuning log for the actual numbers: `docs/balance-updates.md` (append-only).
