# 206 - The licence audit

| | |
|---|---|
| Phase | 2 - the harvester |
| Blocked by | 202 |
| Blocks | anything reaching the history branch |

## Current behaviour

Every source is unchecked, which means nothing may be rehosted.

## Intended behaviour

For each source, somebody has read the terms it is offered under and written
down what they said. The registry entry then carries that judgement and the note
it was based on.

Public and freely licensed are different claims, and the difference is the whole
issue. Data can be openly served to anyone, without any permission to serve it
onward. Rehosting without checking is not a small risk taken knowingly - it is a
claim made about someone else's rights without looking.

Two judgements per source, kept separate:

- May the **bytes** be redistributed? This decides whether the archived files go
  on the history branch or stay gitignored.
- May **facts extracted from them** be redistributed? A number read out of a
  file is often not the file. This decides whether the extracted records may be
  published even when the bytes may not.

Until both are recorded, both read as forbidden.

## Suggested implementation steps

1. Work through the registry entry by entry. Record the licence, where it was
   found, what it said in the reader's own words, and the date it was read.
2. Where a source states no terms at all, that is *not* permission. It is
   recorded as verified-not-redistributable with a note saying terms were sought
   and none were found.
3. Add a check that runs before any commit to the history branch: any archived
   file whose source is not verified redistributable must be ignored rather than
   tracked, and the check fails loudly rather than quietly skipping it.
4. Re-read on a schedule. Terms change, and a judgement with a date on it is the
   only kind that can be noticed going stale.

## Open question this raises

The open-source simulator's repository is permissively licensed, but a licence
that permits redistribution of source code is not obviously a licence to
redistribute a fifteen-year clone of it as a data archive. That specific case
needs reading rather than assuming, and it is the largest single source in the
project.
