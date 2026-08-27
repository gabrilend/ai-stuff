# 044-run-the-pictures — info

Hands a recipe to a running ComfyUI and puts what comes back into the pool.

For a general: this is the only part of this project that talks to another program. Everything up to here decided what a picture should be; this asks for it and files the answer. It is an HTTP client and nothing else, and it must not become anything else -- every decision about *what* to render was made before it ran.

It also finds out whatever this project has been wrong about since the third phase, all at once, because a workflow this project calls correct has never been opened by the program it was written for.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `044-run-the-pictures.lua` and
run the sweep again.*

## Invocation

```
luajit src/044-run-the-pictures.lua --chars 木火水
luajit src/044-run-the-pictures.lua --grade 1 --limit 20
luajit src/044-run-the-pictures.lua --phrases
luajit src/044-run-the-pictures.lua --chars 時語 --style wimmelbild
luajit src/044-run-the-pictures.lua --chars 木 --resolution 1536
```

## What it offers

| | |
|---|---|
| `M.card()` | What the graphics card says about itself, or nil if it will not say. |
| `M.is_the_display_card(card)` | Whether the card that would draw the pictures is also drawing the screen. |
| `M.room_to_work(settings)` | Whether there is enough of the card free to start a picture. |
| `M.where(settings)` | The address the picture program is listening on. |
| `M.input_folder(settings)` | The folder that program reads its inputs from. |
| `M.listening(settings)` | Whether there is anything there, and what it says about itself. |
| `M.submit(settings, graph_text)` | One workflow, posted. Returns the identifier the far end gave it. |
| `M.wait_for(settings, identifier, patience)` | Poll until the picture is made, or give up. |
| `M.collect(settings, filename, subfolder)` | The finished picture, fetched. |
| `M.make_one(settings, record, store, options)` | One character, all the way from a recipe to a rated picture in the pool. |

### `M.card()`

What the graphics card says about itself, or nil if it will not say.

Total memory, how much is in use, and how much is free -- in gigabytes.

### `M.is_the_display_card(card)`

Whether the card that would draw the pictures is also drawing the screen.

WHY THIS IS ASKED AT ALL, and it is the whole of `409`. This project reasoned carefully about the processor getting hot and never asked the same question about the card -- on the grounds that generating is the card's work rather than the processor's, so the processor's governor did not apply. True, and it answered the wrong question. On a machine with one graphics card, that card is drawing somebody's desktop; take its memory and the desktop stops responding, which from outside is not a slow computer but a frozen one.

A card with a desktop on it is never at zero before anything of ours has run. That is the tell, and it is asked rather than assumed.

### `M.room_to_work(settings)`

Whether there is enough of the card free to start a picture.

Asked before submitting rather than discovered by submitting. A run that wedged the display cannot tell anybody anything; one that stopped early can.

### `M.input_folder(settings)`

The folder that program reads its inputs from.

It names its inputs by filename and looks in its own folder -- it does not take a path. So the workflow carries a name and the pictures have to be put where it will look. Getting this backwards produces a workflow that is correct and cannot find its own pictures, which `302` already warns about.

### `M.listening(settings)`

Whether there is anything there, and what it says about itself.

Nothing listening is the normal state of this repository, so it is answered plainly and with the command that starts one rather than by failing somewhere obscure two steps later.

### `M.wait_for(settings, identifier, patience)`

Poll until the picture is made, or give up.

Returns the filename and subfolder it was saved under.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `quote(text)` |  |
| `unescape(text)` | A string out of the far end's reply, with its escapes turned back. |
| `explain_silence(settings)` |  |
| `main(argv)` |  |

## Where it sits

Used by `035-test-the-machine`, `043-install-the-kitchen`, `045-the-pool-that-remembers`.
