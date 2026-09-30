# zip-compat.lua

The one place LuaJIT and Lua 5.3/5.4 differ, for the zip library. The
library's other files use only what this file gives them.

| name | takes | gives |
|---|---|---|
| `band`, `bor`, `bxor`, `lshift`, `rshift`, `bnot` | 32-bit whole numbers | the operation: LuaJIT's `bit` (results signed), or 5.3+'s operators (built with `load`, results unsigned) |
| `u32(n)` | any 32-bit result | the same bits as 0 .. 2^32-1 (compare only through this) |
| `int(n)` | a whole number | an integer on 5.3+, the number itself on LuaJIT |
| `new_window(size)` | a length | a zeroed byte buffer indexed from 0: an FFI `uint8_t` array, or a table |
| `window_string(window, length)` | a buffer, how many bytes | its first bytes as a string |
| `mkdir(path, mode)` | | true when made, false when already there |
| `chmod(path, mode)` | | nothing; an error when it cannot |
| `set_time(path, seconds)` | any whole number (before 1970, after 2038) | nothing; an error when it cannot |
| `exists(path)` | | bool (a file or a folder) |
| `quote(path)` | | the path quoted for the shell |

On LuaJIT, folders, permissions and times are direct system calls through
FFI (`mkdir`, `chmod`, `utimes`). On 5.3/5.4 they are `mkdir`, `chmod`
and `touch -d @N` run through the shell, one process per call. Plain Lua
5.1/5.2 without `bit` are refused when the library loads.
