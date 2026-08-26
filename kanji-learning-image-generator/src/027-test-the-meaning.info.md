# 027-test-the-meaning — info

Everything phase two claims, checked.

For a general: phase two decides what a picture is *of*. It measures each stroke, works out what world the character belongs to, which of its pieces are subjects and which are only sounds, and builds the grey image that carries the illusion.

Almost none of that can be tested against the thing it is for. The specification is that a person squints at a thumbnail and sees the character, and no assertion here observes that. So these tests check that the machinery did what it was told, and the demonstration in phase two exists to let somebody check whether what it was told was right.

The assertion helpers come from `020`, which owns them.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `027-test-the-meaning.lua` and
run the sweep again.*

## Invocation

```
luajit src/027-test-the-meaning.lua [--dir ROOT]
```

## What it offers

| | |
|---|---|
| `M.run(options)` |  |

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `test_measuring_a_stroke(t)` | Characters whose answers are known by looking at them. |
| `test_the_structure_field(t)` |  |
| `test_the_component_lexicon(t)` |  |
| `test_the_scene_grammar(t)` | The reasoning, not the wording. |
| `test_the_words(t)` |  |
| `test_the_arrows(t)` |  |
| `test_the_two_readings(t)` | The picture can be about the meaning, or it can be a hook the meaning hangs |
| `test_a_phrase(t)` | A word is what a learner is actually trying to hold. 時 and 間 separately are |
| `main(argv)` |  |
