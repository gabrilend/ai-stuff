# zip-writer.lua

Packs a file or folder into a zip of our own (my-libs issue 801; built for
rao-chat issue 216e, shared with rmail #405), replacing the zip
program. It writes only what zip-reader accepts. Runs on LuaJIT and Lua
5.3/5.4; lists trees with GNU `find -printf` (not macOS or BSD).

| function | takes | gives |
|---|---|---|
| `pack(path, zip_path)` | a file or folder (followed once if it is itself a link), where to write | `{ size = the exact unpacked total (files plus link targets), entries = count }` |

What it writes:
- every entry stored for now (compression is rao-chat issue 217);
- names relative to the packed path's parent, with the UTF-8 flag set;
- sizes and CRC in the local header (the CRC is patched in once the bytes
  are read);
- Unix permission bits and file type in the external attributes;
- the modified time as Unix time modulo 2^32 in the extended-timestamp
  field (it loops past 2038);
- links below the packed path stored as links, never followed;
- empty folders as `name/` entries.

It errors, and removes the half-made zip, when:
- a file changed while it was packed (the tree is listed before and
  after, and the bytes read are compared with the listed size);
- it meets a device, pipe or socket;
- a file is 4 GiB or more, the zip reaches 4 GiB, or the tree holds
  65,535 entries or more (volumes: rao-chat issue 216f).
