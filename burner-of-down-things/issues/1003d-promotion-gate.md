# 1003d — The promotion gate

The fourth piece of 1003.

## Current Behavior

Nothing distinguishes a draft from a kept strategem.

## Intended Behavior

A draft becomes a strategem only when the person moves it
(`strategems/drafts/x.md` → `strategems/x.md`); the machine never
promotes its own draft.

## Suggested Implementation Steps

1. A promotion command the person runs. **Test:** a draft never appears
   in `strategems/` without that command having been run by a person's
   own invocation, never from within the drafting turn itself.

## Blocked by

- 1003c
