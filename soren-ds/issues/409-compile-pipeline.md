# 409 — Compile pipeline

## Current behavior

Every box function in the system is statically linked into the
kernel image. New boxes can only be added by editing kernel
source, rebuilding, and reflashing — exactly the workflow we
promised the user wouldn't have to follow for their own code.
There is no path from a `.c` file on the SD card to a function
pointer the runtime can call.

## Intended behavior

The compile pipeline takes a single C source file and produces a
loadable function pointer. The path:

1. `read-path` reads the source file from the SD card (e.g.,
   `/programs/my-map/src/my-box.c`).
2. A small C compiler embedded in the kernel parses the source,
   generates ARM machine code, and emits the result as a
   relocatable object in RAM.
3. A small linker resolves symbols against the kernel's exported
   symbol table — the box function calls things like
   `debug_write` and accesses `box_args_t`, both of which the
   kernel image exports for box authors.
4. The linker writes the final code into a fresh page from
   108's allocator, marked executable.
5. The pipeline returns the function pointer for the entry
   symbol named in the box's JSON `fn` field.

The compiler implementation is the heaviest piece of work in
phase 4. Options include embedding a real C compiler such as
TCC (small, embeddable, ARM target available) or building a
minimal C-subset compiler tailored to box semantics (about a
month of careful work, but tighter for our needs). The choice is
made during implementation; the issue commits only to the
external behavior.

The pipeline's *outputs* land in the artifact tree managed by
410 — one directory per box per generation. The function pointer
the pipeline returns is registered in 208's descriptor table at
the next generation; the hot-swap from 411 atomically updates
the descriptor's `fn` field to the new function pointer.

The compile pipeline fails cleanly. A syntax error in the source
returns a structured error to the caller with the line and
column. A linker failure returns a structured error naming the
unresolved symbol. Crashes inside the compiler are bugs; the
panic handler (105) catches them and the run continues without
the new generation.

## Suggested implementation steps

1. Pick the compiler implementation. Document the choice in
   `notes/compile-pipeline/000-compiler-choice.md`.
2. Embed it into the kernel build.
3. `compile_box_source(path, out_function_ptr)` — orchestrates
   the four steps above.
4. Exported symbol table for the linker to resolve against.
5. Error propagation back to the caller.

## Related documents

- `docs/012-soramech-runtime.md` — compile pipeline section.

## Blocked by

108, 406 (read-path is how the source comes in).

## Blocks

410, 411, 412.
