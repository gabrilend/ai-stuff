# 039-test-tokenizer — info

Checks the tokenizer, mostly on the cases where implementations differ from one another. That is deliberate: a tokenizer that is right about ordinary English and wrong about a newline produces a model that seems mildly stupid rather than one that visibly fails, and nobody suspects the right thing.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `039-test-tokenizer.lua` and run the sweep again.*

## Invocation

```
luajit 039-test-tokenizer.lua [--dir ROOT]
```

