# Issue 065g: The Guide

**Status**: Open
**Parent**: 065-the-reading-walk.md
**Dependencies**: 065d, 065e, 065f
**Blocks**: None

## Current Behavior
The walk follows index order only.

## Intended Behavior
A local AI, whichever is installed, chooses each next move from the current
stop, the reader's recent actions and the stops ahead: next, step back to a
foundation, show more, or summarize. It never asks a question whose answer is
judged.

## Suggested Implementation Steps
1. Local model client (scripts/libs/llama-chat-client.lua).
2. Choice prompt and parsing; the walk of 065d takes the guide's choice.
3. Trail entries through 065e and 065f.
