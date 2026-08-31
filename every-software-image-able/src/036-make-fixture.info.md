# 036-make-fixture — info

Packs a small model, runs a forward pass over it, and writes down exactly what came out. That written-down answer is the fixture: the thing every assembly implementation is measured against, on every architecture, forever.

This produces a known question and its known answer. Any faster or more obscure version of the arithmetic is correct exactly when it reproduces this answer, and no other test is needed to say so.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `036-make-fixture.lua` and run the sweep again.*

## Invocation

```
luajit 036-make-fixture.lua [--dir ROOT] [--tokens N]
```

## Why the weights are random

A fixture does not need a model that says anything sensible -- it needs one that is the same every time. Weights drawn from a fixed seed are meaningless and perfectly reproducible, which is all that is being asked of them. Real meaning arrives with a real model, and nothing about this test changes when it does.

## Where it sits

**Checked by** `037-test-forward`, `050-test-assembly-forward`, `062-test-thinking-loop`, `065-test-the-hands`, `110-test-forward-aarch64`, `116-test-forward-riscv64`, `132-test-find-tensors`, `134-test-lay-out`, `136-test-fill-the-plan`, `138-test-prepare-the-tokenizer`, `140-test-the-driver`, `142-test-a-bootable-medium`.

