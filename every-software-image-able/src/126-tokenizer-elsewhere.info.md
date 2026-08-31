# 126-tokenizer-elsewhere — info

Text into the model's numbers and back, in the second and third tongues. Issue 403.

The machine is told things in text and thinks in numbers. This is the piece between. Without it an engine can think and cannot be told anything, because what it was told is text -- including the instruction it wakes up holding.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `126-tokenizer-elsewhere.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/126-tokenizer-elsewhere.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.aarch64(tokenizer)` | described below |
| `M.riscv64(p, tokenizer)` | described below |

### In more detail

**`M.aarch64(tokenizer)`**

int64_t tokenizer_encode(const TokenizerPlan *plan, const uint8_t *text,
                         int64_t text_length, int32_t *tokens_out)

plan x0, text x1, length x2, out x3. Returns how many tokens, or minus the
position of the first unsayable byte, minus one -- so minus one means the
very first byte, and zero stays an honest count for empty text.

int64_t tokenizer_decode(const TokenizerPlan *plan, const int32_t *tokens,
                         int64_t count, uint8_t *text_out)

Neither routine calls anything, so both live entirely in the registers the
convention calls scratch -- x4 through x17, of which this architecture has
enough that nothing needs saving. The first tongue has to push two.

`tokenizer` is the module that describes the prepared table (059), passed
in so there stays one description of where every slot sits.

**`M.riscv64(p, tokenizer)`**

int64_t tokenizer_encode(const TokenizerPlan *plan, const uint8_t *text,
                         int64_t text_length, int32_t *tokens_out)

plan a0, text a1, length a2, out a3. Same returns as above.

Emitted into a counted program rather than returned as text, because this
assembler leaves a relocation on a branch to a label in its own file and
there is no linker to answer it -- so every loop here would be a silent
infinite one (054).

THE RETURN VALUE COMES BACK IN a0, WHICH IS ALSO THE PLAN. That matters
more here than on the other two: the plan is read on every pass through
the rule loop, so it cannot be overwritten until the routine is finished
with it. The other two tongues have the same overlap and more registers to
hide it in.

## Why both in one file

They are one piece of work, written together rather than one and then the other. Every previous piece of assembly here was written for one architecture and ported later, and every time something went missing or drifted between them without anything saying so. Two implementations side by side check each other continuously; two written in sequence check the first one twice, and late.

## What makes this one dangerous

There is no floating point in it at all -- it walks bytes, looks pairs up in a table, and joins the best-ranked pair over and over. So it ports mechanically. But its failure mode is a WRONG ANSWER THAT LOOKS FINE: a tokenizer that joins in a slightly different order still produces numbers, and the machine then reads a subtly different instruction and never knows. Nothing faults, nothing is reported, and the machine is simply told something else.

## The order of joining is the specification

The strongest rule is tried first against every position, and a join sends the walk back to the strongest rule again, because a join can enable one that did not apply before. Trying every rule once in order would be faster and would be a different tokenizer.

## Worth knowing

That is why it is held to the same awkward corpus the first architecture is held to, rather than to a handful of easy words. The cases where tokenizers actually disagree with each other are the whole test.

## Where it sits

**Belongs to** `403`.

**Checked by** `127-test-tokenizer-elsewhere`.

