# cache.lua

A least-recently-used cache charged in bytes (issue 601), used by
`loader.lua`.

| Function | Takes | Gives |
|----------|-------|-------|
| `cache.new(limit)` | the byte limit (0 or more) | a cache |
| `c:put(key, value, bytes)` | an entry and what it costs | true when kept; evicts the entries used longest ago to fit; an entry bigger than the whole limit isn't kept (false) |
| `c:get(key)` | a key | the value, or nil; counts a hit or a miss and marks the entry just used |
| `c:has(key)` | a key | true when present (not marked used, not counted) |
| `c:peek(key)` | a key | the value and what it was charged, or nil (not marked used, not counted; issue 606) |
| `c:remove(key)` | a key | true when it was there |
| `c:keys()` | — | the keys, most recently used first |
| `c:stats()` | — | `{count, bytes, limit, hits, misses, evictions}` |
| `c:clear()` | — | empties it (the counters stay) |
