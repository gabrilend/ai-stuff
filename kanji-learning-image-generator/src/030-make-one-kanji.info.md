# 030-make-one-kanji — info

Everything one character needs, in one folder.

For a general: this is the unit of work. Give it a character and it leaves behind a folder holding the grey picture that hides the character, the stroke-order arrows, the recipe in both the shapes the picture program reads, and a plain description of every decision that went into them.

`031` runs this many times and does nothing else interesting. Everything that decides what a picture is happens here.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `030-make-one-kanji.lua` and
run the sweep again.*

## Invocation

```
luajit src/030-make-one-kanji.lua --chars 休 [--out DIR]
```

## What it offers

| | |
|---|---|
| `M.folder_for(record, out_dir)` | Where one character's work goes. |
| `M.make(record, store, settings, options)` | One character, all the way. Returns what was written, or nil and a reason. |

### `M.folder_for(record, out_dir)`

Where one character's work goes.

Named by number as well as by character, so the folders sort in a stable order and so a filesystem that dislikes the character still has a name it can keep.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `main(argv)` |  |

## Where it sits

Used by `035-test-the-machine`.
