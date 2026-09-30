# zip

A zip packer and a zip reader in plain Lua, shared by rao-chat and rmail
so that neither calls the `zip` or `unzip` programs. It runs unchanged on
LuaJIT and on Lua 5.3/5.4; every difference between them lives in
`src/zip-compat.lua`.

The reader treats a zip as what it is, a recipe written by someone else.
It checks the whole structure before making a single byte:
- names that climb out of the folder or start at the root;
- entries that share bytes (the overlapping bomb);
- devices, pipes and sockets;
- encryption, ZIP64 and multi-disk archives;
- headers that disagree with each other.

It then follows each entry's compressed instructions one at a time,
counting every byte before it is made, so a zip bomb stops at the agreed
size before its excess exists. Any refusal removes everything made.
Symbolic links arrive as a one-line `<name>.symlink.txt` note, never as
links. Dates travel as Unix time that loops past 2038.

The packer writes stored zips that the system `unzip` accepts and extracts
identically. It counts the unpacked size exactly, and fails if a file
changes while being read.

## Files

| file | what |
|---|---|
| `src/zip-compat.lua` | bit operations, byte buffers, folders, permissions and times on either interpreter |
| `src/zip-inflate.lua` | stored and deflated entries under a meter (after puff.c) |
| `src/zip-reader.lua` | `list(path)`, `extract(path, folder, options)`, `lap_time(stored, now)` |
| `src/zip-writer.lua` | `pack(path, zip_path)` |
| `tests/test-zip.lua` | 23 checks: round trips, hand-built hostile zips, compression-table damage |
| `tests/run-tests` | runs the checks under every interpreter present |

Each source file has a `.info.md` beside it with its functions, inputs and
outputs.

## Using it

Link the four source files into a project's `libs/` folder (which is on
the project's `package.path`), then `require("zip-reader")` and
`require("zip-writer")`:

    ln -s /home/ritz/programming/ai-stuff/my-libs/zip/src/zip-*.lua <project>/libs/

Consumers: rao-chat (`src/attachments/`, issue 216e) and rmail (#405).

## Not yet

- Compression when packing (rao-chat issue 217). The reader already follows
  it.
- Files of 4 GiB or more, and trees of 65,535 entries or more (volumes,
  rao-chat issue 216f). The packer refuses them loudly.
- macOS and BSD: the packer lists trees with GNU `find -printf`.

History: my-libs issue 801.
