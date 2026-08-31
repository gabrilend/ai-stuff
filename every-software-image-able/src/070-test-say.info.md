# 070-test-say — info

Checks that a machine with no operating system can be heard: the font derives correctly from its pictures, and a real board draws the right pixels in the right places -- compared against what the font says they should be, pixel for pixel, rather than against "some green appeared".

The machine is switched on, told to write a sentence on the screen, photographed, and the photograph is compared with the letters the font holds. Anything less than that passes when the letters are wrong.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `070-test-say.lua` and run the sweep again.*

## Invocation

```
luajit 070-test-say.lua [--dir ROOT] [--seconds N]
```

## What it describes

| Field | Value | |
|---|---|---|
| &nbsp;&nbsp;↳ `write` | `function(text) heard.screen[#heard.screen + 1] = text ret...` |  |
| &nbsp;&nbsp;↳ `write` | `function(text) heard.wire[#heard.wire + 1] = text return ...` |  |

