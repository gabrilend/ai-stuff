# 018-launch-board — info

Boots a described board in its emulator. The one command that gets run more
than any other in the project; issue 701 is its blueprint.

Treat it as a black box: name a board, hand it things, get a running machine
whose serial wire lands in a log file in RAM.

## Invocation

```
luajit src/018-launch-board.lua <board> [options]
```

`<board>` is the part after `-board-` in a `src/*-board-*.lua` filename
(`qemu-x86-64`, `qemu-arm64`, `qemu-riscv64`), or a path to a description.

| Option | Value | What it does |
|---|---|---|
| `--payload` | file | attach something to boot, the way this board's firmware finds payloads |
| `--disk` | file | attach as this board's storage controller (ahci / nvme / usb) |
| `--memory` | name or size | a named size from the board (`small`, `plenty`) or a literal like `512M`; default `small` |
| `--seconds` | number | kill the machine after this long — for tests, where running forever is correct |
| `--stdio` | — | serial to the terminal instead of the log file |
| `--watch` | optional `gtk`, `sdl` or `curses` | show the machine's screen while it runs. Bare, it opens a window where there is a display server and draws in this terminal where there is not, saying which. `curses` draws the guest's screen over your terminal, which is the better rendering for the boards that run in text mode and the only one that works over a connection with no display |
| `--gdb` | — | freeze at the first instruction, wait for a debugger on `:1234` |
| `--accel` | — | hardware acceleration when guest and host share an architecture; declined out loud otherwise |
| `--dry-run` | — | print the generated command, run nothing |
| `--dir` | path | project root override |

## Behaviour worth knowing

- Reads `input/launch-defaults.lua` first (a table of option defaults; the
  command line wins). Writes `output/goodbye` last, with the run's outcome.
- Ensures the RAM directories and the `tmp/` symlinks exist before writing.
- Serial log: `tmp/shared-memory/logs/<board_id>-serial.log`.
- **No window unless asked, and that default is load-bearing.** Every test here
  boots machines unattended; a window nobody asked for on a build machine is a
  hang rather than a picture. The framebuffer device exists either way and can
  be photographed through the monitor afterwards — `none` only means nobody is
  watching live.
- **`--watch curses` and `--stdio` both want this terminal**, so asking for both
  declines the second and says so: the screen wins, because that is what was
  asked for, and the words go to the log file where they are never lost.
- `--watch` followed by a word that is not a backend is refused rather than
  guessed at, so `--watch vga` does not quietly become a window.
- A `--seconds` run that uses its whole allotment reports "ran its full Ns" —
  the machine surviving, not failing. Exit code 124 is that, not an error.
- `-no-reboot` is always passed: a triple-faulting x86 payload would
  otherwise reboot in a loop forever.

## Internal shape (for the curious)

Two dispatch tables do the real work: one attacher per way a firmware finds
its payload (`boot-sector`, `loader-device`), one per storage controller
(`ahci`, `nvme`, `usb-storage`). Adding a kind is adding a row, never an
if-chain. Every shell command runs alone — no chains, no pipes.
