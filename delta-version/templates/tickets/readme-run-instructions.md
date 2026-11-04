# Issue ][ticket_id[]: Check the README Says How to Run ][project_name[]

## Current Behavior

This ticket was filed into every project chosen for it on ][current_date[] by
the ticket distribution system (delta-version issue 019). Some of those
projects have a README that does not say how to build or run them.

## Intended Behavior

`README.md` in ][project_name[] says, near the top:

- what the project needs installed;
- the one command that builds it, if it needs building;
- the one command that runs it, or its tests.

## Suggested Implementation Steps

1. Read the README and the project's run scripts.
2. If the README already says all three, close this ticket in a line.
3. Otherwise add a short "Running" section, with commands that work from the
   project's own folder.

## Metadata

- **Priority**: Low
- **Dependencies**: None
