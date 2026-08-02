# 027-test-blob — info

Packs a model, reads it back, and compares every tensor byte for byte. Also
checks that the reader refuses what it must refuse.

## Invocation

```
luajit src/027-test-blob.lua [--dir ROOT]
```

Exit status zero only when every check comes out as expected.

## What it checks

**The round trip.** A description with one tensor per precision the format
defines, so none goes untested. Bytes are generated from a seed rather than
stored, so the expected contents stay recomputable and a mismatch means
something. The comparison walks the tensor table the way the engine will have
to, rather than trusting the packer's own idea of where things went — if those
two ever disagree, this is the only thing that would notice.

**Alignment.** Every tensor starts on a 32-byte boundary. Not decoration: a
vectorised inner loop that must begin with an unaligned step pays for it on
every row.

**The refusals.** A truncated blob, a version the reader does not know, and
something that is not a blob at all. These matter as much as the round trip —
a reader that accepts a broken blob does not fail, it hands the arithmetic
somebody else's numbers and the machine thinks badly forever.

**Determinism.** The same description packs to the same bytes. Reproducibility
is a build-time property and it starts here.

## The vocabulary it tests with

Deliberately awkward: a space, a newline, a multi-byte character, single
letters. Tokenizers differ from each other exactly at those cases, and a
subtly wrong one produces a model that seems mildly stupid rather than one
that visibly fails — which is the worst failure available, because nobody
suspects the right thing.

## Result on 2026-08-02

Ten of ten as expected.
