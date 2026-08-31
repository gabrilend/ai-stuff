# 104 — Sampling, and where the randomness comes from

## Current behavior

**The reference exists and is tested.** `src/040` chooses; `src/041` checks it,
9 of 9 on 2026-08-02.

Determinism holds: the same carried numbers give the same choices, different
ones give different choices. Each carried number seeds a generator yielding
four thousand draws, so the file lasts. Running off the end is noticed and
recorded rather than passed over silently.

Three things the tests pinned down that are easy to get wrong: temperature
below one sharpens and above one flattens (reversed, the machine is frozen or
incoherent with no error either way); a temperature of zero is a different
instruction rather than a very small one; and with nothing cut away **every**
token must be reachable, since an unreachable tail is a word the model can
never say.

Sorting breaks ties by token number, so two identical images cannot disagree
through an unstable sort.

**The assembly version exists and agrees exactly** — `src/057` emits it,
`src/058` holds it to the reference: fifteen thousand draws across ordinary,
sharpened, flattened, tail-cut, frozen and wrapped settings, every choice
identical and every chance identical to the bit, with the two streams walking
in step. 8 of 8 on 2026-08-02.

Getting there respecified the reference the same way the forward pass was
respecified. Every floating step is now single precision and the exponential
is the specified one (`047`) — a chosen token is discrete, and a hair of
difference at a boundary sends two implementations down different lives. And
the generator moved to exact sixty-four bit integers: the first version
multiplied in host numbers that hold integers exactly only to fifty-three
bits while the product reaches sixty-one. It looked like an integer generator
and quietly was not — the same lesson as `notes/023`, caught before a fixture
froze it.

The assembly reaches the reference's sorted-and-cut order without sorting:
it repeatedly extracts the first strict maximum, and the tie rule (equal
chances go to the lower token) is what makes the two walks provably
identical.

The image builder step that bakes the file in remains `502`'s: `generate_file`
is here, and `502` calls it when there is an image to bake it into.

## Intended behavior

A token is selected from the scores, using randomness drawn from a file carried on
the image — so that the same image with the same file produces the same machine,
exactly, until it makes randomness of its own.

## Suggested implementation steps

1. Turn scores into probabilities, then draw. The usual controls — a temperature,
   a cut-off that discards the unlikely tail — belong here and should be read from
   somewhere rather than baked in, since the machine may later want to change
   them.
2. **Seed a generator from the carried file.** The image builder puts around a
   hundred kilobytes of random numbers on the image at build time (`502`). Each
   one seeds a cheap generator that produces many thousands of draws before the
   next number from the file is taken. That stretches the file across a very long
   life while keeping the property that matters: same image, same file, same
   machine, exactly.
3. Keep the position in the file as part of what the machine knows about itself.
   Two machines from the same image, given the same inputs, walk the same
   positions and make the same choices — which makes a failure reproducible by
   handing somebody the image rather than by explaining what happened.
4. **Do not record the draws.** The earlier design had every random number written
   down so that thinking could be replayed. Carrying a seed achieves the same
   determinism for far less machinery, and the recording can be added later if
   something turns out to want it.
5. Say something when the file is exhausted and the stream wraps. Not as an
   alarm — see below — but because reaching the end of it at all is a fact worth
   knowing about a running machine.
6. Test that determinism holds: same image, same file, same input, same tokens.

## Why exhaustion is not the hazard it looks like

A drawn number is applied to a different set of probabilities every time, because
the context differs every time. So reusing the stream only reproduces earlier
choices if the same questions are being asked, and the same questions only recur
if the machine has made no progress at all — which is a problem the randomness
was never going to solve.

With a generator seeded from the file the supply is effectively unbounded in any
case. Whatever source the machine eventually builds for itself — a processor
instruction, timing jitter, noise from a device it found — is its own business
(`strategems/009`).

## Blocks

`105`, `106`.

## Blocked by

`103`, and `502` for the file.

## Related documents

The document this once pointed at described what a machine writes down against what
it can recompute instead, which is the principle behind carrying a seed rather than
a stream of numbers. It was part of the status system and went when that did.

`010a` — the loop the sampler is called from, and why nothing types at it.
