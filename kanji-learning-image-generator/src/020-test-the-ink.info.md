# 020-test-the-ink — info

Everything phase one claims, checked.

For a general: phase one turns two archives into geometry and pixels and has no idea what a kanji means. This checks that half of the machine on its own terms -- that the tag reader survives what these documents actually contain, that every stroke in the archive parses, that curves become lines that land where they should, that the drawing surface behaves like ink on paper, and that a picture written to disk can be read back and is the same picture.

It also carries the handful of assertion helpers the other test files borrow. The first test file owns them because a separate file holding twenty lines of helpers is a file nobody opens and everybody duplicates.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `020-test-the-ink.lua` and
run the sweep again.*

## Invocation

```
luajit src/020-test-the-ink.lua [--dir ROOT] [--quick]
```

## What it offers

| | |
|---|---|
| `M.harness()` | A fresh set of counters and the four ways of asserting into them. |
| `M.run(options)` | Every test in this file. Returns true if they all passed. |

### `M.harness()`

A fresh set of counters and the four ways of asserting into them.

Returned rather than global so two harnesses can run in one process without adding each other's failures up, which is what `run-tests` does.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `self.ok(condition, description, detail)` |  |
| `self.same(actual, expected, description)` |  |
| `self.near(actual, expected, slack, description)` | For anything computed in floating point, where exact equality is a |
| `self.note(text)` | A measurement worth printing that is not a pass or a failure. |
| `self.finish(title)` |  |
| `test_the_tag_reader(t)` |  |
| `test_the_path_language(t)` |  |
| `test_flattening(t)` |  |
| `test_every_stroke_in_the_archive(t, quick)` | The test the whole of phase one exists for. |
| `test_the_store(t)` |  |
| `test_the_canvas(t)` |  |
| `inflate_fixed(text)` | Enough of a decompressor to check the compressor, and no more. |
| `test_writing_a_picture(t)` |  |
| `test_the_numbers(t)` |  |
| `main(argv)` |  |

## Where it sits

Used by `027-test-the-meaning`, `035-test-the-machine`.
