# 048-test-exp — info

Measures both polynomials for the exponential across the range a model actually produces, and says which one the specification should use.

There are two candidate ways of computing this, one shorter and one longer. Rather than argue about which is better, both are run over the numbers a model really generates and the worse-case error of each is reported. The specification then follows the measurement.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `048-test-exp.lua` and run the sweep again.*

## Invocation

```
luajit 048-test-exp.lua [--dir ROOT]
```

