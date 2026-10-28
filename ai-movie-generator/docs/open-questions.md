# Open questions

Each one stays here until it is answered with the owner; an answer moves into
the document it changes, and the question is struck through with the answer
beside it.

1. **"Render the game."** When the input is a game's soundtrack, what should
   the film show — the game's world as imagined from the music's mood, or a
   specific game the owner names (with its look described in the brief)?
2. **Where the monologue's voice comes from.** A recording the owner
   supplies, or a synthesised voice? `/usr/bin/piper` exists, but it may be
   the gaming-mouse tool of the same name rather than the speech engine;
   no voice model files have been found.
3. **Keeping a face the same.** Seed and description alone hold a character
   only loosely. Installing the IP-Adapter node pack into ComfyUI's
   custom_nodes/ would hold faces much better. That changes the
   stable-diffusion project, which belongs to its own sessions — install it
   there, or stay with seed + controlnet?
4. **A motion model.** AnimateDiff for SD 1.5 would give real movement
   inside a shot. Worth installing into ComfyUI, or keep motion as camera
   moves and drift?
5. **Picture size.** 768×432 is the proposed default (16:9 near SD 1.5's
   native size), upscaled by SwinIR for a final render. Agreed?
6. **The room's headset.** Which VR device (if any) will open the room —
   it decides whether WebXR is the right road.
7. **The writers' model.** qwen3.5:9b is the proposed default. Should the
   writers' room ever call Claude instead of a local model, or stay local?
