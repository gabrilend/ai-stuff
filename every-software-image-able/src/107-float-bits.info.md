# 107-float-bits — info

Turning a number into the exact bits a processor holds it as, and back. One implementation, because the obvious way to write it is wrong in a way that does not show up until it matters.

Assembly cannot say "one seven-hundred-and-twentieth". A constant has to arrive as the exact pattern of bits a single-precision number is made of, so something has to convert. This is that something.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `107-float-bits.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/107-float-bits.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.of(value)` | The bits of `value` held as a single-precision number, as a plain Lua number so it can be formatted, compared and written out without further conve... |
| `M.hex(value)` | The same, spelled the way an assembler wants to read it. |
| `M.from(bits)` | The other direction: what number a pattern of bits means. |
| `M.round(value)` | One value, rounded the way the machine rounds it, and handed back as an ordinary number. |
| `M.self_check()` | Proves the conversion still works after the loop it is in has gone hot. |

### In more detail

**`M.of(value)`**

The bits of `value` held as a single-precision number, as a plain Lua
number so it can be formatted, compared and written out without further
conversion.

**`M.hex(value)`**

The same, spelled the way an assembler wants to read it. Provided here
rather than left to each caller, because every caller was writing the same
format string and one of them writing it differently is a difference
nobody would notice.

**`M.from(bits)`**

The other direction: what number a pattern of bits means. Used when
reading back what a machine reported, where the value arrives as an
integer and has to become a number again.

**`M.round(value)`**

One value, rounded the way the machine rounds it, and handed back as an
ordinary number.

SAFE WHERE THE OTHER WAS NOT, and it is worth knowing why: this writes and
reads the SAME field, so there is no second view for the compiler to
mistake for something unrelated. The rounding idiom scattered through the
reference implementations is this shape and was never at risk.

**`M.self_check()`**

Proves the conversion still works after the loop it is in has gone hot.

Called by the tests rather than trusted, because the failure this file
exists to prevent CANNOT be caught by a small check -- the broken version
passes the first few dozen calls perfectly. Only a hot loop reveals it, so
the check is a hot loop.

## The obvious way is broken, and silently

Writing a number into a float-shaped box and reading it back through a pointer of a different shape is the standard trick for this, and it works perfectly -- for the first few dozen calls. Then the loop it sits in gets hot, the compiler traces it, and the read through the second pointer is treated as though it could not have changed, because nothing tells the compiler the two pointers touch the same memory. From then on every call returns the same answer.

## What it cost

A payload was built carrying two hundred and fifty-six numbers of test data, of which three were distinct. The machine that ran it computed the right answer over the wrong numbers, disagreed with the first architecture by eighty-nine percent, and was very nearly recorded as a broken port. It was the tool that was broken.

## Why a union fixes it

A union is one object with two ways of being read, so the compiler knows the two views are the same storage and cannot treat either as unchanged while the other is written. The aliased-pointer version hides that relationship, which is exactly what makes it fast and exactly what makes it wrong.

## The shape of this defect

is the project's oldest one wearing new clothes: no error, no crash, a plausible answer. The first few values were right, which is worse than all of them being wrong -- a spot check passes.

## Worth knowing

MEASURED: two thousand different numbers through the aliased version give sixty-eight distinct results. Through the union below, two thousand.

## Where it sits

**Checked by** `100-test-kernels-aarch64`, `110-test-forward-aarch64`, `113-test-kernels-riscv64`, `116-test-forward-riscv64`, `119-test-sampler-aarch64`, `122-test-sampler-riscv64`, `125-test-quantised-kernels`, `136-test-fill-the-plan`, `140-test-the-driver`.

