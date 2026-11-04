# stethoscope

A mailbox in RAM that lets one Claude Code session ask another a question and
get the answer back, with no person relaying it.

## What it is for

Two sessions in two terminals cannot see each other. When one of them meets a
piece of data it does not know how to handle, and the other is the one that
knows (it wrote the format, it owns the project), this carries the question
across and the answer back.

Listening is a diagnostic, not standing equipment: a listening session spends a
turn on every question it hears. So a session may listen **only when the person
has written a permit for it**, by typing `! stethoscope permit NAME` themselves.

## The mailbox

Under `/dev/shm/claude-stethoscope/` (override with `--dir`), one folder per
listener name:

| path | what it holds |
|---|---|
| `NAME/permit` | present while the person allows NAME to listen |
| `NAME/inbox/ID` | a question nobody has heard yet |
| `NAME/heard/ID` | a question a listener has taken |
| `NAME/replies/ID` | the answer to question ID |

An ID is the arrival time in seconds, the sending process's id and a random
number, so names sort roughly by arrival. Every file is written under a hidden
temporary name and renamed into place, so a reader never sees half a message.

## Commands

    stethoscope permit NAME
        The person allows NAME to listen. A session never runs this itself.

    stethoscope stop NAME
        Withdraws the permit; also ends a listen already running.

    stethoscope listen NAME [--patience SECONDS]
        Waits for the oldest unheard question, prints it with its ID and the
        command to answer it, files it as heard, and exits. One question per run.

    stethoscope ask NAME [--patience SECONDS] < question
        Sends the question and waits for its answer, then prints the answer.

    stethoscope send NAME < question          prints the ID, does not wait
    stethoscope await NAME ID [--patience SECONDS]
    stethoscope reply NAME ID < answer        only for a question already heard
    stethoscope who                            names, permitted or de-permitted,
                                               and how many questions wait

Patience defaults to an hour. Waiting is done by looking at the folder twice a
second (this machine has no `inotifywait`).

## Exit status

0 done · 1 refused or misused · 2 waited and nothing arrived. A wait that runs
out is never reported as an answer.

## Tests

`tests/test-stethoscope.sh` — works in a throwaway mailbox, so it grants no real
permit.
