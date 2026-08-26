# 087 — Every seam checked in one place

```meta
phase  | 13
issues | 1301
```

## Why this is the capstone rather than a summary

Each blueprint checks itself. `095` checks every constraint that has been written.
**Neither notices a constraint that was never written**, and the gaps are always
at the seams — between the phase that produces a number and the phase that
consumes it, where each assumes the other is handling it.

So this is a register of seams, and its output is the list of ones that are
unguarded.

## The seams, and what crosses them

```drawing
the chain that sizes the object [not-dimensioned]

   the model's layer size ──▶ the slice ──▶ the die ──▶ the face ──▶ the cube
        078                     047          041         042          012

   the chain that heats it

   engine power ──▶ power map ──▶ hot spot ──▶ junction ──▶ margin
        045            041          025          025         027 and 074

   the chain that feeds it

   the tiers ──▶ the crossbar ──▶ the link ──▶ the slice ──▶ the engine
      034            037            051         047           045
```

## The three triple checks

Three quantities are derived by three independent routes and required to agree.
They are the most valuable constraints in the set, because each catches an error
no single blueprint could see:

- **the crossover batch**, from `045`, `053` and `079`
- **time per token**, from `053`, `055` and `061`, with `080` bounding the
  overhead on top of it
- **the core's edge length**, from the cube inward (`012`) and from the tier stack
  outward (`036`)

## The gap this blueprint cannot close

The notation holds numbers and not lists. So a seam register can count seams and
count constraints, and **cannot verify that a given seam has a constraint on it.**
Four places in the project already have that weakness — `072`'s interaction sites,
`077`'s operation list, `080`'s counters, and this.

It is stated plainly rather than papered over, and it is the single strongest
argument for the notation growing the ability to hold a named set.

## Symbols

```symbols
n_seam        | 1 | given | 44       | places where a number produced in one phase is consumed in another
n_seam_guarded | 1 | given | 44      | of those, how many have a constraint asserting the agreement
n_triple      | 1 | given | 3        | quantities derived by three independent routes
n_alarm       | 1 | given | 8        | constraints asserted in the direction of alarm: always true, written so a reader meets a number rather than a claim
n_count_only  | 1 | given | 5        | places a constraint counts where it should name, because the notation holds numbers and not lists

n_seam_open   | 1 | derived | n_seam - n_seam_guarded   | seams with no constraint on them, which is what finishing this project means driving to zero
f_guarded     | 1 | derived | n_seam_guarded / n_seam   | the share that are guarded
n_bp          | 1 | solved | 84                         | blueprints in the set -- from 103, which loads them rather than counting them from memory
n_constraint  | 1 | solved | 552                        | constraints in it -- from 103. Carried as a hand count until it was twelve short, which is the exact failure a self-describing document is prone to
c_per_bp      | 1 | derived | n_constraint / n_bp        | constraints per blueprint, which is a crude measure of whether any file is asserting nothing
```

## Constraints

```constraints
C-087-1 | n_seam_open == 0             | every seam must have a constraint on it. The capstone constraint, and the one that took longest to reach zero
C-087-2 | n_triple >= 3                | at least three quantities must be derived three ways. Each of the three catches a class of error no single blueprint could see, and they are the most valuable lines in the set
C-087-3 | f_guarded ~= 1               | the same statement as a fraction, which is what a reader looks at
C-087-4 | c_per_bp > 5                 | a blueprint must assert more than a handful of things on average, or the set is publishing numbers nobody checked
C-087-5 | n_count_only <= 5          | at most five places may count where they should name. Asserted as a ceiling rather than a floor: it is a known weakness of the notation and it must not grow. It was four and this blueprint made it five, which is the sort of thing a ceiling exists to make visible
C-087-6 | n_alarm >= 3                 | at least three constraints must be asserted in the direction of alarm, because a number a reader meets is worth more than a claim they are asked to accept
```

## What is still open

**`n_seam` is a count somebody made by hand**, from the blocks-and-blocked-by
graph in the tickets. It is the number this blueprint most wants to derive and
cannot, and if it is wrong then `C-087-1` is checking a number against itself.

**Four places count where they should name**, and `C-087-5` holds the line rather
than fixing it. Fixing it means the notation growing a named set, which is a
change to `092` and `095` and is the largest single improvement available to the
instruments.
