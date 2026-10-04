#!/usr/bin/env bash
# exit-status.test.sh -- exercises scripts/exit-status.sh.
# Run: bash scripts/exit-status.test.sh [project-dir]
#
# Why this exists. A full embedding run died at 85% and the pipeline reported
# only "GENERATION FAILED". The log ended mid-sentence with no error in it, and
# there was no way to tell whether the program had given up, been interrupted,
# been shot by the out-of-memory killer, or crashed -- four different problems,
# one word. The status number distinguishing them was captured and discarded.
#
# The second half of this file kills real processes and reads back the status the
# shell reports, because the 128+N convention is the load-bearing assumption and
# asserting it against the actual kernel is the only way to know it holds here.

set -u

# {{{ setup_dir_path()
setup_dir_path() {
    if [ "$#" -gt 0 ] && [ -n "$1" ]; then echo "$1"; return; fi
    cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}
# }}}

DIR="$(setup_dir_path "${1:-}")"
# shellcheck source=/dev/null
source "${DIR}/scripts/exit-status.sh"

pass=0; fail=0

# {{{ check() -- assert the description CONTAINS a fragment
check() { # check <label> <status> <expected fragment>
    local got
    got="$(describe_exit_status "$2")"
    if [[ "$got" == *"$3"* ]]; then
        pass=$((pass+1)); echo "  ok   - $1"
    else
        fail=$((fail+1)); echo "  FAIL - $1"; echo "         got: $got"; echo "         want to contain: $3"
    fi
}
# }}}

# {{{ check_eq()
check_eq() { # check_eq <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}
# }}}

echo "exit-status decoding"

# {{{ the statuses a program returns for itself
check "0 is success"                 0   "success"
check "1 points at the log"          1   "reason should be in the log"
check "1 names the code"             1   "exit code 1"
check "2 is a plain self-exit"       2   "stopped itself"
check "128 is still a self-exit"     128 "stopped itself"
# }}}

# {{{ the statuses that mean somebody else stopped it
check "130 is SIGINT"                130 "SIGINT"
check "137 names the OOM killer"     137 "out-of-memory killer"
check "137 says how to check"        137 "dmesg"
check "139 is a segfault"            139 "SIGSEGV"
check "143 is SIGTERM"               143 "SIGTERM"
check "unknown signal still decodes" 190 "killed by signal 62"
check "a kill warns about the log"   137 "may stop mid-sentence"
# }}}

# {{{ exit_status_was_signal draws the line at 128
exit_status_was_signal 1   && r=yes || r=no; check_eq "1 is not a signal"   "$r" "no"
exit_status_was_signal 128 && r=yes || r=no; check_eq "128 is not a signal" "$r" "no"
exit_status_was_signal 129 && r=yes || r=no; check_eq "129 is a signal"     "$r" "yes"
exit_status_was_signal 137 && r=yes || r=no; check_eq "137 is a signal"     "$r" "yes"
# }}}

# {{{ against the real kernel, not just the arithmetic
# Kill actual processes and read back what the shell reports, so the 128+N
# convention this file rests on is verified rather than assumed.
echo ""
echo "against real processes"

sh -c 'exit 3' & wait $! ; got=$?
check_eq "a real exit(3) reports 3" "$got" "3"

sleep 30 & victim=$!
kill -9 "$victim" 2>/dev/null
wait "$victim" 2>/dev/null; got=$?
check_eq "a real SIGKILL reports 137" "$got" "137"
check "and decodes as the OOM suspect" "$got" "out-of-memory killer"

sleep 30 & victim=$!
kill -TERM "$victim" 2>/dev/null
wait "$victim" 2>/dev/null; got=$?
check_eq "a real SIGTERM reports 143" "$got" "143"

# The mechanism behind the log that ended mid-sentence, demonstrated: a program
# whose output is redirected to a file buffers in blocks, and a program that is
# killed never flushes that buffer. Write far LESS than one block (so nothing is
# forced out by a full buffer), leave the writer alive, kill it, and the file is
# empty -- every line it "wrote" is gone.
#
# The probe is luajit itself, because luajit is what the embedding run uses and
# its buffering is the behaviour under test. It prints ten lines, then blocks
# reading a pipe that will not deliver for 30 s -- alive, with its output still
# in hand. We kill it there. Nothing must flush in between, which is why it
# blocks on a read rather than calling sleep: a subprocess call would flush on
# the way out and quietly prove nothing.
buffer_probe="$(mktemp)"
sleep 30 | luajit -e 'for i = 1, 10 do print("line " .. i) end io.read("*l")' > "$buffer_probe" &
probe=$!
sleep 0.5
pkill -9 -P "$probe" 2>/dev/null
kill -9 "$probe" 2>/dev/null
wait "$probe" 2>/dev/null
written=$(wc -l < "$buffer_probe")
check_eq "a killed writer's buffered lines never reach the file" "$written" "0"
rm -f "$buffer_probe"

# The same probe with the prologue generate-embeddings.sh now installs. Ten lines
# written, ten lines kept, through exactly the same kill.
buffer_probe="$(mktemp)"
sleep 30 | luajit -e 'io.stdout:setvbuf("line") for i = 1, 10 do print("line " .. i) end io.read("*l")' > "$buffer_probe" &
probe=$!
sleep 0.5
pkill -9 -P "$probe" 2>/dev/null
kill -9 "$probe" 2>/dev/null
wait "$probe" 2>/dev/null
written=$(wc -l < "$buffer_probe")
check_eq "line buffering keeps every one of them" "$written" "10"
rm -f "$buffer_probe"
# }}}

echo ""
echo "exit-status: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
