# 702b — Devices that die realistically

## Current behavior

`702a` catches the machine doing something forbidden, by stopping the world. That
answers whether the discipline held. It does not resemble hardware at all, and it
is not meant to.

## Intended behavior

Devices that behave the way destroyed hardware behaves — which is to say,
ambiguously, silently, and sometimes later.

This exists to test a different claim from `702a`. Not "did the machine obey the
rules," but "when a part stops answering, can the machine work out what
happened?" `docs/003a` names that as honestly hard: from inside, a destroyed
device, a busy device and an unpowered device all look the same.

## Suggested implementation steps

1. Model death as absence rather than as announcement. The device stops
   responding. It does not report that it was killed, because the real one cannot.
2. Make death survive a restart of the emulated machine. A part that recovers when
   power is cycled is a bug that forgives the exact mistake being tested for.
3. Model the slow death. Thermal damage does not present at the moment of the
   mistake — the part works for a while and then stops, and by then the machine is
   doing something unrelated. This is the case most likely to be blamed on the
   wrong thing, and a machine that has only met instant death will blame the wrong
   thing.
4. Provide the three-way confusion deliberately: a device that is destroyed, one
   that is merely busy and will answer eventually, and one that is unpowered and
   would answer if it were not. Put all three in one run and see what the machine
   concludes.
5. Include a device that hangs the bus when read at an address nothing answers on,
   since that is the likeliest way an early machine stops without destroying
   anything, and it is recoverable in a way the others are not.
6. Judge the machine by what it writes down, not by whether it guessed right.
   Concluding "this device stopped answering and I do not know why" is the correct
   answer to an ambiguous situation, and a machine that confidently names a cause
   it cannot know has done worse than one that says it does not know.

## Blocks

Nothing.

## Blocked by

`702a`. Testing whether a machine copes with ambiguity is only worth doing once it
has been established that it does not walk into the forbidden registers to begin
with.

## Related documents

`docs/003a-datapath-careful-exploration.md` — how does the machine know a device
died, and does a gravestone ever get retried.
