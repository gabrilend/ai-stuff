# 138-test-prepare-the-tokenizer — info

The tokenizer's prepared table, built by the machine itself, held to the one the host builds. Issue 107a.

On a development machine a page of ordinary code turns the model's carried word-lists into the lookup tables the engine uses. On a bare machine that page has to be assembly. This runs both against the same model and requires the four tables to come out identical, byte for byte -- and then encodes and decodes text through the machine-built one, because two tables that differ in a slot nothing reads are not a defect and two that differ in a slot something reads are.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `138-test-prepare-the-tokenizer.lua` and run the sweep again.*

## Invocation

```
luajit 138-test-prepare-the-tokenizer.lua [--dir ROOT]
```

## What it describes

| Field | Value | |
|---|---|---|
| &nbsp;&nbsp;↳ `text` | `string.char(1, 2, 3, 4, 5, 1, 2) }` |  |

## Why both kinds of check

Comparing the tables says WHICH slot is wrong. Encoding through them says whether the thing works at all. A setup routine wants both, for the reason `136` gives: one answers "does it work" and the other answers "what is broken".

## Where it sits

**Belongs to** `107a`.

