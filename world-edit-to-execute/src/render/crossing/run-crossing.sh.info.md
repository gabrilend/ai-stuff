# run-crossing.sh

Builds the crossing demo (generates `net-messages.h`, compiles with LuaJIT,
the mailbox and raylib), then checks it on a clean connection and on one
with 100 ms delay, 60 ms jitter and 20% loss, and takes two pictures (the
crossing, and the waiting dialog). With `window`, opens the window.

- **Usage:** `run-crossing.sh [DIR] [window]`; writes
  `tmp/shared-memory/crossing/check.txt`, `shot.png`, `shot-paused.png`.
