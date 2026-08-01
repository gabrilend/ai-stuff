# 001-input-test.lua

Proves the input gate. Exposes `run(check, home)`; `home` is a Dominions folder
and the checks that need one are skipped when it is absent.

The cases worth having are the refusals: a malformed settings line is refused
with its line number, a path that does not exist is refused with its key named,
an unknown door kind is refused by name, and a savegame folder holding several
turn files comes back as candidates rather than as a choice.
