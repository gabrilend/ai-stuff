# 807d — Prose templates

The fourth piece of 807.

## Current Behavior

No prose rendering exists.

## Intended Behavior

Canvas word `prose`: a template string with `{{slot}}` marks (034's own
slot syntax) filled from the canvas's data; a missing slot is a finding,
never rendered blank.

## Suggested Implementation Steps

1. A slot-fill function matching 034's `fill` shape.
2. The missing-slot finding. **Test:** a template with every slot filled
   matches exactly; a missing slot is a finding, never a blank.

## Blocked by

- 807a
