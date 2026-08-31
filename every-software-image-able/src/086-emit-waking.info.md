# 086-emit-waking — info

What runs before the machine can think: find out what this processor actually is, say so, and start the engine that matches. Issue 402.

The computer is switched on and this is the first thing of ours that runs. It asks the processor what it can do, says the answer out loud on the serial port, and hands over. If it does not recognise the processor it says so and stops rather than guessing.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `086-emit-waking.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/086-emit-waking.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.LEVELS` | the vector arrangements, per architecture, worst first |
| `M.x86_64(options)` | Asks the processor what it is, says so, and reports which engine it would start. |
| `M.plan(architecture, carried)` | What this image would do on a given architecture, as data -- so the image builder (502) can lay out exactly the engines that will be looked for, an... |

### In more detail

**`M.LEVELS`**

Each level names what a hot loop may assume. The engine carries one loop
per level it supports and this picks; a build that carries only the
baseline is smaller, slower, and correct everywhere, which is a real
choice rather than a lesser one.

**`M.x86_64(options)`**

Asks the processor what it is, says so, and reports which engine it would
start. Boots as a UEFI application like everything else here.

options: engines (which levels this image actually carries)

**`M.plan(architecture, carried)`**

What this image would do on a given architecture, as data -- so the image
builder (502) can lay out exactly the engines that will be looked for, and
so a person can read the decision without booting anything.

## The firmware already picked the architecture

There is no code that runs on all three, so nothing shared can identify a processor and dispatch -- machine code is not portable and the detector would need an architecture of its own. Each firmware looks where its own convention says and finds only its own payload (029, and the boot filenames in 030 through 032). What is left for this file is the detection that IS possible: which vector extensions this particular processor turned out to have, within an architecture already chosen.

## And the engines are never tried in turn

Running code for the wrong architecture does not return garbage; it does not return. The processor decodes the bytes as instructions and does whatever they happen to mean, and there is nothing above it watching, because this project has nothing above it. Trying in turn needs a supervisor, and the supervisor would need an architecture of its own.

## Say it before handing over

"Found this processor, starting this engine" is the single most useful sentence a failing machine can produce, and at this moment it is the only thing that can be said at all.

## Where it sits

**Belongs to** `402`.

**Checked by** `087-test-waking`.

