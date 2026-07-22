# BCI branch — research findings (issue 207)

> **EXPERIMENTAL. DOCUMENTED, NOT SCHEDULED. This branch gates nothing** and is not
> the Phase-2 input source — it is the sacrosanct stretch dream, quoted verbatim:
> *"reads common brain patterns like 'look up and to the left' ... which moved the
> headset mounted to the ceiling at just the right tension."* Per the issue's own
> steps, this is the SOFTWARE rehearsal against a scripted attention trace, run
> before any real EEG or servo exists. What cannot yet be done is stated plainly,
> per the no-silent-fallback rule.

## What is proven (software, done)

- **Attention decoder (007):** a coarse attention direction, held over time, drifts
  the aim (yaw/pitch) that way and clamps at the neck's limits — "moving their
  attention upward and leftward" moves the gaze up and left. Pure and deterministic.
- **Ceiling-headset tension model (008):** an aim becomes the four cable tensions
  (N/S/E/W) that would hold the head there; cables in the lean direction tighten,
  opposites ease. The **"just the right tension" invariant** — a moderate lean keeps
  the *average* cable tension exactly at the resting base — holds and is tested.
- **Scripted-trace demo (009):** the example daydream (center → up-left → right →
  down → center) runs the full pipe attention → aim → tensions; **12/12** assertions
  pass, and the report shows the mean tension pinned at 50.0 across the whole trace.
- **Artifact:** `run-bci-experiment.sh` (the `${DIR}` convention, runs from any
  directory, reads `input/` first) writes `bci-trace-report.txt` to the RAM tier.

## The open research + hardware questions (the honest unknowns)

This is the part to be candid about; the software above is the *easy* half.

- **Real EEG decoding is the hard, unproven part.** Consumer headsets (Muse,
  OpenBCI, Emotiv) can flag coarse states, but robustly decoding *continuous
  directional attention* — "up-and-to-the-left" vs "up-and-to-the-right" — in real
  time is an open research problem: noisy, low-bandwidth, and heavily per-user
  calibrated. The scripted trace stands in for a decoder we do not have.
- **The ceiling rig is a safety-critical mechatronics sub-project.** Four
  servo-winched cables, load cells, and — because this is a headset on a person's
  skull pulled by motors — "at just the right tension" is literally a *safety*
  constraint, not only poetry. Actuation, force limiting, and fail-safe release are
  out of software scope and must be designed as hardware.
- **Calibration is per-user.** The tension band (base/min/max) here is a placeholder;
  a real rig would tune comfortable, safe head-motion limits per wearer.

## How it would plug in (deferred until Phase 2 exists)

The issue's design says this becomes one more **source behind Phase 2's aim
abstraction (issue 206)** — implementing `advance / activate / deactivate /
descriptor`, with the descriptor flagging "provides orientation but NOT real
per-hand poses," so 205's idle pose fills the hands. That interface does not exist
yet, so this spike deliberately does not wire into it; the decoder + tension model
are proven standalone so they are ready when 206 lands.

## Next questions

1. Which EEG path and directional-attention decoder — and can it hit usable latency
   and accuracy per user, or does the dream need a physical fallback control?
2. The rig's actuation + force-limiting + fail-safe design (the safety core)?
3. Per-user tension/comfort calibration?
4. Wire the decoder into Phase 2's source interface (206) once that is built.
