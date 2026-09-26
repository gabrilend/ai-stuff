# 013-paths.lua

Where everything is. Every path the machine uses is built from the one
project folder (DIR) here, so no module invents a path from a string.

| Function | In | Out |
|---|---|---|
| `for_project(dir)` | absolute project folder (string) | table of absolute paths (strings): `dir`, `src`, `tests`, `fixtures`, `cases`, `input`, `output`, `docs`, `scratch` (RAM artifacts), `exec_scratch` (RAM, executable), `house_scripts`, `validate_issues`, `init_project`, `skills`, `thread_library_build` |
| `set_search_path(dir)` | absolute project folder | nothing; makes `require "NNN-name"` find `src/` and `libs/`, and the thread library loadable |

Refuses a relative project folder: every path would then depend on where the
machine was started.
