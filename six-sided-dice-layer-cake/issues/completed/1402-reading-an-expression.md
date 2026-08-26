# 1402 — Reading an expression

Produces `src/092-expression.lua`.

## Current behavior

**Done.** `src/092-expression.lua` exists. Tokeniser, recursive-descent parser,
symbol collection and evaluation, kept as separate passes so the ledger can
learn the shape of the dependency graph before any value exists.

Fourteen functions and the constant pi, held in two dispatch tables -- arity and
behaviour -- so that adding one is two lines and no branch.

The rule that every literal is dimensionless is enforced by construction: a
number becomes a dimensionless quantity and `091`'s arithmetic then refuses
anything that needed it to be otherwise.

`parse_relation` splits a constraint on its comparison operator, refuses a
relation with none and one with two, and keeps both sides' original text so the
checker can print the relation as its author wrote it.

## Intended behavior

**A tokeniser, a parser and an evaluator for the derivation expressions in
`symbols` blocks and the relations in `constraints` blocks.**

### The grammar

Infix with the usual precedence: addition and subtraction, then multiplication and
division, then exponentiation, then unary minus, with parentheses. Function calls
over `sqrt abs min max log ln exp floor ceil round sin cos tan atan`. The constant
`pi`. Identifiers, which are symbol references. Decimal numbers with an optional
exponent.

Small enough for recursive descent, and the file should say so rather than
reaching for a parser generator.

### The rule that makes the notation worth having

**Every literal number is dimensionless.** No exception, no unit suffix, no
special case. If a derivation needs twenty kelvin, twenty kelvin is a declared
symbol somewhere.

The evaluator enforces this by construction: a number literal becomes a quantity
with the empty dimension, and `091`'s arithmetic then refuses anything that would
have needed it to be otherwise. The error message must be good, because this is
the mistake every author of a blueprint will make on their first day, and a
message that says *literals are dimensionless; declare this quantity as a symbol*
teaches the rule in one sitting.

### Two evaluation modes

**Symbol collection**, which walks the parse tree and returns the identifiers it
references without evaluating anything. `094` needs this to build the dependency
graph before any value exists.

**Evaluation**, given a table of resolved quantities.

Keeping them separate matters: the ledger must know what an expression depends on
before it can know what it evaluates to, and a design that only offers evaluation
forces a guess at the ordering.

### Errors

Every failure names the blueprint, the symbol and the character position.
`002` promises that the checker says how far off a constraint is; that promise
starts here, with errors that locate themselves.

## What the file must offer

Tokenise. Parse to a tree. Collect referenced identifiers from a tree. Evaluate a
tree against a symbol table. Parse a relation into a left side, an operator and a
right side.

## Tests

- Precedence and associativity, including exponentiation.
- Unary minus in every position it can legally appear.
- Every function, including the two-argument ones.
- An undefined identifier raises with a position.
- A literal added to a dimensional symbol raises with the teaching message.
- Symbol collection finds every identifier and no function name.
- A relation parses into three parts and rejects a missing operator.

## Blocks

`1403`, `1404`, `1405`.

## Blocked by

`1401`.

## Related documents

`002` for the grammar.
