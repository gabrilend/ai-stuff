#!/usr/bin/env bash
# exit-status.sh -- a sourced library, not run directly.
#
# WHAT (for a CEO): when a stage of the build dies, the pipeline used to print
# "FAILED" and stop there. But the operating system always says HOW a program
# ended, in a single number, and four completely different problems hide behind
# that one word: the program gave up on purpose, somebody interrupted it, the
# machine ran out of memory and shot it, or it crashed. Each needs a different
# response, and the number tells you which -- so print the number, and say what
# it means, instead of discarding both.
#
# HOW: a shell reports a child killed by signal N as 128+N. So a status above 128
# means the program did not choose to stop; subtracting 128 names the signal, and
# the signal names the culprit. Below 128 the program exited under its own power,
# and by our convention 1 means "I gave up and wrote the reason in my log".
#
# WHY IT MATTERS BEYOND THE MESSAGE: a program killed by a signal never runs its
# exit path, so its buffered log output is dropped by the C library rather than
# written. A log that stops mid-sentence is therefore not a mystery -- it is a
# symptom, and one this function names out loud so the reader does not go hunting
# for an error message that was never written.
#
# FUNCTIONS (source this file, then call):
#   describe_exit_status <status>   print a human sentence for a wait() status
#   exit_status_was_signal <status> return 0 if the status means "killed", else 1

# {{{ describe_exit_status()
# Print one or two lines describing how a child process ended.
describe_exit_status() {
    local status="$1"

    if [ "$status" -eq 0 ]; then
        echo "success"
        return 0
    fi

    # 1..128 -- the program returned this itself.
    if [ "$status" -le 128 ]; then
        if [ "$status" -eq 1 ]; then
            echo "exit code 1 — the program stopped itself; its reason should be in the log above"
        else
            echo "exit code $status — the program stopped itself"
        fi
        return 0
    fi

    local signal=$((status - 128))
    local meaning
    case "$signal" in
        2)  meaning="SIGINT — interrupted, usually Ctrl-C" ;;
        6)  meaning="SIGABRT — aborted, usually a failed assertion or allocation" ;;
        7)  meaning="SIGBUS — bad memory access, often a truncated mapped file" ;;
        9)  meaning="SIGKILL — killed outright; the usual sender is the kernel's out-of-memory killer (check with: sudo dmesg | grep -i 'killed process')" ;;
        11) meaning="SIGSEGV — segmentation fault, a crash inside the program or a library it called" ;;
        13) meaning="SIGPIPE — wrote to a pipe whose reader had already gone" ;;
        15) meaning="SIGTERM — another process asked it to shut down" ;;
        *)  meaning="signal $signal" ;;
    esac

    echo "exit code $status = killed by signal $signal ($meaning)"
    echo "         A killed program never flushes its log, so the log may stop mid-sentence."
    return 0
}
# }}}

# {{{ exit_status_was_signal()
# True (0) when the status says the program was killed rather than returned.
exit_status_was_signal() {
    [ "$1" -gt 128 ]
}
# }}}
