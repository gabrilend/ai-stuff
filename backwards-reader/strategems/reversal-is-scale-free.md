# strategem — reversal is scale-free

A pattern that showed up here and is not about text.

## The shape

The vision asks for three different things and they turn out to be one
thing at three sizes:

    reverse the order of the lines
    reverse the order of the sentences
    reverse the *meaning* of a sentence

Each is: *take a whole, find its seams, turn the pieces around, put it
back*. What changes between them is only what counts as a piece and what
"turned around" means for a piece that size. At the top the pieces are
lines and turning means reordering. At the bottom the pieces are ideas and
turning means negation. In between, both are happening at once — the worked
example in the vision swaps the two clauses of a sentence *and* inverts
each, in the same move.

So the operation is one operation with a scale parameter. Which means it is
a **ladder**, and the code is a descent, and the interesting question is not
"how do I reverse text" but "where does the ladder stop".

## Why this is worth keeping

Whenever an ask arrives as three related features, check whether it is one
feature at three magnifications. The tell is that the features are
described in the same grammar. Here: reverse the lines / reverse the
sentences / reverse the meaning — same verb, shrinking noun. That
repetition is the pattern announcing itself.

If it is one feature, then:

- the code is a table of rungs, not three subsystems
- adding a scale is adding a row, not adding a module
- the recursion is the product, and its termination is the design problem
- every rung gets the same tests, driven by the table

If it is not one feature, you find out cheaply, because a rung that does
not fit the row shape refuses to be written.

## The related trap

Having found the ladder, the temptation is to make it infinite, because it
so obviously wants to be. Word, syllable, phoneme, letter, bit. The vision
already noticed and named the failure: `[stack overflow]`. A scale-free
pattern needs a floor supplied from outside itself, because it will not
find one on its own. Supply the floor explicitly and loudly, or the elegance
eats the program.

## Where else this has been seen

- Directory trees: a folder and a file are one thing at two scales, which
  is why `find` is four lines and a walk.
- Load balancing across doors, then across cores inside a door, then across
  batches inside a core. Same dispatch question, three magnifications; the
  crossover measurement is the same measurement each time.
