# test-destinations.c

Several task queues in the kept engine copy (issue 515i). Built and run by
`run-engine-tests.sh`.

- **The order is the policy:** one worker serving [frame, default] runs the
  frame tasks first, even though the default tasks were handed in earlier.
- **Refusal:** a destination nobody serves is refused at release (checked
  in a child process).
- **Exactly once:** a million tasks over three destinations, from four
  outside threads, in singles and mixed-destination batches, and from inside
  workers. Half the workers serve [1, 2, 0] and half [2, 0]. Every task
  runs once, and the pool stops by itself.

It also ran clean under ThreadSanitizer (clang), 2026-09-25.
