-- Model file names for the workflows in comfyui/workflows (issue 522f).
-- Rename these to the files your ComfyUI has under models/, then write the
-- workflows again: luajit src/assets/comfy.lua write
return {
    checkpoint = "v1-5-pruned-emaonly.safetensors",          -- models/checkpoints
    controlnet_canny = "control_v11p_sd15_canny.pth",        -- models/controlnet
    hunyuan3d = "hunyuan3d-dit-v2.safetensors",              -- models/checkpoints (Hunyuan3D 2)
    negative = "blurry, text, watermark, signature, frame, border",
    seed = 5222,
}
