# zip-reader.lua

Reads a received zip (my-libs issue 801; built for rao-chat issue 216e,
shared with rmail #405): the whole structure checked before a
byte is made, then each entry made through zip-inflate's meter into a private
folder. Replaces the unzip program. Runs on LuaJIT and Lua 5.3/5.4.

| function | takes | gives |
|---|---|---|
| `list(path)` | a zip file | entries `{ name, pieces, kind ("file" / "folder" / "link"), method, flags, crc, compressed, size, local_at, data_at, mode (permission bits), unix_time (32 bits or nil) }` in directory order, and their size total; makes nothing |
| `extract(path, folder, options)` | folder: existing and empty; options `{ size (the agreed unpacked total, whole), exact (true: the total must equal size; false: size is a ceiling), now (arrival time), progress (function or nil) }` | the top-level names made |
| `lap_time(stored, now)` | 32 bits of Unix time, the arrival time | the date on the lap at or before `now`, within 2^32 s |

`progress(stats)` is called at most once a second while making and once at
the end: `stats = { entry, entries_done, entries_total, bytes_in,
bytes_out, budget, started, done }`.

What is made:
- files with the sender's permission bits, minus set-user-id, set-group-id
  and sticky, plus owner read and write;
- folders, with their times set last;
- for each symbolic link, a note `<name>.symlink.txt` saying where it
  pointed, never a link.

Refusals (errors `refused <reason>: <detail>`; everything made in the
folder is removed first):
- `damaged`: sizes or offsets outside the file, disagreeing headers, bad
  extra fields, a CRC mismatch;
- `zip64`, `multi-disk`, `encrypted`, `unsupported`: formats our packer
  never writes;
- `bad-name`: an absolute name, a `.`, `..` or empty piece, a backslash, a
  control character, over 241 bytes a piece or 4096 in all, or a name
  outside ASCII without the UTF-8 flag;
- `duplicate`: one path twice, or a file used as a folder;
- `overlap`: entries sharing bytes;
- `special-file`: devices, pipes and sockets;
- `unpacks-larger` / `unpacks-smaller`: the total passes the agreed size
  (or, when exact, falls short of it), or an entry does not make exactly
  its own size.
