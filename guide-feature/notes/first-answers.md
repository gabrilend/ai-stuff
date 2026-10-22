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

## The second round: corrections to the first design

Written down 2026-10-21 after the owner read the first design. Claude had
described each voice keeping its own list of thoughts, matched by shared
words and faded by a number. The owner's answer, verbatim:

> not quite. Each system will have an r-mail mailbox, and they are wired to
> only accept connections from each other in the router settings. They can
> reach out to external LLM providers, but then they only accept exactly them
> as well, and only if we reached out first this session.
>
> there are four computers total in this setup, 3 minicomputers and 1 regular
> computer. the minicomputer's r-mail inbox will be set up to have a hook
> script upon receive that executes a turn of the LLM machinery, described
> elsewhere. Then, to write the output to the outbox with the correct
> formatting and such. This updated copy will be sent to Kuvalu, who will run
> all three combined to distill it once more, and then display it to the
> screen. Alternatively, kuvalu might (this is the original design) might
> simply update the display to the newest one. Each of the changed words get
> written, and if any letter in a word is overwritten and can't fit, then that
> word is deleted entirely. This should enable users to skim, and see the
> changed sections from all three. So, if on the previous turn one of the
> mini-computers changed the phrasing on a sentence, that sentence would be
> marked as "changed", and then it'd display to the user by writing over what
> was in that slot. Remember, they're all blitting to the same 2d character
> array.

On rmail's 30-second sync rhythm:

> we can adjust things like this on a per-implementation basis. That's why
> it's a lua script, so it's easy to edit and adapt to your needs.

Which project the voices draw from:

> whatever we're working on at the time.

Pure chance, or leaning toward files like the page:

> the tool call should be able to adjust an embedding priority. Each part of
> the codebase will have an embedding generated dynamically upon git commit,
> and the tool call the LLM emits will find similar token labels, like
> variable names, class names, structs, etc. It ignores syntax.
>
> the tool call will be able to say "I want a highly focused insight" or "I
> want a broad reaching exploration." and it'll deliver more or less similar
> or related pieces of architecture.

How the files reach the mini-computers:

> I think we'd git clone a project into the mini-computer if we were gonna
> work on it. To RAM if it fits.

The relays:

> let's implement this using llama.cpp. We can run on kuvalu for now, but
> make sure there's a config file in the project root that allows us to set
> multiple endpoints that can be selected from at runtime.

The display box:

> no, each machine gets access to all of the rows. and columns. They are all
> working with the same canvas size. They are just only displaying updates to
> the user, meaning they should try and change as minimal as they can in order
> to keep the important stuff from before displayed, while also fitting in new
> stuff. They should prioritize editing single words over changing sentences.
