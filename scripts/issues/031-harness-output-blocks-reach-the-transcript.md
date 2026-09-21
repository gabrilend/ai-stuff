# Issue #031: Harness output blocks reach the transcript as raw tags

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
