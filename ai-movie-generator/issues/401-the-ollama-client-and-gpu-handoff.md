# 401 — the ollama client and gpu handoff

phase 4, the writers' room

**Depends on:** 101

## Current behavior

No language model is called.

## Intended behavior

A Lua module calling ollama on 127.0.0.1:11434: generate (with a model name and system instructions), embed, and unload (`keep_alive: 0`). The pipeline unloads the model before ComfyUI work begins, so the two never hold the graphics card together.

## Suggested implementation steps

1. The three calls.
2. Test: generate a one-word answer; embed two phrases; unload and confirm with `ollama ps`.

## Related documents

- docs/datapath-writers-room.md
- docs/hardware-and-models.md
