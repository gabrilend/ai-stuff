# measure-authorship.lua

## Overview

Produces the front page's four figures, all in characters:

1. **Human-written text:** what the person typed in the conversations, plus
   everything under a `notes/` folder.
2. **Machine-written text:** what the model wrote in the conversations.
3. **Source code in the tree:** the repository's tracked program source.
4. **Documents in the tree:** the tracked documents, issue files included.

It has two halves. The first reads every saved conversation and splits it
between the person and the model. The second reads the files git tracks and
sorts them into notes, source, documents, or someone else's work.
Everything set aside is reported too, so the rules can be checked rather
than trusted (issue 059).

## Commands

    measure-authorship.lua                  terminal summary
    measure-authorship.lua --json           JSON, for the census and other programs
    measure-authorship.lua --largest [N]    the N biggest files in each pile (default 15),
                                            for checking where the rules put things
    measure-authorship.lua --dir=/path      measure another checkout (any position)
    measure-authorship.lua --workers=N      parallel workers (default: CPU count)

`--worker LIST OUT` and `--count-worker LIST OUT` are internal: one worker's
share of the transcripts, or of the repository's files.

Exit status: 0 measured. 1 a refusal, printed as one line: no transcripts
found, git tracks nothing, a worker failed or stopped before finishing its
share, or a malformed record. 2 an unknown mode.

## JSON shape

    { "human_written_total":       int,     human_characters + notes_characters
      "machine_written_total":     int,     the model's characters (= machine_units)
      "source_characters":         int,     tracked source code
      "docs_characters":           int,     tracked documents, issue files included
      "notes_characters":          int,     tracked files under any notes/ folder
      "human_characters":          int,     the person's characters in conversation
      "machine_units":             int,     the model's characters in conversation
      "machine_unit_name":         string,  always "characters"
      "ratio":                     number,  machine_units / human_characters
                                            (0 when nothing typed was found)
      "transcripts_counted":       int,     markdown files read under llm-transcripts/
      "excluded_paste_characters": int,     pasted errors, logs and program output, set aside
      "system_characters":         int,     tool-generated text, set aside
      "turns_counted":             int,     distinct turns after removing copies
      "turn_copies_seen":          int,     turn copies read, before removing copies
      "vendored_characters":       int,     someone else's code in the tree, set aside
      "repo_files_counted":        int,     tracked files counted into a pile (distinct contents)
      "repo_duplicate_files":      int }    further copies of those, counted once

## What is a character

A UTF-8 code point. Every run of whitespace counts as one character, because
the exporter re-wraps lines and a wrap must not change the count. Both sides
are counted the same way. Tokens are not used: the transcripts do not record
them, and counting them would need the model's tokenizer.

## Which files

Every `*.md` under any `llm-transcripts/` folder in the repository. Skipped:
`.git/`, the transcript keepers' `.patches/` records, and `.bak` copies.
Files with no turns in them (`wordcloud.md`, `robot-analytics.md`, the older
exports whose conversation section is empty) are read and contribute
nothing.

## Who sat in the user's chair

| Transcript | Its user turns are |
|------------|--------------------|
| a session id `agent-…` (a sub-agent) | machine: the main model wrote the prompt |
| every other session, including those saved as `<date>_agent-<n>.md` | the person's, with the exceptions below |

A file name is the exporter's label, not evidence of who typed. The
`_agent-<n>.md` runs with ordinary session ids open with "Hello computer, all
is well.", and the owner says only they type it (issue 059, answered
questions). So those prompts count as the person's, with no evidence of a
script to say otherwise.

Assistant responses are machine everywhere, including their `>` interim
lines.

## Exceptions inside an ordinary session

| A user turn that | Is credited to |
|------------------|----------------|
| continues a compacted session ("This session is being continued…") | machine |
| is a message from another model session ("Another Claude session sent a message:", `<agent-message>`) | machine |
| is tool output: `<local-command-stdout/stderr/caveat>`, `<task-notification>`, `<bash-stdout/stderr/notification>`, "Caveat: The messages below…", "Warmup", an interruption notice | set aside |
| is a skill's instructions ("Base directory for this skill:", a `# … Skill` heading, the design-lead prompt) | set aside |
| wraps something typed: `<command-args>`, `<user-memory-input>`, `<bash-input>` | the typed part is the person's; the wrapper is set aside |
| contains `<system-reminder>` spans | those spans are set aside |
| anything else | the person's, less pasted logs |

## Pasted logs

A turn is cut into blocks: each fenced code block, and each paragraph
between blank lines. A block is a log when:

- it holds a **strong signature**: a Python traceback, Lua's
  `stack traceback:`, a JavaScript stack frame, `error:` with a
  `file:line`, or a `luajit:` or `lua:` error line; or
- **half or more of its lines are log-shaped**: a `path.ext:123:`
  location, a timestamp, an `[ERROR]`/`WARN`/`INFO` level, a compiler
  caret, a shell prompt, two or more `key=value` pairs, a
  `snake_case_logger:` prefix, nvcc's `#$ ` lines, a line of `--flags`, a
  bare absolute path, `file.h(79): error`, "4 errors detected",
  `tool warning :`.

**Pasted program output** is set aside the same way. The owner's answer:
"ideally, no [it shouldn't count as theirs], but good luck recognizing it."
Its line shapes join the log shapes:

- box-drawing characters and shaded bar blocks;
- a `[=====>  ]` progress bar, a `(53.1%)` figure, a `4200/7904 poems`
  counter;
