# 807c — Box diagrams

The third piece of 807: the `.txt` twin of the `.png` diagram (805c).

## Current Behavior

No ascii box-diagram rendering exists.

## Intended Behavior

Canvas word `box-diagram`: boxes drawn from line characters, arrows routed
between named boxes with a label at either end (`there — here`), the same
shape as the `.png` diagram but in text, measured in characters.

## Suggested Implementation Steps

1. The box-drawing primitive (corners, sides, measured in characters).
2. Arrow routing between two boxes with there/here labels. **Test:** a
   two-box diagram with one arrow matches a stored expected file byte for
   byte.

## Blocked by

- 807a
