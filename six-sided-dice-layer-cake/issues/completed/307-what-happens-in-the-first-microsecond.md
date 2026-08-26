# 307 — What happens in the first microsecond

Produces `src/026-thermal-transient-and-throttle.md`.

## Current behavior

**Done, and it closed a question opened two phases earlier.**
`src/026-thermal-transient-and-throttle.md` exists.

**The walking hot spot is thermally invisible.** A multiplier region's time
constant against its own cold plate is about three milliseconds; a pipeline stage
is a hundred and fifty microseconds. The array reaches five per cent of its
steady rise -- about six tenths of a kelvin -- before the work moves to the next
face. The excursion is small under any face ordering, so the antipodal
arrangement `010` chose on thermal grounds earns nothing, and `010`'s open
question closes in the negative. The ordering is now free for something else.

The spout's burst is confirmed as thermally nothing: five and a half millijoules
into a face's thermal mass is under a millikelvin, which is what makes it an
energy budget rather than a power one.

Eight constraints, including the ordering of the four protection thresholds --
three constraints on four numbers that are obviously in the right order, which is
exactly the situation where one gets retuned and the order quietly breaks.

**The load step's electrical consequence is real even though its thermal one is
not**, and a reader of this file alone would come away thinking otherwise.

## Intended behavior

**The temperature history of the machine over time, at four timescales, and the
protection that acts when it goes wrong.**

Steady state is the easy case and it is not the dangerous one. What has to be
shown is that the silicon survives the transients, and the transients here are
unusually severe because of the sieve: during single-stream generation, exactly one
face is doing arithmetic at a time and it changes every hundred and fifty
microseconds.

### The four timescales

**Nanoseconds — the load step.** A matrix engine goes from idle to fully switching
in one cycle. The thermal mass that responds on this timescale is the top few
microns of silicon, which is tiny, so the local temperature spike is real. This is
the timescale `031`'s decoupling exists for electrically; thermally it sets the
peak junction excursion that `306`'s steady-state number does not capture.

**Microseconds — the spout burst.** A hundred and sixty-eight watts appears on one
face for thirty-three microseconds and vanishes. The silicon's thermal time
constant is around a millisecond, so the burst is absorbed as stored energy
rather than conducted away. Five and a half millijoules into the thermal mass of a
face. The blueprint must show the resulting rise, which should be small, and say
what the maximum permissible burst length is before it stops being small.

**Hundreds of microseconds — the walking hot spot.** One face works, then the
next, around the cube once per token. `010` chose the antipodal face ordering
specifically so that consecutive stages are as far apart as possible. **This
blueprint is where that choice is paid off or shown not to matter**, by computing
the temperature swing on one face over a token period under both orderings and
comparing. If the difference is negligible, `010` should be told and the ordering
freed for other uses.

**Seconds — the loop.** The coolant takes seconds to go round the external loop in
`027`, so a sustained load change takes seconds to reach the radiator and come
back as a changed inlet temperature. This is the timescale on which the control
loop lives, and a control loop with seconds of transport delay and a millisecond
plant is one that must be slow or it will oscillate.

### The protection

Three levels, each with a threshold, a response, and a stated response time:

- **Throttle.** Clock and engine utilisation reduce. Recoverable, invisible except
  as slower generation.
- **Halt.** Faces stop issuing. The model stays resident. Recoverable in
  microseconds once temperature falls.
- **Cut.** Power removed. Not recoverable without a host. Reserved for a coolant
  failure, where nothing electrical can help.

The thresholds must be derived from `306`'s margin and the transient rates here —
a threshold set below the peak of a normal load step is a machine that throttles
constantly, and a threshold set above the fatal excursion is a machine that
throttles once.

**Where the sensors are matters more than how many there are.** A sensor on the
edge of a die reports a temperature the hot spot passed through some
milliseconds ago. `609` owns the sensor placement and this blueprint owns the
requirement it must meet: the sensor-to-hot-spot lag must be shorter than the time
between the throttle threshold and the fatal one at the worst load ramp.

## Symbols this must publish

Thermal capacitance at each level of the stack. Time constants for each of the
four timescales. Peak excursion for the load step, the spout burst and the
walking hot spot. The three protection thresholds with their response times. The
sensor lag requirement. Maximum permissible spout burst.

## Constraints this must assert

- Peak junction temperature including all transient excursions stays under the
  limit, which is a stricter test than `306`'s steady-state one.
- The throttle threshold sits above the normal load-step peak and below the halt
  threshold, which sits below the fatal excursion. An ordering constraint on four
  numbers, and the kind of thing that is obviously right and quietly gets violated
  when one of them is retuned.
- Sensor lag is shorter than the throttle-to-fatal interval at maximum ramp rate.
- The spout's maximum burst energy divided by the face's thermal capacitance gives
  a rise under a stated allowance.

## Suggested implementation steps

1. Build the lumped capacitance model, one node per layer of `014`'s stack.
2. Run the four timescales.
3. Compare the two face orderings and report whether `010`'s choice earns itself.
4. Set the thresholds from `306`'s margin and assert the ordering.
5. Derive the sensor lag requirement and hand it to `609`.

## Blocks

`308`, `609`, `1005`.

## Blocked by

`301`, `305`, `306`, `901` for the spout's burst profile.

## Related documents

`005`. `010` for the face ordering this validates. `007` for the burst.
