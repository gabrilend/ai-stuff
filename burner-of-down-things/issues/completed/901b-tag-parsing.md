# 901b — Tag parsing

The second piece of 901.

## Current Behavior

Built. `src/079-the-parcel.lua`'s `tag(p)` reads a parcel's first file's
first line: a well-formed tag returns `number, wish`; a line that does not
open with the tag's own words at all returns `nil` (no tag, ordinary); one
that opens with them but does not fit the rest returns `nil, finding`,
naming the right form. A `%f[%A]` word-boundary check keeps a word like
"promptly" from misreading as an attempted, malformed tag. Checked by
`tests/101-checking-tag-parsing.lua`.

## Intended Behavior

A tag is a parcel's first line, `language model prompt <number>: <what is
wanted>`. A malformed first line is a finding showing the right form, not
a crash; a parcel with no tag at all is still accepted — the router works
it out from contents alone (902/904).

## Suggested Implementation Steps

1. The tag pattern and its parser. Done: `079-the-parcel.lua`'s `tag`.
2. The malformed-tag finding. Done. **Test:** a well-formed tag's number
   and wish are read; a malformed one is a finding naming the right form.
   Done.

## Blocked by

- 901a
