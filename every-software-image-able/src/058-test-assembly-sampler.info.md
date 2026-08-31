# 058-test-assembly-sampler — info

Runs the readable sampler (040) and the assembly sampler (057) side by side, on the same scores with the same carried numbers, and requires them to agree choice for choice and bit for bit.

Choosing a word is the one place where a tiny arithmetic difference does not stay tiny -- a flipped choice joins the conversation and everything after it differs. So the two implementations are not compared "closely"; they are compared exactly, over thousands of draws, across every setting the sampler has.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `058-test-assembly-sampler.lua` and run the sweep again.*

## Invocation

```
luajit 058-test-assembly-sampler.lua [--dir ROOT]
```

