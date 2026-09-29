# 081-the-shape-types.lua

The closed list of shape types, and recognisers for the three simplest
(docs/068, issue 902a). Structured types (902b) and the remaining five
plus `unknown` (902c) extend the same `recognise()` dispatch.

| Function | In | Out |
|---|---|---|
| `recognise(bytes)` | a parcel file's bytes | `"integer-array"`, `"number-array"` or `"text"`, tried in that order; `nil` when none match (902b/902c try next) |
| `TYPES` | | the closed list of every shape type's name |
