# 124-test-quantised — info

The small stored form, checked against what it claims about itself. Issue 108.

Weights at four bits each instead of thirty-two. This checks that the packing and the unpacking are inverses of each other, that the error is where the arithmetic says it should be, and that the bytes laid down are the bytes the format describes -- because a size and a format are different things, and two programs can agree exactly on how many bytes a tensor takes while disagreeing completely about what they mean.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `124-test-quantised.lua` and run the sweep again.*

## Invocation

```
luajit 124-test-quantised.lua [--dir ROOT]
```

## What it describes

| Field | Value | |
|---|---|---|
| &nbsp;&nbsp;↳ `build` | `function(index) return index % 2 == 0 and 3.5 or -3.5 end }` |  |
| &nbsp;&nbsp;↳ `build` | `function(index) return index == 0 and 100 or 0.001 end }` |  |

## What this deliberately does not check

that the quantised product agrees with the plain one. It does not and must not. Quantising loses information; the answer is different and is meant to be. What is checked is that the loss is bounded by what the form's own arithmetic predicts.

## Where it sits

**Belongs to** `108`.

