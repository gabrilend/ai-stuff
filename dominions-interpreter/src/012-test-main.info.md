# 012-test-main.lua

Runs every test module and reports in sentences. Run it through `./tests-run`.

A test module is picked up by being listed in the table at the top and needs
only to expose `run(check, home)`. Tests are cheap and there should be many, so
adding one has to cost nothing.

Passes are counted, not printed — a suite that prints a line per success buries
the one line that matters. Failures are collected and listed at the end with
what did not hold.

`home` is the Dominions folder, passed through from the shell script, which
finds it in `input/game` when it is not given one. Without it the suite still
runs and says which parts it skipped, so a machine with no game installed can
still check the parts that do not need one.
