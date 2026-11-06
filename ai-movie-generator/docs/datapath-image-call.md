# Datapath — the image call

How one line of picture description becomes one PNG file on disk.

## In

A **picture request**, a Lua table:

| field | type | meaning |
|---|---|---|
| prompt | string | what is in the picture |
| negative | string | what must not be (defaults to the house negative, `EasyNegative` plus a short list) |
| seed | integer | the random starting noise; same seed + same prompt = same picture |
| width, height | integer | pixels, multiples of 64; default 768×432 (16:9 at SD 1.5's native scale) |
| steps | integer | sampling steps; default 20 |
| guidance | number | how strictly the picture follows the prompt (CFG); default 7.0 |
| init_image | string path, optional | start from this picture instead of noise (image-to-image) |
| strength | number 0–1, optional | with init_image: how much may change (0.25 = drift, 0.6 = reimagine) |
| control | table, optional | `{ kind = "depth" \| "openpose" \| …, image = path, weight = number }` |

## Through

1. **A workflow template is chosen.** Templates live in `assets/workflows/`
   as API-format JSON with placeholder strings (`__PROMPT__`, `__SEED__`,
   `__INIT_IMAGE__`, …). There is one template per *shape* of request:
   text-to-image, image-to-image, text-to-image-with-control. A dispatch
   table maps the request's shape to its template — no if/else chain.
2. **Placeholders are filled.** Each placeholder is replaced by the request's
   value. Placeholders, not node-hunting: a graph with a positive and a
   negative text node has two places a prompt could go, and only the
   placeholder says which one is meant (this reasoning comes from
   /mnt/kaun/stable-diffusion/workflows/README.md).
3. **Input images are uploaded.** An init or control image is sent to
   ComfyUI's `/upload/image` first; the returned name replaces its
   placeholder.
4. **The graph is queued.** POST to `/prompt` returns a prompt id.
5. **The call waits.** Poll `/history/<prompt id>` until the entry appears
   (or listen on the websocket). A time limit applies; running out is an
   error, never a silent empty result.
6. **The picture is fetched.** `/view?filename=…` returns the PNG bytes,
   which are written to the run folder.

## Out

- the PNG, named `<shot id>-<keyframe index>.png`;
- a line appended to the run's **render log** in `tmp/shared-memory/<run>/`:
  request fields, seconds taken, prompt id. The log is how speed is measured;
  documentation points at it instead of quoting numbers.

## Failure

ComfyUI not running, model missing, time limit reached, or a node error in
the response: the call stops with the server's own message. No retry with
different settings, no substitute picture.
