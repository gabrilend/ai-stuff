# 024a-the-paintbrush — info

The closed set of things a person may say about a picture, and the wall that refuses everything else.

For a general: when a picture comes out wrong there has to be something to do about it other than changing the rules that produced it, because changing the rules changes every other character too. This is that something. A person writes a better argument for one character and it wins.

    -- input/arguments/時.lua     return {       world = "sky",       subjects = {         { "日", "the sun, low and huge" },         { "寺", "a temple with a bronze bell" },       },       note = "sun over temple. the temple is only there for the sound.",     }

WHY THE VOCABULARY IS CLOSED. Given a long document describing everything a scene can hold, anybody writing quickly will reach for a neighbouring word that does not exist -- confidently, and in good style. A short allowlist has nowhere for the analogy to go. The refusing is the feature.

The language is the parser: an argument is Lua returning a table, so a syntax error arrives with a line number for free and there is no parser here to be wrong. This checks vocabulary, not syntax.

Numbered to sit beside `024`, whose work it overrides.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `024a-the-paintbrush.lua` and
run the sweep again.*

## Invocation

```
luajit src/024a-the-paintbrush.lua --check 時
```

## What it offers

| | |
|---|---|
| `M.contract()` | The vocabulary, as a document. |
| `M.check(argument, record, store)` | Every complaint the wall has, at once. |
| `M.path_for(character)` |  |
| `M.load_for(record, store)` | The argument somebody has written for this character, checked. |
| `M.apply(scene, argument)` | A scene, with a person's argument laid over it. |
| `M.scene(record, store, settings, options)` | The scene for a character, argued with if somebody has argued with it. |

### `M.contract()`

The vocabulary, as a document.

Generated from the table above rather than written beside it, because a contract with two homes is a contract that will disagree with itself. The documentation site renders this; there is no file to go stale.

### `M.check(argument, record, store)`

Every complaint the wall has, at once.

Returns a list. Empty means the argument is legal. Nothing is thrown, because the caller wants all of them together and an error would deliver one.

### `M.load_for(record, store)`

The argument somebody has written for this character, checked.

Returns the argument and its path, or nil when there is none. Errors, with every complaint at once, when there is one and it is wrong -- because an argument that was written and then silently ignored is worse than no argument at all: the picture does not change and nothing says why.

### `M.apply(scene, argument)`

A scene, with a person's argument laid over it.

Only what the argument actually says is changed. Everything else stays as the grammar worked it out, which is what makes overriding one thing a small act rather than an obligation to describe the whole picture.

### `M.scene(record, store, settings, options)`

The scene for a character, argued with if somebody has argued with it.

Everything that wants a scene should come through here rather than through `024` directly, or an argument would be written and quietly ignored.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `distance(a, b)` | How many single-character edits turn one word into the other. |
| `nearest(word, legal)` | The legal word this one was probably meant to be, or nil. |
| `main(argv)` |  |

## Where it sits

Used by `025-the-words-the-machine-reads`, `033-the-documentation-site`, `035-test-the-machine`.
