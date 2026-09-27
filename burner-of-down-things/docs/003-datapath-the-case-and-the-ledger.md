# 003 — Datapath: the case and the ledger

Everything the machine knows about one piece of software lives in one folder,
and everything that has happened to it is one file that only grows.

## The case folder

```
cases/<name>/
  case.lua        the case record (002): source path, harness, target
  input/          the person writes here: requests, and `target` if they want one
  output/         the machine writes here: reports for the person, and goodbye
  survey/         files.tsv, links.tsv, summary.txt           (004)
  blueprint/      outline.tsv, issues/*.md                    (006)
  design/         the new code, laid out as a house project   (007)
  turns/          one folder per model turn                   (005)
  ledger          the chained record
  lock            present only while the machine is working this case
```

Cases live in `${DIR}/cases/` by default. `cases/` is in `.gitignore`: a case
is the person's material, often someone else's source, and the machine's own
repository does not carry it.

| Decision | What each path leads to |
|---|---|
| `open` is given a source folder that does not exist | Refused, naming the path |
| `open` is given a name already used | Refused; a case is never overwritten. The person picks another name or works the existing one |
| A command finds `lock` present | Refused, naming the process id written in it. Two machines working one case would interleave the ledger |
| The lock's process id is no longer running | Still refused, with the id and the instruction to remove the lock by hand. A dead lock is evidence of a crash, and the person should see it |

## One run, start to end

```
  read input/ ──► take the lock ──► verify the ledger ──► do the command ──► write output/goodbye ──► drop the lock
```

1. **Read `input/` first.** Every file there is listed, and any not yet named
   by a `request-received` ledger line is new. This is the first thing every
   command does, because what the person wrote decides what the run is about.
2. **Verify the ledger** before appending to it. A broken chain stops the run
   ([below](#what-the-chain-is-for)).
3. **Do the command.** Each step appends ledger lines as it goes, never at the
   end in a batch, so a crash leaves an accurate partial record.
4. **Write `output/goodbye` last**: what was done this run, what is waiting,
   what failed. Overwritten each run; the ledger holds the history.

## The ledger

A line is appended by one function that reads the last line's hash, builds
the new line, hashes it, and writes it with a single append. Nothing else
writes the file.

| Kind | Written when | `about` |
|---|---|---|
| `case-opened` | the case folder is made | `-` |
| `request-received` | a new file is found in `input/` | the file name |
| `surveyed` | the survey finishes | `-` |
| `turn-started` | a harness is started | the turn id |
| `turn-ended` | it exits, with its verdict | the turn id |
| `breach` | confinement found a write outside the allowed paths | `set of N`: turns run together cannot be told apart, so the whole set is named |
| `outlined` | the outline passes its checks | `-` |
| `outline-failed` | an outline turn's table fails a check | `attempt N` |
| `described` | an issue file passes its checks | the issue id |
| `describe-failed` | an issue's describe turns all fail their checks | the issue id |
| `built` | an issue's tests pass in the design | the issue id |
| `build-failed` | an issue's tests still fail after its retries | the issue id |
| `refereed` | a referee turn's workflows pass their checks | `-` |
| `referee-failed` | three referee turns' workflows all fail their checks | `-` |
| `workflow-failed` | a workflow still fails after two rounds of repair | the workflow's file name |
| `audited` | an audit turn looked at one issue's part for a failing workflow | the issue id; text `changed` or `unchanged` |
| `inspected` | an inspection looked at a group of issues | the group, e.g. `201+301`; text the issue named, or `none`, and why |
| `delivered` | every issue is built, the final acceptance run passes, and every workflow passes | `-` |
| `graded` | a request's grade is decided | the request file |
| `held` | a graded request waits for the person's `--go` | the request file |
| `request-failed` | a request's locate, amend or rebuild gave up | the request file |
| `request-done` | a request's rebuild has passed | the request file |
| `goodbye` | the run ends | `-` |

### What the chain is for

> append-only memory, no editing possible. backwards verified with encryption
> keys via checksum analysis generation.

Each line carries the hash of the line before it and a hash of itself. Change
one character of an old line and its own hash no longer matches; replace the
hash too and the next line's `prev` no longer matches. Verification walks the
file from the first line and reports the first line where either fails.

The chain does not stop a person with an editor from rewriting the whole file
and re-hashing every line. What it does is make any edit short of that visible,
and make the head hash — the last line's hash, 64 characters — a fingerprint
of the whole history. Two copies of a case with the same head hash have the
same past.

| Decision | What each path leads to |
|---|---|
| Verification finds a mismatch | The run stops, printing the line number and both hashes. The machine never repairs a ledger |
| The ledger file does not exist in a case folder | The case is broken: refused. Only `open` creates a ledger |
| A line's text contains a tab or newline | Escaped as `\t` and `\n` before hashing, so one event is always one line |

## Why the center reads only this

[The center](009-datapath-the-center.md) — what the machine attends to first —
is computed from the ledger and nothing else. Anyone holding the ledger can
recompute it and get the same answer. *At least then, the evil singularity is
predictable in kind.*
