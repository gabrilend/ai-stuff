# Issue #031: Harness output blocks reach the transcript as raw tags

**Status (2026-11-02):** built, apart from step 4 (rebuilding the corpus),
which needs the session logs on the developer's machine. See *What Happened*
at the end.

## Current Behavior

When a command is run during a conversation, the harness writes the command and
its output into the record using its own tags. The exporter passes them through
untouched, so they land in the transcript as literal markup:

    <bash-input>pwd</bash-input>
    she said

    <bash-stdout>/home/ritz/games/tq/ai-stuff/double-diaper-dungeon</bash-stdout><bash-stderr></bash-stderr>

Three things are wrong with that, in rising order of how much they matter.

**It reads as markup rather than as anything.** A person reading the transcript
sees angle brackets and tag names, which say nothing about what happened.

**An empty stream still prints.** `<bash-stderr></bash-stderr>` is a pair of
tags around nothing, which on a page is a piece of furniture announcing that
there was no furniture.

**It is machine text sitting in a person's turn.** The exporter already lifts
harness-authored text out of the user's seat -- caveats, slash commands, task
notifications -- because putting machine bookkeeping in somebody's mouth
misattributes it. These blocks are the same kind of thing and were missed.

That last one is why this is worth fixing rather than styling around: the
transcripts are published, and on a public page a reader cannot tell that the
line was not typed by the person it appears under.

## Intended Behavior

A command and its output are rendered as what they are: a command that was run,
and what it said back. The shape the rest of the format already uses for
machine-authored text is the shape to follow rather than a new one.

What each stream becomes:

| in the record | on the page |
| --- | --- |
| the command | a line marked as a command that was run |
| standard output | the output, as a block |
| standard error, non-empty | the output, marked as the error stream |
| standard error, empty | nothing at all |

**An empty stream emits nothing.** Not an empty block, not a marker saying it
was empty. There is a difference between "the command printed nothing" and
"there was no command", and the first does not need a monument.

**The command's text is not re-interpreted.** Whatever it contains -- quotes,
angle brackets, markdown characters -- is shown as typed. It went to a shell,
not to a renderer.

## Suggested Implementation Steps

1. Find where the exporter recognises the other harness-authored shapes -- the
   local-command caveats, the command name and message pairs, the task
   notifications -- and add these beside them. They are the same category and
   belong in the same place rather than in a new pass.
2. Emit the command and each non-empty stream in the format's existing
   vocabulary for machine text, so a reader and the website renderer both
   already know what to do with it.
3. Drop empty streams entirely.
4. Rebuild the corpus. Every transcript whose session log still survives can be
   regenerated; the ones whose logs expired are frozen and stay as they are,
   which means the raw tags remain visible in the oldest transcripts forever and
   that is acceptable.
5. Test with the three shapes that are easy to get wrong: a command with no
   output at all, a command that wrote only to the error stream, and a command
   whose output contains the harness's own tag names as text.

## Related Documents and Tools

- `libs/conversation-parser.lua` -- the exporter, and where the other
  harness-authored shapes are already handled
- `README-backup-conversations.md` -- the format description, which this adds a
  row to
- `double-diaper-dungeon/issues/10-003-the-transcript-renderer.md` -- the
  website that publishes these transcripts, and the reason the misattribution
  matters rather than merely looking untidy

## Notes

Raised by the developer after reading the rendered transcripts on the website,
where the raw tags are plainly visible. She asked for the fix upstream rather
than in the renderer, which is right: the renderer would be painting over
something the exporter should not be emitting, and every other consumer of the
format would still see the tags.

## What Happened

Built on 2026-11-02 in `libs/conversation-parser.lua`, beside the other
harness shapes as step 1 asked.

**What a command now looks like in a transcript:**

    `pwd` *(shell)*

    ```
    /home/ritz/games/tq/ai-stuff/double-diaper-dungeon
    ```

and, for one that wrote only to the error stream:

    `ls missing` *(shell)*

    *standard error:*

    ```
    ls: cannot access 'missing': No such file or directory
    ```

The command and its output are one unit closed by one rule line, written
where the log has them, and take no number in the person's sequence. A
command that printed nothing is the command line alone.

**How:** `split_shell` runs before every other envelope rule and turns the
tags into `shell`, `shell_output` and `shell_end` items; the main loop holds
the command until its output message arrives (the log files them as two
messages), then writes both. The unit is written without the wrapper, so a
command's spacing and the output's columns survive.

**Decisions made while building it** (the issue left these open):

- *The marker.* `` `COMMAND` *(shell)* ``, the same shape as a skill
  invocation's `` `name` *(skill)* `` line, so the format gains no new kind
  of line. "shell" rather than "bash" because the reader cares that it was a
  command, not which shell ran it.
- *A command that would not survive as inline code* -- it spans lines, or
  holds a backtick -- is the bare `*(shell)*` marker over a fenced `sh`
  block, because nothing in a block is re-read as markdown.
- *Only standard error is labelled.* Standard output is the expected case
  and sits directly under the command; a label on it would be the monument
  the issue warns against.
- *Output containing the tag names.* When a message is exactly one of the two
  shapes, each closing tag is found from the end of the message rather than
  the first one met, so printing a session log with cat keeps the log whole.
  Shell blocks are also lifted out before any other rule, or a
  `<system-reminder>` inside printed output would have been cut out of it.
- *Output containing fences.* A block's fence is one backtick longer than
  the longest run that opens any of its lines, so `cat README.md` stays
  inside its block. The site's markdown reader
  (`transcript-site/libs/markdown.lua`) closed a block at any ``` line; it
  now needs a fence at least as long as the opening one, which is the
  CommonMark rule and changes nothing for ordinary three-backtick blocks.
- *Trimming.* Blank lines at either end of a stream are dropped; the first
  printed line keeps its indentation.

**Tested** by `tests/test_conversation-parser-shell-blocks.lua`: the
developer's `pwd` example, a command with no output, a stderr-only command
whose text holds quotes and angle brackets, output holding the harness's own
tags, output holding its own fences, numbering, ordering, and the site
reader drawing a long fence. All the other parser tests, the wrapping,
export-guard, patches and site tests still pass.

**Left for the developer:** step 4, rebuilding the corpus. Every transcript
whose log survives picks this up on its next export; to do them all at once,
run `rederive-transcripts` to see what would change, then again with
`--write`.

**Known and not fixed here:** the site's transcript reader drops any line of
eight or more dashes as a separator, even inside a code block, so output
holding such a line loses it on the page (not in the file). It already did
this for code the model wrote, and fixing it is the reader's business.
