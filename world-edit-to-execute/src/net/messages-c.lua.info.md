# messages-c.lua

Prints `net-messages.h`, the C reader of every gameplay message, from the
descriptions in `messages.lua` (issue 804), so the C side can't drift from
the Lua side. **Usage:** `luajit messages-c.lua DIR > net-messages.h`.

Per message NAME the header has `NET_NAME` (its type byte), `net_NAME` (a
struct: one field per description field as `uint8_t`/`uint16_t`/`uint32_t`/
`float`; per list LIST a caller-owned array pointer `LIST`, `LIST_room` set
by the caller, `LIST_count` set by the reader, records `net_NAME_LIST`), and
`net_decode_NAME(bytes, length, out) -> NULL or why refused` (another
message, ends early, bytes left over, more records than room). Refuses to
generate a list inside a list.
