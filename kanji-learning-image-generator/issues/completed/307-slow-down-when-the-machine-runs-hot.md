# 307 — Slow down when the machine runs hot

## Current behavior

Done. `src/031a-when-the-machine-runs-hot.lua`, used by `031`:

```
luajit src/031a-when-the-machine-runs-hot.lua
```

Measured over the five hundred commonest characters, the mean temperature fell
eight degrees and the peak five, for roughly two and a half times the wall
clock. `docs/balance-updates.md` has the before and after and every knob.

**Two things came out differently from the plan.**

*The reserve is a share, not a subtraction.* Leaving two cores free is a large
concession on a four-core machine and almost none on a thirty-two core one, and
it is the **proportion** of the machine held at full load that decides the
temperature. There is still a minimum reserve and an outright ceiling.

*The rest is proportional, not a step.* Two thresholds with a fixed pause at
each treats one degree over as the same emergency as ten — it either does
nothing while the machine is genuinely climbing or throttles a run that was
barely warm. The pause now slopes between the two marks and keeps growing, to a
limit, if the temperature is still rising past the hot one.

## Was

`303` asked the machine how many processors it has and started that many workers.
On the machine this was built on that is fourteen workers on fourteen cores,
every one of them at full load, for as long as the run takes — which for the
whole archive is several minutes.

That drove the processor to the top of its thermal range. Nothing broke and
nothing was going to break: the chip throttles itself long before damage, and
the limits it reports are set with that margin in them. But sustained heat is
sustained wear, and the run was taking every core the machine had and leaving
none for the person using it.

> can you implement thread cap limits because the CPU engine is running at 99%
> heat tolerance. Lucky for us this is set to a reasonable number that implies
> no long-term damage to the system, but still wear is wear and we should try
> and slow down the wear applied when heat is high.

## Intended behavior

**Three things, and only the third is actually about heat.**

**Leave cores free.** Taking every processor is what makes a machine
unresponsive while a batch runs, and the last two cores buy far more comfort
than they buy speed. The count is `processors minus a reserve`, with a ceiling
that can be set outright.

**Ask for the work politely.** Workers run at low priority, so anything else on
the machine takes precedence. This does not reduce heat — a busy core is a busy
core — but it means a hot run never makes the machine feel broken.

**And watch the temperature, because that is what was actually asked for.**
Slowing down *on a schedule* would be guessing. This machine reports its
package temperature as a plain file, so the run can read it between characters
and rest when it is climbing:

- below the warm mark, no resting at all — a cold machine should go at full speed
- above it, a short pause between characters
- above the hot mark, a long one

That is a duty cycle, and a duty cycle is the one thing here that genuinely
lowers sustained temperature rather than redistributing it. Sustained full load
is what heats a chip; brief regular idleness lets it shed.

**A machine that will not say how hot it is gets the pauses turned off**, once,
with a notice. Resting on a fixed schedule to protect against a temperature
nobody measured is a slower run bought for nothing, and silently doing it would
be worse than not doing it.

**The run says what it did.** Peak temperature, how long it spent resting, and
how many workers it used — otherwise the governor is a thing that either works
or does not and nobody can tell which.

## Suggested implementation steps

1. **`src/031a-when-the-machine-runs-hot.lua`**, beside the batch driver it
   governs rather than after it. Reads the temperature, decides the rest, and
   sleeps without spinning — a busy-wait to avoid heat would be a joke.

2. **The thresholds and the reserve go in `input/settings.lua`**, with the rest
   of the knobs, and every change to them goes in `docs/balance-updates.md`.

3. **The temperature source is looked for, not assumed.** The kernel exposes
   thermal zones under a well-known path and the useful one is not always the
   first; it is found by its type rather than by its number.

4. **The governor is used by anything that runs long**, which is the batch and
   the phase demonstrations, not just the one place it came up.

5. **Test that it can read a temperature on this machine, and that it does the
   right thing when it cannot.** The second half matters more: the failure mode
   worth preventing is a run that rests constantly because it is reading
   nothing and treating that as hot.

## Related

`303` — what it governs. `docs/006` — the phase this joins.
