# 204 - The append-only archive

| | |
|---|---|
| Phase | 2 - the harvester |
| Blocked by | 201, 202 |
| Blocks | every extractor, which may only read from here |

## Current behaviour

Fetched bytes have nowhere to go.

## Intended behaviour

A place where every response ever received is kept exactly as it arrived,
forever, with its provenance beside it, and which nothing downstream may write
to.

The single rule: **an archived file is never edited and never deleted.** When an
extractor turns out to have been wrong, the repair is to extract again. This is
not tidiness, it is the only way the archive means anything - re-fetching does
not return what was fetched before, because sources edit pages, repositories
force-push, and spreadsheet owners revoke sharing. The archive is the only copy
of what was true when we looked.

A provenance record travels with every archived file:

| Field | Type | Meaning |
|---|---|---|
| `source` | string | which registry entry asked |
| `asked_for` | string | the exact thing requested |
| `asked_at` | string | when |
| `status` | integer | what the server said |
| `claimed` | table | what the response said about itself - its type, its length, its freshness markers |
| `bytes` | integer | what actually arrived, which is checked against what was claimed |
| `digest` | string | a fingerprint of the content, so a later re-fetch can be compared against this one without either overwriting the other |

The digest is what makes re-fetching safe rather than forbidden. Asking again
later and finding the same fingerprint is a confirmation, which the fact records
want. Finding a different one is a discovery - the source changed - and both
copies are kept, because which of them is correct is not the archive's business.

## Suggested implementation steps

1. Lay the archive out by source, then by the split seam that source declares,
   then by the thing asked for. The path should be readable enough that a person
   can find a file without a tool.
2. Write the file and its provenance together, into the RAM tier first, moved
   into place only once both are complete. A provenance record without its file,
   or a file without its provenance, is a corruption that is hard to notice.
3. Enforce the no-edit rule mechanically where the filesystem allows it, not by
   convention. A convention that only the author remembers is not a rule.
4. Test that fetching the same unchanged thing twice produces one file, two
   provenance records, and a confirmation rather than a duplicate.
