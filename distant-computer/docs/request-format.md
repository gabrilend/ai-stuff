# The request file

One file per request. The steward writes it in the distant computer's
outbox; the courier carries it into the near computer's gate.

## Name

    <yyyymmdd>-<hhmmss>-<kind>-<4 hex digits>

for example `20261028-231122-commit-7f3a`. That name is the request's id
everywhere: in the ledger, in answers, and in conversation. Sorting the
names sorts the requests by the time they were made.

## Contents

A header of `name: value` lines, a blank line, then the body:

    kind: commit
    from: steward
    project: guide-feature
    reason: "the fit check now reports column numbers; issue 105 asked for it"
    made: 2026-10-28T23:11:22Z

    <body>

| field | type | required | meaning |
| --- | --- | --- | --- |
| `kind` | `commit`, `write`, `sudo`, `outward`, `decision` | yes | picks the reader and applier |
| `from` | one word | yes | the voice or program that asked |
| `project` | one word | no | the monorepo folder it concerns |
| `reason` | quoted text | yes | why, in plain words |
| `made` | UTC time | yes | when |

## The body, per kind

| kind | body |
| --- | --- |
| `commit` | one line: the full commit hash on the distant branch. The commit itself travels by `git fetch`, not in the file |
| `write` | first line `path: <path relative to the monorepo root>`, then a blank line, then the file's new bytes exactly |
| `sudo` | the command, one line, exactly as it would be typed |
| `outward` | a free description: what to do, for whom, what it costs or earns, and what happens if it is declined |
| `decision` | the question, then a line `options:` followed by one option per line |

## Answers

An answer is a file of the same id in the gate's `answered/` folder, carried
back to the distant computer's `answers/` folder:

    answer: approved
    by: owner
    time: 2026-10-28T23:14:05Z
    note: "free text, may be empty"

For a `decision`, `note` holds the chosen option or the owner's own words.

## Refusals

The gate refuses, and does not queue, a request that:

- has a kind it does not know;
- is missing a required field;
- for `write`, names a path outside the monorepo or one containing `..`;
- for `commit`, names a commit the courier did not fetch.

A refused request is still written to the ledger (`failed`, with the
reason), so the steward can read why.
