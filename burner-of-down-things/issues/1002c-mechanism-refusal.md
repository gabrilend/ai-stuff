# 1002c — Mechanism refusal

The third piece of 1002.

## Current Behavior

Any lesson is accepted.

## Intended Behavior

A lesson without a mechanism is sent back — a mood ("the build was bad")
is not a mechanism ("a builder grading its own work passes itself"),
docs/069.

## Suggested Implementation Steps

1. The mood-vs-mechanism check (a mechanism names an actor and a
   consequence; a bare judgement word is refused). **Test:** a lesson
   with no mechanism is refused; one with a mechanism is kept.

## Blocked by

- 1002a
