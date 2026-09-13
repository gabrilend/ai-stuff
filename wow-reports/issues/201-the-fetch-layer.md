# 201 - The fetch layer

| | |
|---|---|
| Phase | 2 - the harvester |
| Blocked by | nothing |
| Blocks | every source adapter |

## Current behaviour

Nothing fetches anything.

## Intended behaviour

One way to make a request, used by everything, which returns either a response
or a named failure and never a half-answer.

There is no TLS library for the Lua runtime installed on this machine - the
socket library is present without its encryption half, and every source worth
having is encrypted. So requests are made by driving the system's own transfer
program as a child process.

That is worth defending rather than apologising for. Certificate validation,
redirect following, timeouts, retry-after handling, resumable transfers and
content-encoding are all things that program already does correctly and that a
hand-rolled client would do badly for a year. The cost is one process per
request, which against a network round trip is nothing.

What a request returns:

| Field | Type | Meaning |
|---|---|---|
| `status` | integer | what the server said |
| `body_path` | string | where the bytes were written; never held in memory, because some responses are large |
| `headers` | table | the response headers, kept for provenance and for conditional requests later |
| `asked_at` | string | when the request was made |
| `took` | number | seconds elapsed, so the scheduler can learn how much a source is being burdened |

A failure is a named condition - refused, timed out, certificate rejected,
rate-limited, not found - never an empty body that looks like success. The
standing rule that a fallback is a warning and a warning is an error applies
here more than anywhere: a scraper that silently archives a zero-byte response
poisons the archive permanently, and the poison is invisible.

## Suggested implementation steps

1. Write the request function: build the argument list, run the transfer program
   with its status and timing written to a side channel, read that side channel,
   return the record above.
2. Never let the body pass through a shell. Arguments go as a list.
3. Bodies land in the RAM scratch tier first and are moved into the archive only
   once the response is known to be complete, so an interrupted transfer cannot
   leave a truncated file in an append-only archive that never rewrites
   anything.
4. Support conditional requests from the start - sending what the last response
   claimed about its own freshness, and recognising the answer that means
   nothing changed. This is the single largest politeness win available and
   retrofitting it is harder than building it in.
5. Test against a source known to answer, a path known to be absent, and an
   address that does not resolve. All three must produce distinguishable named
   outcomes.
