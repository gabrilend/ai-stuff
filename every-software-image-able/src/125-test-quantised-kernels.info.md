# 125-test-quantised-kernels — info

The quantised matrix product, on all three architectures, held to the readable specification bit for bit. Issue 108.

Weights stored at four bits each have to be unpacked before they can be multiplied, and that unpacking happens in the innermost loop of the machine. This checks that all three processors unpack them identically and get identical answers -- not close answers.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `125-test-quantised-kernels.lua` and run the sweep again.*

## Invocation

```
luajit 125-test-quantised-kernels.lua [--dir ROOT] [--seconds N]
```

## What it describes

| Field | Value | |
|---|---|---|
| `specification` | `specification, float_bits = float_bits` |  |

## One test, three machines, on purpose

Every other piece of assembly in this project was written for one architecture and ported later, and every time that happened something went missing or drifted between them (`403` lists what). This routine was written for all three in one sitting and is checked in one place, so there is no interval during which two of them are different and nothing says so.

## What it is held to

Not the plain product -- that answer is different on purpose, because quantising loses information. It is held to `123`, the readable specification of this form, which is where the order of operations is decided.

## Where it sits

**Belongs to** `108`.

