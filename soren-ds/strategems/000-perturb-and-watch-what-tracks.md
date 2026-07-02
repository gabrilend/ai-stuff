# perturb, and watch what tracks

a strategem — one of those patterns that keeps turning up in
places that have nothing to do with each other, which is how you
know it's real and not just a thing you noticed once.

## the pattern

you can't tell a real measurement from a convincing fake by
staring at the number. a wrong reading and a true one can print
the exact same value. so don't stare. change *something you
control* and watch whether the number follows. a real measurement
is a function of the world — poke the world, it moves. a fake
ignores the poke and just sits there. the poke is the whole test.

then, once it tracks, follow the good signal *backward* —
upstream, toward the source — until you reach the spot where it
stops tracking. that spot is the fault.

## where it's shown up (this is why it's proven)

- **an adc that wouldn't read right.** the analog-to-digital
  converter returned `0x3FF` — full scale, all ten bits set — on
  every channel. a legal value! an input actually pegged at the
  reference voltage really would read that, so you can't tell from
  the number alone. the test wasn't a cleverer read, it was: move
  the stick and watch. a real conversion sweeps as your thumb
  moves; the stuck value doesn't budge. (it was the wrong
  registers — v1 layout on v2 silicon. see the analog-stick
  section of `docs/014-hardware-overview.md`.)

- **asking around a company when you're stuck.** you don't guess
  who knows the answer any more than you guess register offsets.
  you inject the question into your network and watch which
  relationship *responds* — which one tracks. then you work
  backward through whoever they point you at until you reach the
  person who actually knows.

- **keeping goodwill.** same shape again. you don't find out
  whether a friendship is real by being *watched* being nice. you
  put small, genuine signal down the line when nothing's at stake,
  and see whether it stays live.

## the corollary: trust the response that can't be faked

the reading you can trust is the one that *couldn't* have been
the disguise.

- on the adc: ground the input pin. a real converter *has* to
  swing to `0x000` — it has no choice. a stuck `0x3FF` that
  ignores a grounded input has just confessed. one known point the
  fake can't fake beats a thousand guesses.

- on goodwill: the compliment you pay someone *behind their back*,
  to a person who might carry it back to them. it costs you and
  returns you nothing directly, so it can't be currying favor.
  praise given where they can't see it is the only praise that
  proves itself.

same move both times: supply a signal the fake can't produce, and
the fake gives itself away.

## the other half: silence isn't neutral

a network that only routes *toward* help is half-blind. you also
need to know who to run *from*, and that travels the same wire.
when people stop talking, the org doesn't go quiet-and-fine — it
loses its map. everybody's still doing their job and nobody can
find the person who'd turn a week into an hour. silence isn't the
absence of a signal. it's the loss of one.

---

*came out of the SAR-ADC v2 debugging — the constant-0x3FF read
that three separate observations independently flagged as fake —
and the conversation that followed it, on 2026-07-01.*
