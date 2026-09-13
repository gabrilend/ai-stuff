# 102 - The build record

| | |
|---|---|
| Phase | 1 - the patch spine |
| Blocked by | 101, which fetches the document this reads |
| Blocks | every extractor, because a fact without a build is not storable |

## Current behaviour

The build history sits in the archive as fetched bytes that nothing can use.

## Intended behaviour

One typed record per shipped build, extracted from the archived document and
never fetched again. The extractor reads the archive and writes facts; it must
not reach the network, so that re-extracting after a bug is free and repeatable.

The build record's fields, down to primitives:

| Field | Type | Meaning |
|---|---|---|
| `line` | string | which product line - retail, a test realm, a Classic line |
| `major` | integer | the first number; names the expansion |
| `minor` | integer | the second number; the content patch |
| `patch` | integer | the third number; the corrective release |
| `build` | integer | the fourth number; unique and ordered, the real identity |
| `released` | string | the date this build went up, as year-month-day |
| `addressing` | table | the identifiers the publisher uses to name this build's data, kept so a later source can ask about this exact build |

## Suggested implementation steps

1. Parse the archived document into build records.
2. Reject rather than repair. A version string that is not four numbers, a
   missing date, an unparseable line - each is an error that names the offending
   entry and stops. A build history with a silently dropped entry is a patch
   axis with a hole in it, and the hole would not be visible later.
3. Store the records in the shape the fact document describes, sorted by build
   number ascending, keys written in sorted order so that a re-extraction that
   changes nothing produces no diff.
4. Test: re-running the extractor on an unchanged archive produces a
   byte-identical result. This is the property that makes the archive
   trustworthy, so it is checked rather than assumed.

## Related documents

- The shape of a fact - the record format and why keys are sorted on write
