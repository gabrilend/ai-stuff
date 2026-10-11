<!-- written by Claude (Opus 5.5), 2026-10-10, for the first renderer slice: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 009-soramech-worker

A worker thread's body. Takes tasks from the "soramech-pool" channel (first come, first served), runs the box for the task's station against shared memory, reports the station on "soramech-done". Stops on the string "stop". Set up once from the "worker-setup" channel (see the file's header for the table's layout). Offers nothing to require.
