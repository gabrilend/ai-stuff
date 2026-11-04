# 102 — the comfyui client

phase 1, the image call and the run

**Depends on:** 101

## Current behavior

ComfyUI is installed at /mnt/kaun/stable-diffusion and started by its own `run` script; this project cannot talk to it.

## Intended behavior

A Lua module that speaks ComfyUI's HTTP interface on 127.0.0.1:8188: check the server answers (and say how to start it if not — never start it silently), upload an image, queue a workflow graph, wait for its history entry with a time limit, fetch the resulting PNG. JSON through dkjson from /home/ritz/programming/ai-stuff/libs/lua. Every failure carries the server's own message.

## Suggested implementation steps

1. HTTP through luasocket; if luasocket cannot be loaded, stop and say so (no silent curl fallback — a fallback is an error to resolve in this issue).
2. The four calls: system check, upload, queue, wait-and-fetch.
3. Test against a tiny workflow (64×64, 1 step) to prove the round trip.

## Related documents

- docs/datapath-image-call.md
- docs/hardware-and-models.md
