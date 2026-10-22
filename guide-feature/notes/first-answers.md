# First answers

Written by Claude on 2026-10-21, while initialising the project, so the owner's
answers to the first four questions sit beside the vision they refine. The
owner's words are kept verbatim below each question.

## Where kuvalu's inbox listens

The vision gave port 111213. A port number is a 16-bit field in every TCP
header, so the highest possible port is 65535 and 111213 cannot be opened.

> 1223

## How one shared page survives rmail's "only the author's edits travel" rule

rmail sends an edit to every recipient only when the author edits their own
outbox file. A recipient's edit to their inbox copy stays on their machine and
is overwritten by the author's next update. So a single page that four
machines edit together does not map onto rmail directly.

> we'll have to handle it with hook scripts. Let rmail handle the
> communication, and the logic processing will happen with our running lua
> program.

## What is listening on the three fg-sora ports today

> Nothing yet

## What "the user's display module" is

> protocols, not procedures. Create an API, and then create a lua window
> (recommended), terminal view (limited display features), HTML page (remote
> access), and possibly an android app for mobile usage. Definitely an apple
> watch app.

## Added while the first documents were being written

The display box, and the language model told when it does not fit:

> we must also be able to limit the dimensions (in characters, X/Y or
> width/height) of the display box, so that we can dynamically adjust to
> various size screens. The LLM is provided this knowledge, and if their
> output doesn't fit it is returned mechanically and run again with a
> description of why. Like a compiler error.

The fg-sora machines as relays:

> also, can we add functionality to have the three mini-computers connect to
> remote locations to do their LLM processing? Acting as relay nodes.
