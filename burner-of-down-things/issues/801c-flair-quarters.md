# 801c — The flair's quarter colours

The third piece of 801: the function every end calls to draw a surface's
midline the same way.

## Current Behavior

No function computes the flair's quarter colours.

## Intended Behavior

A function taking a base colour, returning its four quarter colours:
quarter one a little lighter than the base, quarter four a little darker,
quarters two and three each half lighter, half darker — reading how much
lighter and darker from 801a's look table.

## Suggested Implementation Steps

1. The colour-shift primitive (lighten/darken a colour by an amount).
2. The four-quarter function built from it. **Test:** quarter one lighter
   than the base, quarter four darker, two and three each split; the same
   base colour always gives the same four.

## Blocked by

- 801a
