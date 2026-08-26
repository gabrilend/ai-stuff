# 308 — Everything outside the cube

Produces `src/027-external-loop.md`.

## Current behavior

**Done.** `src/027-external-loop.md` exists, and its real content is a trade
rather than a component list.

**The margin should be spent on removing the chiller.** A twenty-five degree
inlet in a twenty-two degree room is a three kelvin approach, which no air-cooled
radiator of a sensible size delivers -- it needs a refrigeration plant with its
own several hundred watts. A fifty degree inlet needs twenty-eight kelvin, which
a radiator and a fan manage easily, and the junction goes to about ninety with
room still to spare. A constraint asserts that the trade is available.

Pump redundancy is cheap for the reason `024` found: losing one of two pumps
costs about four kelvin, not half the cooling.

Seven constraints. The leak budget was rebuilt after the checker noticed that a
helium leak rate is a pressure-volume throughput with the dimensions of power and
cannot be compared against a reservoir emptying; divided by the working pressure
it becomes a volume flow, and a hundred and sixty-six joints come to a few cubic
millimetres a year.

**The inlet is still specified cold.** The whole argument here says it should not
be, and changing it is one edit -- not made, because the junction temperatures
printed throughout the documentation assume the cold inlet and reconciling them
is a pass somebody has to do deliberately.

## Intended behavior

**The pump, the radiator, the reservoir, the filtration, the instrumentation and
the interlock — specified as a system with a duty point, not as a shopping list.**

The cube is a heat exchanger with a specified inlet condition. Something has to
produce that condition, and if it cannot, every number in phase 3 is wrong.

### The pieces

**The pump.** Duty point from `305`: three and a half litres a minute against
about four tenths of a bar. Trivially small. The requirements that are not trivial:
it must not shed particles into a hundred and fifty micron channel, and it must
be redundant, because a pump failure with the machine at full power gives — from
`307`'s thermal capacitance — a very short time before the halt threshold. The
blueprint must state that time.

**The radiator.** Nineteen hundred and ten watts into air. Roughly twelve kelvin
of approach at a plausible face area and airflow. This is the term that decides
whether the machine needs a chiller: if the coolant inlet must be twenty-five
degrees and the room is twenty-two, the approach is three kelvin and a chiller is
required. If the inlet may be fifty, the approach is twenty-eight and a radiator
and a fan will do. **`005`'s sixty kelvin of junction margin should be spent
here**, and this blueprint is where that trade is made explicit.

**The reservoir and make-up.** Expansion volume over the operating temperature
range, plus the total permitted leak from `205`, plus the spillage per service
event from `207`, over the service interval. A number, not a jar.

**Filtration.** The single specification that protects the microchannels. Absolute
rating must be a stated fraction of `012`'s channel width, and the blueprint must
say what happens as the filter loads — a filter that raises system resistance as
it clogs moves the duty point in `305`, and the machine should notice before a
channel does.

**Instrumentation.** Inlet and outlet temperature, flow, pressure, reservoir
level, and conductivity if the fluid is water. Each with a purpose, a threshold
and an action; a sensor with no action attached is a sensor nobody reads.

**The interlock.** Coolant failure is the one fault where nothing electrical
helps. The interlock must cut power on flow loss faster than `307`'s halt
threshold allows, and it must be independent of anything running on the cube,
because a cube that is overheating is a cube that cannot be trusted to notice.

### The property nobody expects

From `305`: in laminar flow the convection coefficient does not depend on velocity.
So **halving the flow does not halve the cooling** — it doubles only the coolant's
own temperature rise, which is seven point eight kelvin of a thirty-six kelvin
chain. A pump at half speed costs about four kelvin of junction temperature. That
makes graceful degradation on a partial pump failure genuinely graceful, and it is
worth a paragraph because it is the opposite of what a reader will assume.

## Symbols this must publish

Pump duty point and redundancy scheme. Time to halt on pump loss. Radiator
capacity, approach temperature and airflow. Chiller requirement as a boolean
derived from the inlet target. Reservoir and expansion volume. Make-up volume over
the service interval. Filter rating and clean and dirty pressure drops. Sensor
list with thresholds and actions. Interlock response time.

## Constraints this must assert

- Radiator capacity at the design airflow exceeds the total heat from `301`.
- The interlock responds faster than the time to reach `307`'s halt threshold on
  total flow loss.
- Filter absolute rating is under a stated fraction of the microchannel width.
- Reservoir volume exceeds thermal expansion plus total permitted leak plus
  service spillage over the interval.
- Dirty-filter system resistance still intersects the pump curve above the minimum
  acceptable flow.

## Suggested implementation steps

1. Fix the inlet temperature target, and make it a symbol, because it is the
   parameter that decides whether a chiller exists.
2. Size the radiator against it and report the chiller boolean.
3. Take the duty point from `305` and pick a pump; derive time-to-halt from
   `307`.
4. Sum the reservoir volume from three independent sources.
5. Specify filtration against the channel width.
6. Write the sensor table with an action per row, and the interlock separately,
   because it is not a sensor.

## Blocks

`1205`, `1206`, `1301`, `1302`.

## Blocked by

`205`, `207`, `302`, `305`, `307`.

## Related documents

`005` for the margin this blueprint decides how to spend.
