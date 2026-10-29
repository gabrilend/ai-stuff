# Open questions

Each one stays here until it is answered with the owner; an answer moves into
the document it changes, and the question is struck through with the answer
beside it.

1. ~~**"Render the game."** What should a soundtrack's film show?~~
   **Answered 2026-10-28:** a world imagined from the music's mood. The
   writers' room may fill in details at will — genres, kinds of game,
   places and people — always as original designs (setting-and-tone.md).
2. ~~**Where the monologue's voice comes from.**~~ **Answered 2026-10-28:**
   a synthesised voice. `/usr/bin/piper` turned out to be the gaming-mouse
   tool (Void package piper-0.8), not the speech engine; see question 8.
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
8. **Which speech engine to install.** None is installed (only espeak-ng's
   runtime library). Piper TTS (the rhasspy/OHF engine, with downloaded
   voice models of tens of megabytes each) gives natural voices on the CPU;
   espeak-ng is tiny and robotic. The proposal is Piper TTS, installed into
   this project's `libs/` so it does not collide with the mouse tool's name.
