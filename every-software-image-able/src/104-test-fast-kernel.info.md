# 104-test-fast-kernel — info

Holds the fast matrix product to its own readable twin, bit for bit, and measures both what it buys and what it costs.

The project has two specifications for the same operation now. The exact one adds in a fixed order and gives the same answer on every machine; the fast one keeps four totals at once and gives a slightly different answer, in exchange for the processor being able to do four additions instead of waiting between each one.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `104-test-fast-kernel.lua` and run the sweep again.*

## Invocation

```
luajit 104-test-fast-kernel.lua [--dir ROOT] [--seconds N]
```

## Worth knowing

This does three things. It requires the fast assembly to match the fast reference exactly -- the discipline does not relax just because the specification changed. It measures how far the two specifications land from each other, so the price is a number. And it times them, so the purchase is a number too.

