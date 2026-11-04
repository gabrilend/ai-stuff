# exit-status.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/exit-status.sh: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
exit-status.sh -- a sourced library, not run directly.
project-dir: none -- it takes no command line; the script sourcing it reads --dir.

WHAT (for a CEO): when a stage of the build dies, the pipeline used to print
"FAILED" and stop there. But the operating system always says HOW a program
ended, in a single number, and four completely different problems hide behind
that one word: the program gave up on purpose, somebody interrupted it, the
machine ran out of memory and shot it, or it crashed. Each needs a different
response, and the number tells you which -- so print the number, and say what
it means, instead of discarding both.

HOW: a shell reports a child killed by signal N as 128+N. So a status above 128
means the program did not choose to stop; subtracting 128 names the signal, and
the signal names the culprit. Below 128 the program exited under its own power,
and by our convention 1 means "I gave up and wrote the reason in my log".

WHY IT MATTERS BEYOND THE MESSAGE: a program killed by a signal never runs its
exit path, so its buffered log output is dropped by the C library rather than
written. A log that stops mid-sentence is therefore not a mystery -- it is a
symptom, and one this function names out loud so the reader does not go hunting
for an error message that was never written.

FUNCTIONS (source this file, then call):
  describe_exit_status <status>   print a human sentence for a wait() status
  exit_status_was_signal <status> return 0 if the status means "killed", else 1

Print one or two lines describing how a child process ended.
```

## Functions

### `describe_exit_status()`

```
Print one or two lines describing how a child process ended.
```

### `exit_status_was_signal()`

```
True (0) when the status says the program was killed rather than returned.
```
