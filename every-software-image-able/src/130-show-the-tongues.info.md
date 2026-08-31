# 130-show-the-tongues — info

What three engines written by hand for three processors actually agree about. The phase 4 demo's numbers.

This project has no compiler. The arithmetic that runs a model was written three times, once per family of processor, by people. The claim phase 4 makes is not that all three work -- it is that all three produce THE SAME NUMBERS, to the last bit, and a paragraph saying so proves nothing.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `130-show-the-tongues.lua` and run the sweep again.*

## Invocation

```
luajit 130-show-the-tongues.lua [--dir ROOT]
```

## What it describes

| Field | Value | |
|---|---|---|
| &nbsp;&nbsp;↳ `machines` | `"ARM, RISC-V", count = "279 matrix values, 133 normalisat...` |  |
| &nbsp;&nbsp;↳ `against` | `"the first architecture" }` |  |
| &nbsp;&nbsp;↳ `machines` | `"all three", count = "5 rows over 3 blocks each"` |  |
| &nbsp;&nbsp;↳ `against` | `"the readable specification (123)" }` |  |
| &nbsp;&nbsp;↳ `machines` | `"ARM, RISC-V", count = "192 scores, over four tokens"` |  |
| &nbsp;&nbsp;↳ `against` | `"the first architecture" }` |  |
| &nbsp;&nbsp;↳ `machines` | `"ARM, RISC-V", count = "192 scores moved"` |  |
| &nbsp;&nbsp;↳ `against` | `"itself, and required to differ" }` |  |
| &nbsp;&nbsp;↳ `machines` | `"ARM, RISC-V", count = "620 draws across 6 settings"` |  |
| &nbsp;&nbsp;↳ `against` | `"the first architecture" }` |  |
| &nbsp;&nbsp;↳ `machines` | `"ARM, RISC-V", count = "11 awkward cases, both directions"` |  |
| &nbsp;&nbsp;↳ `against` | `"the first architecture" }` |  |
| &nbsp;&nbsp;↳ `machines` | `"ARM, RISC-V", count = "5 lines, in order"` |  |
| &nbsp;&nbsp;↳ `against` | `"what it was handed" }` |  |
| &nbsp;&nbsp;↳ `detail` | `"six on the first, ten on the second, twelve on the third...` |  |
| &nbsp;&nbsp;↳ `detail` | `"the first architecture's firmware wants its arguments in "` |  |
| &nbsp;&nbsp;↳ `detail` | `"present on the first two. ABSENT on the processor the th...` |  |
| &nbsp;&nbsp;↳ `detail` | `"an instruction on the second, an optional extension on t...` |  |
| &nbsp;&nbsp;↳ `detail` | `"the third architecture's assembler leaves a note for a l...` |  |
| &nbsp;&nbsp;↳ `detail` | `"the first architecture has a separate address space for ...` |  |

## Why bit for bit and not closely

A comparison that admits "close enough" turns every future disagreement into an argument. Three implementations held to identical answers can be checked by a machine; three held to similar answers can only be checked by a person with an opinion about how similar is similar enough.

## What this deliberately does not do

run the comparisons. It reads what they recorded. A demo that re-ran everything would take a quarter of an hour of booting emulated computers, and the point of the demo is to show the shape of the claim rather than to be the test -- `run-tests` is the test, and it is what produced these.

## Worth knowing

So this counts. Every comparison every architecture has been put through, gathered in one place with the count beside it, and every one of those numbers was produced by booting a real emulated machine of that kind and asking it.

