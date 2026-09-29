# 901b — Tag parsing

The second piece of 901.

## Current Behavior

No tag is read.

## Intended Behavior

A tag is a parcel's first line, `language model prompt <number>: <what is
wanted>`. A malformed first line is a finding showing the right form, not
a crash; a parcel with no tag at all is still accepted — the router works
it out from contents alone (902/904).

## Suggested Implementation Steps

1. The tag pattern and its parser. 2. The malformed-tag finding.
   **Test:** a well-formed tag's number and wish are read; a malformed one
   is a finding naming the right form.

## Blocked by

- 901a
