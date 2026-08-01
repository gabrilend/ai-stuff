# A connection must name its evidence

*not everything is related to everything else, so it's better to make accurate
assumptions than fearless deductions*

## The pattern

Any system that looks for relationships will find them. That is not a defect of
one implementation, it is what looking for relationships means: given two
things and enough freedom, a relation can always be constructed. The freedom is
the problem, and the fix is not to look less hard. It is to require that every
proposed relation **carry a pointer to the thing that established it**, and to
drop the ones that cannot.

    candidate link ──► does it cite a specific record? ──► no ──► dropped
                                    │
                                   yes
                                    │
                                    ▼
                     does the cited record share a concrete
                     referent with the thing being explained?
                                    │
                        ┌───────────┴───────────┐
                       no                      yes
                        │                       │
                     dropped              a connection

The two gates are different in kind, and both are needed.

The first is about provenance: *where did this come from*. It is cheap and
mechanical and it eliminates the confident invention — a relation that names no
source is not weakly supported, it is unsupported, and arguing with it is
already a mistake.

The second is about referent: *do these actually touch*. Two records can both
be real, both be cited, and still have nothing to do with each other. What
makes them touch is sharing something concrete and checkable — the same
identifier, the same place, the same object, the same person — and that is a
lookup, not a judgement.

## Why resemblance cannot be the second gate

Similarity measures — embedding distance, shared vocabulary, matching shape —
are good at **nominating** candidates and bad at **confirming** them.

They are good at nominating because they are cheap, they scale, and they
surface things a keyword search would miss. They are bad at confirming because
resemblance is symmetric and unbounded: everything resembles everything a
little, so any threshold is a decision about how much invention to permit
rather than a test of whether the relation holds.

So: resemblance opens the door, and a shared concrete referent decides whether
anything walks through. Using similarity for both jobs is the single most
common way a retrieval system starts lying fluently.

## The refusal must be a first-class answer

If "nothing bears on this" is not in the answer set, the system will never say
it, and every question will get a relation whether or not one exists.

This is worth stating as a mechanism rather than as a preference, because it
changes the interface. The function does not return a best match — it returns
either a cited link or an explicit nothing, and the caller has to handle both.
A caller that treats an empty result as an error, or a signature that makes the
empty result awkward to express, will produce a system that fabricates under
pressure no matter what the prompt says.

## Where this shows up

| Domain | The nomination | The concrete referent that confirms it |
|---|---|---|
| narrative memory | a similar-sounding past event | the same province, person, or object appears in both |
| debugging | two failures that look alike | the same stack frame, the same input, the same commit |
| citations | a paper on the same topic | a claim that actually appears in it |
| medicine | symptoms that fit a pattern | a test result naming the mechanism |
| law | a case that reads similarly | a holding on the same point of law |

The shape is identical every time: cheap wide nomination, expensive narrow
confirmation, and an explicit empty answer that costs nothing to give.

## The cost, stated fairly

Real connections get dropped. A relation that is true but whose evidence is not
recorded anywhere fails both gates and disappears.

That is the trade, and it is the right way round for anything a person is going
to rely on. A missed connection leaves a person where they were. An invented
one moves them somewhere wrong while sounding exactly like the real thing —
and unlike the miss, it is not visible from the outside.

## Related

- `docs/datapath-the-chronicle.md` — the record this is enforced against
- `docs/datapath-the-doors.md` — the remembrancer, whose whole contract this is
- `docs/architecture.md` — the rule about connections, as it applies here
