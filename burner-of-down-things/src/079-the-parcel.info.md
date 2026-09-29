# 079-the-parcel.lua

What arrives at the switchboard (docs/068, issue 901a): one or more files
in one folder, read as one unit. Tag parsing (901b), number issuance
(901c) and reuse refusal (901d) are later pieces built on this read.

| Function | In | Out |
|---|---|---|
| `read(folder)` | a switchboard folder's path | `{folder, files = {{name, path}, ...}}`, or `nil` when the folder is missing or empty |
