# src/boxes — box sources

Every `.c` file in this directory is a box source. Nothing lists them:
the generator (`src/engine/060-generator.c`) reads whatever is here, so a
box cannot exist that the build did not see, and adding a box is adding a
file (issue 301). These files are never compiled on their own — the
generated catalogue includes each one, which is why the kernel's and the
twin's builds both skip this directory.

## What each thing in a box source becomes

| in a box source file | what it becomes |
|---|---|
| a function anyone can call from outside | **a box**, addressed as `src/boxes/<file>:<function>` |
| a function marked `static` or `inline` | a helper. Not a box. |
| a function named `<type>__compare` | the ordering for `struct <type>`, used by a comparator. Not a box. |
| a struct definition | a value type, with a size and a field table |

## The rules a box keeps

| rule | why |
|---|---|
| every input and the result are integers or value types defined in a box source | the field table is how text in a map becomes bytes |
| a value type is a struct, never a bare pointer | a value on a wire is copied; a pointer would share what it points at |
| a box never returns a string | borrowed memory has no owner; return a struct holding a char array |
| every parameter is named | the name is in every error message |
| no floating point | the kernel is built without it (issue 103f) |
| a box with no inputs is refused | it could never be made to run; give it a trigger input it ignores (issue 310) |
| **a box never remembers anything between calls** | two cores can be inside it at the same instant (issue 209). Not enforced. |
| **a box never blocks** | a core that cannot progress is not running the ten things that are ready. Not enforced. |

## Things the one-file build asks of you

The catalogue is compiled as one C file that includes every box source in
file order. So: define a value type in a lower-numbered file than the files
that use it; do not define the same struct twice; and two files may each
have a function or static helper of the same name (the generator renames
them while each file is included), but not a struct field that shares a
name with another file's function.