- a quoted `> ` line, meaning the model's words quoted back;
- a `[user@host dir]$` prompt;
- an emoji-led status line (✅ 📝 🖼);
- columns aligned with runs of three or more spaces;
- a bare relative path.

The exporter re-wraps long lines and puts blank lines between the pieces,
so a log also spreads to its neighbours. The two rules below are repeated
until nothing changes:

- a block right after a log that is not a sentence is part of the log;
- a short block, under 60 characters, between two logs is part of the log.
  A longer one is the person replying between two quoted excerpts, and
  stays theirs.

A block reads as a sentence when any of these holds:

- it ends in a question mark;
- it has six plain words in a row;
- it has three ordinary words in a row and sentence-ending punctuation.

When a block is a log but opens with a sentence that shares its paragraph,
the opening lines stay the person's.

Pasted material that none of these shapes catches still counts as the
person's. That covers prose carried over from another conversation, for
example.

## Removing copies

Each user turn is keyed by three things joined together: its normalised
text and the normalised text of the two user turns before it in the same
conversation.

- The chain restarts at every conversation boundary: `# Conversation
  Summary:`, `## 📜 Conversation`, `Printing conversation:`, or a new
  file. A boundary also ends an open turn when no separator line comes
  before it.
- The key carries the turn's origin (person or sub-agent), so a
  model-written prompt never merges with a person's message.
- Keys are 64-bit hashes: two FNV-1a passes with different seeds.
- Every assistant response up to the next user turn is summed onto the
  turn. This covers the "(continued)" parts.

When the same key appears more than once:

- the person's side is counted once;
- the machine's side uses the longest copy. Renderings at different levels
  of detail disagree, and the fullest one includes the files the model
  wrote.

Known edge: the same short message three times running in one conversation
("continue", "continue", "continue") keys the third like the second, so it
is counted once.

## The repository's files

Only files git tracks are read (`git ls-files -z`), so scratch space,
ignored files and anything untracked are out. Each path goes to the pile of
the first rule that matches:

| Rule | Pile |
|------|------|
| under a folder whose licence file names someone other than the owner; the top-level `libs/`; a `luarocks`, `node_modules`, `vendor`, `third_party`, `third-party` or `site-packages` folder; a browser-saved page (`X.html` beside `X_files/`) | vendored (set aside) |
| a `.bak` file | left out (a copy) |
| under `llm-transcripts*/` or `docs/HTML/` | left out (measured elsewhere / generated) |
| under a `notes/` folder, even inside `input/` | notes (the person's) |
| under `input/`, `output/`, `backups/`, `archives/`, `archive/`, `source/` | left out |
| `.md` or `.markdown`; `.txt` under `docs/` or `issues/`; `README*.txt` | docs |
| a source extension (lua, c, h, sh, py, rs, js, go, cpp, html, css, glsl…; full list in the script), or `Makefile`, `CMakeLists.txt`, `Dockerfile`, `meson.build` | source |
| no extension, not hidden, and opens with `#!` | source |
| anything else | left out |

Four decisions need the file's contents:

- A NUL byte in the first 8 KB means binary, left out.
- A tracked path that reads as nothing is a nested repository or a
  symlinked folder, left out.
- A document or note holding exported conversation turns is transcript
  material filed elsewhere, left out so it is not counted twice.
- Source whose first 60 lines carry a foreign notice is vendored.

**Someone else's work** follows the repository's COPYRIGHT file: "look for
the nearest license file… and read the file's own header while you are at
it". A notice counts as foreign when it has any of these shapes and doesn't
mention the owner (`gabrilend`) or the FSF's own copyright on the GNU
licence text:

- a copyright line with a year, or `(c)`;
- `©` with a year;
- MIT's "Permission is hereby granted" or "The MIT License";
- "Licensed under the Apache";
- "Created/distributed by".

Not the rule: "every `libs/` folder is vendored". Most projects' `libs/`
hold code written here: vulkan-compute, sd-image-parts, the shared
`scripts/libs/`.

**Copies:** when the exact same contents are tracked in more than one
place, they are counted once, in the most personal pile any copy reached:
notes, then docs, then source, then vendored.

## Parallelism

Both halves run the same way. The work is dealt round-robin into one share
per worker, and each worker is a separate LuaJIT process started at the
same moment, because LuaJIT has no threads.

- Workers write their records into a fresh folder in the RAM tier
  (`delta-version/tmp/shared-memory/measure-authorship/run.*`, prepared by
  `scripts/libs/ensure-ram-tiers`).
- Each worker ends its output with a `#finished` line. The shell's `wait`
  reports success even when a worker died, so a share without that line
  stops the run rather than shrinking the totals.
- The parent merges the records and removes the folder.

The result is the same for any worker count, and the tests check this for
both halves.

## Tests

`test-measure-authorship.sh` builds fixtures in
`/dev/shm/delta-version/measure-authorship-test` and checks each rule:

- transcripts for the conversation rules, including pasted program output
  set aside and sentences that mention paths, percentages or emoji kept;
- a small git repository with one file per repository rule, including an
  untracked file, a duplicate and a binary.

`KEEP_FIXTURES=1` leaves the fixtures in place for inspection.

## Related

- `census-projects.lua` turns this figure into a README slot (issue 058).
- `../issues/059-measure-human-and-machine-authorship.md` gives the reasons
  and holds the open questions.
