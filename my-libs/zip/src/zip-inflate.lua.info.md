# zip-inflate.lua

Follows a zip entry's recipe, one instruction at a time, under a meter
(my-libs issue 801; built for rao-chat issue 216e). A deflated stream is a list of "write these bytes" and "copy
N bytes from D back"; a zip bomb is the second repeated. Every instruction
is counted before its bytes are made, so nothing past the budget ever
exists. Built after Mark Adler's puff.c (bit-at-a-time canonical Huffman
decoding, every malformed table refused by name).

| function | takes | gives |
|---|---|---|
| `run(method, read, sink, budget)` | method 0 (stored) or 8 (deflated); `read(n)` → up to n bytes of the entry's compressed data or nil at its end; `sink(bytes)` receives made bytes as a string, up to 32 KiB at a time; budget: the most bytes allowed | bytes made (number), their CRC-32 (0 .. 2^32-1), bytes read |
| `crc32_string(crc, text)` | a running CRC (start 0) | the CRC continued, 0 .. 2^32-1 |
| `same_crc(a, b)` | two CRCs, signed or unsigned | bool |

Refusals are errors whose text starts `refused <reason>: `:
`unpacks-larger` (the budget would be passed), `damaged` (reserved block
type, a copy from before the start, over-full or incomplete code tables,
codes that do not exist, a stream cut short or with bytes after its end),
`unsupported` (any method but 0 or 8).
