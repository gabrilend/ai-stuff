# 702b — Devices that die realistically

## Current behavior

**Done, and tested** -- `src/092`, checked by `src/093`, 18 of 18 on
2026-08-02.

Death is absence rather than announcement: the part stops responding and says
nothing about why, because the real one cannot. The bus gives back all-ones,
which is also a perfectly plausible register value.

Death survives a power cycle. A part that came back would forgive the exact
mistake being tested for, so the cycling is a function rather than an
assumption, and it is checked: what was merely busy returns, what was
destroyed does not.

The slow death is modelled. A part with its thermal protection switched off
keeps working, is still working a while later, and then stops -- by which
time the machine is doing something else entirely and nothing about the
moment of failure points at the write that caused it. That is the case most
likely to be blamed on the wrong thing, and a machine that has only met
instant death will blame the wrong thing.

**The three-way confusion is the point, and it is the check the file exists
for.** A destroyed part, a busy part and an unpowered part are all on the
bench at once, and from inside the machine they are indistinguishable -- the
test requires that they be indistinguishable rather than requiring the
machine to tell them apart. `docs/003a` names that as honestly hard, and this
is that hardness made testable instead of argued about.

What it still does not cover, and cannot: these are described devices. A real
board is full of parts nobody wrote down, and a machine exploring one of
those passes everything here while destroying hardware. That gap is in
`notes/023` with the others, unpaid.

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
