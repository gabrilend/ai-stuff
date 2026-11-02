# transcript-prompts

Writes, beside each conversation transcript, a file holding only what the
person asked: one request per line. A model picking a project back up reads
every request in a few screens, then opens the transcript at the request it
needs. Design and decisions: `issues/002-add-simple-input-for-LLMs.md`.

## Where the file lives

```
<project>/llm-transcripts/prompts/<transcript name without .md>.txt
```

Its name follows the transcript's, so it is found by the same name and is
renamed with it. It sits in a sub-folder so that nothing that scans
transcripts (the naming checks, the site builder, the corpus backup, the
claim finder, which all read `llm-transcripts/*.md` one level deep) ever
takes it for one.

## What is in it

- Line N is `### User Request N` of the transcript. No prefix, no numbering:
  the line number is the request number.
- A request's own line breaks are written as the two characters `\n`, a
  backslash as `\\`, a carriage return as `\r`. Every request is one line,
  and the text turns back into the transcript's byte for byte.
- The text is the **patched** transcript's, never the session log's. A patch
  that redacted words in a request (`transcript-patches`) redacts them here
  too, and the spot reads exactly as it does in the transcript. The price:
  the text is the transcript's rendering, wrapped at eighty columns, with
  pasted-back lines marked `> `.
- A helper's transcript (`agent-...` in its header) gets no prompts file: its
  requests were written by the model that spawned it, not by the person.
- A conversation with no requests gets an empty file.

## Who writes it

The exporter (`backup-conversations`) writes it on every export, created or
unchanged (so a missing one comes back), and removes it when its transcript
is renamed or retired. A file whose content would not change is left alone,
so its timestamp and git status do not move. A failure to write it fails that
conversation's export, after the transcript itself is in place.

`commit-own-changes` carries prompts files by the rules it uses for
transcripts: those of the projects in the commit, and those whose transcript
belongs to the committing conversation.

## Usage

```bash
transcript-prompts TRANSCRIPT.md...        # write each one's prompts file
transcript-prompts --dir LLM-TRANSCRIPTS   # every transcript in the folder,
                                           # and remove prompts files whose
                                           # transcript is gone
transcript-prompts --print TRANSCRIPT.md   # the lines on standard output only
```

`--dir` is the way to fill in transcripts whose session log has expired:
the exporter will never write those again. Exit status: 0 done, 1 a
transcript could not be read (named on stderr; the others are still done),
2 bad arguments.

## As a library

```lua
arg[0] = "<scripts>/as-a-library"   -- anything not ending in transcript-prompts
local tp = dofile("<scripts>/transcript-prompts")
tp.lines_of(text)       -- the file's content, false for a helper, nil+why
tp.escape(s) / tp.unescape(line)
tp.prompts_path(transcript_path)
tp.write_for(transcript_path)  -- "created" | "updated" | "unchanged" | "skipped"
```

## Tests

`tests/test-transcript-prompts.sh` runs the exporter on a fake session store
and checks the file, the escaping, a redaction, an unchanged export, a
rename, a helper, `--dir`, `--print` and a refused transcript.
