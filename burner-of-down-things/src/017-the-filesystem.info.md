# 017-the-filesystem.lua

The folder operations LuaJIT lacks, done with the standard tools, and the one
place paths are quoted for a shell.

| Function | In | Out |
|---|---|---|
| `quote(s)` | string | the string single-quoted for a POSIX shell |
| `run(command)` | shell line | true when it exited 0 |
| `capture(command)` | shell line | its standard output (string), and whether it exited 0 |
| `exists(path)` / `is_folder(path)` | path | boolean |
| `make_folder(path)` | path | makes it and its parents, or refuses |
| `list(path)` | folder | sorted array of names inside it, hidden ones included; refuses a missing folder |
| `read(path)` / `write(path, text)` | path | whole-file read; whole-file write through a neighbour file and a rename |
| `remove_tree(path)` | absolute path of 12+ characters | removes it; refuses anything short enough to be a mistake |
| `real_path(path)` | path | the path with links resolved, or nil if it does not exist |
