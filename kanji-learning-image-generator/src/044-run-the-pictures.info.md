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
luajit src/044-run-the-pictures.lua --chars 時語 --style photographic
luajit src/044-run-the-pictures.lua --chars 木 --resolution 1536
luajit src/044-run-the-pictures.lua --chars 休 --kitchen across
```

## What it offers

| | |
|---|---|
| `M.for_kitchen(settings, name)` | The settings as they are for one of the other kitchens (`415`). |
| `M.system_stats(settings)` | What the far end says about its own card, through its own /system_stats. |
| `M.card(settings)` | What the graphics card says about itself, or nil if it will not say. |
| `M.is_the_display_card(card, settings)` | Whether the card that would draw the pictures is also drawing the screen. |
| `M.room_to_work(settings)` | Whether there is enough of the card free to start a picture. |
| `M.where(settings)` | The address the picture program is listening on. |
| `M.upload(settings, path, name)` | One input picture, handed to the picture program over HTTP. |
| `M.wanted_by(graph_text)` | What a workflow needs the far end to have: its box types and its models. |
| `M.inventory(settings, graph_text)` | Everything a workflow needs that the far end does not have, all at once. |
| `M.listening(settings)` | Whether there is anything there, and what it says about itself. |
| `M.submit(settings, graph_text)` | One workflow, posted. Returns the identifier the far end gave it. |
| `M.wait_for(settings, identifier, patience)` | Poll until the picture is made, or give up. |
| `M.collect(settings, filename, subfolder)` | The finished picture, fetched. |
| `M.make_one(settings, record, store, options)` | One character, all the way from a recipe to a rated picture in the pool. |
| `M.draw_one_route(settings, record, made, recipe, options)` | One route's recipe, posted, drawn, collected, filed and -- where it means |

### `M.for_kitchen(settings, name)`

The settings as they are for one of the other kitchens (`415`).

Each kitchen in `settings.kitchens` is a set of changes laid over the sections of the settings -- kitchen, workflow, field -- and only what it writes differs. A copy, never written into the shared table, because half this project reads that table.

No name means the settings unchanged: the local kitchen. A name that is not there is an error naming the ones that are, rather than a quiet return to the local one -- a run aimed at another machine that silently ran here would look exactly like it had worked.

### `M.system_stats(settings)`

What the far end says about its own card, through its own /system_stats.

For a kitchen on another machine nvidia-smi answers about the wrong card -- this one -- so the far end is asked instead. Returns the same shape as `M.card`, or nil if it would not say.

### `M.card(settings)`

What the graphics card says about itself, or nil if it will not say.

Total memory, how much is in use, and how much is free -- in gigabytes. The card asked is the kitchen's: this machine's through nvidia-smi, or the far end's through its own report when the kitchen is elsewhere.

### `M.is_the_display_card(card, settings)`

Whether the card that would draw the pictures is also drawing the screen.

WHY THIS IS ASKED AT ALL, and it is the whole of `409`. This project reasoned carefully about the processor getting hot and never asked the same question about the card -- on the grounds that generating is the card's work rather than the processor's, so the processor's governor did not apply. True, and it answered the wrong question. On a machine with one graphics card, that card is drawing somebody's desktop; take its memory and the desktop stops responding, which from outside is not a slow computer but a frozen one.

A card with a desktop on it is never at zero before anything of ours has run. That is the tell, and it is asked rather than assumed.

Except on a card in another machine, where the tell does not work: the far end's own program is already holding memory, so the card is never at zero whether or not a screen is on it. That kitchen says in the settings what is known (`shares_a_screen`), and says it is assumed when nobody knows.

### `M.room_to_work(settings)`

Whether there is enough of the card free to start a picture.

Asked before submitting rather than discovered by submitting. A run that wedged the display cannot tell anybody anything; one that stopped early can.

### `M.upload(settings, path, name)`

One input picture, handed to the picture program over HTTP.

It names its inputs by filename and looks in its own folder -- it does not take a path. This used to be met by copying the pictures into that folder, which only works when the folder is on this machine. Posted to its upload address instead, the picture lands in the same folder whichever house the program lives in, so there is one route rather than two (`415`).

`name` is what the workflow calls it, "kanji/00006728-field.png": the folder part goes as the subfolder, the rest as the filename. Overwrite is on, so a character made again replaces its own input rather than being filed under a new name the workflow does not know. The reply's filename is checked against the one asked for, because a workflow naming one file while the far end filed another finds nothing and fails three steps later.

### `M.wanted_by(graph_text)`

What a workflow needs the far end to have: its box types and its models.

Read out of the workflow's own text, so the list cannot drift from what is actually posted.

### `M.inventory(settings, graph_text)`

Everything a workflow needs that the far end does not have, all at once.

Asked before posting, of the program itself. A kitchen this project did not install cannot be reasoned about -- what it holds is a fact about that machine -- and the refusal it would give names only the first missing piece. This names every one, so one look at the list says what to ask the owner for. An empty list means everything is there.

### `M.listening(settings)`

Whether there is anything there, and what it says about itself.

Nothing listening is the normal state of this repository, so it is answered plainly and with the command that starts one rather than by failing somewhere obscure two steps later.

### `M.wait_for(settings, identifier, patience)`

Poll until the picture is made, or give up.

Returns the filename and subfolder it was saved under.

### `M.draw_one_route(settings, record, made, recipe, options)`

One route's recipe, posted, drawn, collected, filed and -- where it means

anything -- graded.

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
