# calibrate.c

Prints how many rounds of `churn` make a microsecond on this machine (best of
five 50-million-round timings). `run-frame.sh` passes the number to every
program as `ROUNDS_PER_US`.
