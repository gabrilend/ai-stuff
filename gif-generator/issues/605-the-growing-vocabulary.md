# 605 — the growing vocabulary

## Status: open

This is the tracker the `say` tool (604) keeps. Every word it could not
recognise, and that a word session then taught the studio, is listed here,
added in one pass at the end of each `say` run. When new words arrive and
this file has been moved to `issues/completed/`, `say` moves it back and
reopens it.

## Current Behavior

No words have been taught yet. The table below is filled by `say`.

## Intended Behavior

Every word a person reaches for has a file in `words/` saying what it
means, and is listed here with the sentence that first asked for it. A word
listed here is complete when its file loads, expands (for a pattern) into
strokes the wall accepts, and has its test.

## Suggested Implementation Steps

Nothing to do by hand: `say` adds rows. A person may move this file to
`issues/completed/` whenever the list feels done; the next new word
reopens it.

## Words

| Word | Kind | First asked for in | Added |
|------|------|--------------------|-------|
