# find-in-transcripts

Finds where a phrase was said in `llm-transcripts/`, with line breaks and
runs of spaces ignored (the transcripts wrap at 80 columns, so a phrase can
straddle two lines and a plain grep misses it). Prints each find's file and
line, and the lines around it. Used to check the pointers to the owner's
decisions that replace quoted decisions in comments (Issue 10-048).

## Usage

`scripts/find-in-transcripts [--dir PATH] "PHRASE" [--context N]`

| option | meaning |
| --- | --- |
| `PHRASE` | the words to find (case ignored) |
| `--context N` | lines shown around each find (default 3) |

Exit status: 0 found, 1 not found.

## Test

`scripts/find-in-transcripts.test.sh`
