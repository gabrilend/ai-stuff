# 017 — The seals

```meta
phase  | 2
issues | 205
```

Every joint that separates coolant from something that must stay dry, with a
pressure, a compression range, a material and a leak rate.

This is the honest answer to *what kills this machine*. Water at two bar, a
hundred and fifty microns from live silicon at three quarters of a volt. One drop
in the wrong place and the cube is not damaged, it is scrap, because nothing
inside it can be reached.

## The joints, counted

| joint | count | what it separates |
|---|---|---|
| face plate to edge rail | 24 | the plenum from the outside |
| edge rail to corner block | 24 | rail to chamber |
| supply chamber to return chamber | 8 | the two networks from each other |
| via island rings (`014`) | 96 | water from conductors |
| cold plate cover bond | 6 | channels from the die stack |
| external fitting to corner block | 8 | the loop from the room |

**A hundred and sixty-six.** Ninety-six of them exist because `014` chose to
cross the cold plate rather than route around it, and that decision should be
read next to this number rather than on its own.

## The two regimes

**Permanent bonds** — the cold plate cover, the via island rings. Made once at
wafer scale, never serviced, measured as a helium rate at proof pressure rather
than by whether they drip.

**Compression seals** — face plates, rails, fittings. Made at assembly, in
principle remakeable. An elastomer cord in a groove, and the range of squeeze it
tolerates is what `013`'s tolerance stack has to fit inside.

That coupling is the hard part of the phase: a seal wants a lot of compression
and a loop of six plates wants to give it very little.

## The number that matters more than pressure

**A hundred thousand thermal cycles**, from `086`. Pressure is undemanding here —
two bar is nothing. What ages an elastomer is being squeezed and heated and
released a hundred thousand times, which is compression set, and it is the term
that decides whether these joints last.

## Symbols

```symbols
p_work        | bar | given | 2.0   | working pressure of the coolant loop, pump head plus static
mult_proof    | 1   | given | 3.0   | proof pressure as a multiple of working; an ordinary figure, held as a symbol so the whole set can be raised at once
mult_burst    | 1   | given | 5.0   | burst pressure as the same
d_cord        | mm  | given | 2.50  | diameter of the elastomer cord in a compression groove. One millimetre was tried first and fell fifteen microns short of the tolerance loop; the bow that 018 then found pushed the flatness allowance from fifteen microns to fifty and the cord with it
squeeze_min   | 1   | given | 0.15  | least fractional squeeze at which the cord seals
squeeze_max   | 1   | given | 0.30  | most it tolerates before compression set over the cycle count is unacceptable
leak_per_seal | mbar*L/s | measured | 1e-9 | helium leak rate per joint at proof pressure for a good elastomer seal in a groove. A leak rate quoted this way is a pressure-volume throughput and therefore has the dimensions of power, which is worth knowing before dividing it by anything
comp_set      | 1   | measured | 0.20 | fraction of its squeeze an elastomer of this class loses permanently over a hundred thousand cycles at temperature
w_seal_min    | mm  | given | 1.20  | least width of face plate rim a groove and its land need

n_seal_plate  | 1   | derived | 4 * n_face                    | face-plate-to-rail joints
n_seal_rail   | 1   | derived | 2 * n_edge                    | rail-to-corner joints
n_seal_cover  | 1   | derived | n_face                        | cold plate cover bonds
n_seal_fitting| 1   | derived | n_corner                      | external fittings
n_seal_total  | 1   | derived | n_seal_plate + n_seal_rail + n_corner + n_island_seal + n_seal_cover + n_seal_fitting | every joint in the machine that keeps coolant on one side of itself
p_proof       | Pa  | derived | p_work * mult_proof           | pressure every wall and every seal must hold without leaking
p_burst       | Pa  | derived | p_work * mult_burst           | pressure at which a wall is permitted to fail
seal_compression_range | mm | derived | d_cord * (squeeze_max - squeeze_min) | the band of gap variation a groove can take up while still sealing
seal_end_of_life       | mm | derived | d_cord * squeeze_min / (1 - comp_set) | squeeze that must be present when new, so that after a hundred thousand cycles of set there is still enough left to seal
leak_total    | mbar*L/s | derived | n_seal_total * leak_per_seal | throughput of every joint in the machine added together
Q_leak_seal   | m^3/s | derived | leak_per_seal / p_work        | volumetric loss at one joint at working pressure; a throughput divided by the pressure driving it is a volume flow
Q_leak_total  | m^3/s | derived | n_seal_total * Q_leak_seal    | and for all hundred and sixty-six of them
L_seal_line   | mm  | derived | n_seal_plate * L_plate        | length of compression seal line around the face plates alone
```

## Constraints

```constraints
C-017-1 | seal_compression_range >= tol_loop | the squeeze band must take up the tolerance accumulated around a loop of four face plates in 013. This is the constraint the phase turns on and it is expected to fail on the first attempt
C-017-2 | seal_end_of_life * (1 + comp_set) <= d_cord * squeeze_max | the squeeze needed when new, allowing for the set the elastomer will take, must still be inside what it tolerates. A seal fitted tight enough to survive its own ageing must not be so tight that the ageing is what kills it
C-017-3 | w_seal >= w_seal_min          | the rim left around the die block by 012 must be wide enough for a groove and its land
C-017-4 | p_burst > p_proof             | burst above proof, which is trivially true and worth asserting because the two multipliers are separate symbols and somebody will edit one
C-017-5 | Q_leak_total < Q_leak_max     | the sum of a hundred and sixty-six joints' permitted loss must stay under what the reservoir in 027 can give up between services without the level sensor tripping
C-017-6 | n_seal_total > 150            | a floor asserted deliberately in the direction of alarm: this design has more than a hundred and fifty places for water to get out, and a version of it that appeared to have forty would mean somebody had stopped counting the via island rings
```

## What is still open

**`C-017-1` failed twice before it held**, and the sequence is worth keeping
because it is what the notation is for. A one millimetre cord takes up a hundred
and fifty microns of gap variation; four face plates at twenty-five microns of
edge tolerance and fifteen of flatness accumulate a hundred and sixty. Fifteen
microns short.

Then `018` found that a face assembly bows forty-five microns when it is hot, so
fifteen microns of flatness was never a real figure — it is what the process
achieves at one temperature, and the machine runs at another. Flatness went to
fifty, the loop went to three hundred, and the cord went to two and a half
millimetres to cover it. That cost seventy microns of plenum height in `014`.

None of those three numbers could have been chosen first. Each was forced by the
one after it.

**Nothing has established the elastomer.** `comp_set` at twenty per cent over a
hundred thousand cycles is a plausible figure for a good fluorocarbon elastomer
and is entered as `measured` with no source. It multiplies the whole seal life
and it should have a datasheet behind it.

**The nine-seal corner geometry does not exist.** `015` names it and does not
draw it, and it is the hardest sealing shape in the machine.
