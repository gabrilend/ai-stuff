# 1002 — Pitch of a spoken sentence

**Phase:** 10 — The machine answers
**Blocked by:** none
**Blocks:** 1004
**Related documents:** delta-version issue 066

## Current Behavior

Nothing measures voice pitch.

## Intended Behavior

Short sentiment sentences are spoken or transcribed; each sentence's pitch
register (low, middle, high of the speaker's range) becomes one value, or a
stream of values across the sentence, written as signal chunks (1001). It is
one source among any that speak the contract.

## Suggested Implementation Steps

1. Record or load audio; split on pauses into sentences.
2. Measure pitch per short frame; place it within the speaker's own range.
3. Write the values as chunks.
