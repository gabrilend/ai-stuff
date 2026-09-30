# ComfyUI workflows for game art

Workflow files for ComfyUI that make art this engine can use (issue 522f).
They use only ComfyUI's own nodes: no custom node packs, no Python of ours.
Every node's sockets and controls were checked against ComfyUI's source
(commit `a716932`, 2026-09-29).

Each workflow comes in two shapes, because ComfyUI reads two that aren't
interchangeable:

| File | For |
|------|-----|
| `workflows/<name>.ui.json` | the editor: drag it onto the canvas |
| `workflows/<name>.api.json` | scripts: post it to `/prompt` |

## The workflows

| Name | Makes | Needs |
|------|-------|-------|
| `icon` | a command-card icon: 512 px, and the same scaled to 64 × 64 (WC3's button size) | a checkpoint |
| `ground-tile` | a top-down ground texture (seamless tiling is the engine's own post-pass) | a checkpoint |
| `portrait-art` | a character picture for a portrait or loading screen | a checkpoint |
| `texture-restyle` | an existing texture redrawn from a prompt, its layout kept (image to image, denoise 0.45) | a checkpoint, `wete-texture.png` in ComfyUI's `input/` |
| `texture-restyle-lines` | the same, its outlines held by a Canny ControlNet (for model skins, whose UV islands must stay put) | a checkpoint, a Canny ControlNet, `wete-texture.png` |
| `model-from-image` | a 3D model (GLB) from one picture, with ComfyUI's built-in Hunyuan3D 2 nodes | the Hunyuan3D 2 checkpoint, `wete-concept.png` |

## Model names

`settings.lua` names the model files the workflows load. Rename them to
what your ComfyUI has under `models/`, then write the workflows again:

    luajit src/assets/comfy.lua write

## Checking against your ComfyUI

ComfyUI changes. To confirm every node and input still exists in the one
you run:

    curl http://127.0.0.1:8188/object_info > object_info.json
    luajit src/assets/comfy.lua check object_info.json

## Getting art in and out

    # a texture from a map (or from your install, through it) as a PNG,
    # to restyle: copy it to ComfyUI's input/ as wete-texture.png
    luajit src/assets/tool.lua texture MAP "Textures\\Footman.blp" footman.png

    # a model as GLB (textures embedded), for Blender or as a reference
    luajit src/assets/tool.lua model MAP "units\\human\\Footman\\Footman.mdx" footman.glb

    # posting a workflow without the editor
    curl -s -X POST http://127.0.0.1:8188/prompt \
         -H 'Content-Type: application/json' \
         -d "{\"prompt\": $(cat comfyui/workflows/icon.api.json)}"

What comes back can go straight into the engine:

- PNGs are read by `src/parsers/png.lua`.
- GLBs (from `model-from-image`) are read by `src/parsers/gltf.lua` and drawn by the same renderer as WC3's models. See them in the model gallery with `MODEL_GALLERY_GLB=path.glb` (`src/demo/models/main.lua`).
