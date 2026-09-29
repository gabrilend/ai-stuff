# 079-the-parcel.lua

What arrives at the switchboard (docs/068, issue 901a): one or more files
in one folder, read as one unit. Tag parsing (901b), number issuance
(901c) and reuse refusal (901d) are later pieces built on this read.

| Function | In | Out |
|---|---|---|
| `read(folder)` | a switchboard folder's path | `{folder, files = {{name, path}, ...}}`, or `nil` when the folder is missing or empty |
| `tag(p)` | a parcel (from `read`) | a well-formed tag's `number, wish`; `nil` when the first file's first line carries no tag at all (fine, not an error); `nil, finding` when it opens with the tag's words but does not fit the rest (a malformed attempt) |
