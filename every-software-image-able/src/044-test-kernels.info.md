# 044-test-kernels — info

Runs the assembly kernels and the reference over the same numbers and compares them **bit for bit**. Not approximately. Not within a tolerance. Identical, or a failure.

The fast version written in the processor's own instructions must produce exactly the same answer as the slow readable version. Anything less than exactly is a judgement call about whether a difference is small enough, and judgement calls are what this comparison exists to remove.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `044-test-kernels.lua` and run the sweep again.*

## Invocation

```
luajit 044-test-kernels.lua [--dir ROOT]
```

## Why this can be tested without booting anything

A kernel that touches only the memory handed to it needs no operating system to run. The same bytes that will run on a bare machine can be loaded here and called directly, which turns a several-minute boot into a fraction of a second. It is the only part of the engine that gets this, and it is the part that most needs it, because it is the part that will be written three times.

## Where the line is

These two kernels are built from multiplication, addition and square root, all of which are exactly specified. Anything downstream of an exponential, a sine or a cosine cannot be compared this way, because those differ between implementations -- so those parts are checked by the fixture in 037 with a stated tolerance instead.

