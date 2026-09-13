# Phase 8 Progress — The Handheld

**The goal:** the simulation as a map of boxes, two screens, a stylus, and a build
the compile script already knows the shape of.

**Ends with:** two handhelds side by side, finding each other over the radio and
playing a match — pending the sibling project's radio phase — and, before that,
one handheld playing the same seed as a computer and printing the same hash.

| Issue | | Status |
| --- | --- | --- |
| 801 | The simulation is a map of boxes | not started |
| 802 | Two screens, two lenses | not started |
| 803 | Buttons, chords, and the four-button menu | not started |
| 804 | Patterns drawn with a stylus | not started |
| 805 | The handheld build | not started |
| 806 | Two handhelds play a match | not started |

**Blocking:** G1 is a direction set (hand-ported boxes, the Lua as reference). G2
and G3 are questions for a person holding the device. F4 blocks the capstone.
The sibling project's phases 3 through 7 — its runtime, filesystem, input,
compositor, and radio — block everything here in practice.

**Carry into the work:** every system in the tick is a pure function over flat
arrays that writes only its slice, and the phase 8 test asserts exactly that
before any box is written.

**Demo:** not yet built.
