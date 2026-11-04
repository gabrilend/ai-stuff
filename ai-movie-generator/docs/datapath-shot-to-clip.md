# Datapath — shot to clip

How one `shot{}` line becomes a 3–6 second video clip.

## In

One shot table from the shot list (see shot-list-format.md), plus the film's
size, fps and the cast/place tables it names.

## Through

1. **The prompt is assembled.** `sees` + each cast member's `look` + the
   place's `look` + the film's style words, joined with commas. The seed is
   the first cast member's seed if any, otherwise film seed + shot index.
2. **The road is chosen** by a dispatch table on `by`:
   - `diffusion` → steps 3–5;
   - `gif` → step 6.
3. **The keyframe is painted** through the image call. For `pan`, the
   keyframe is painted wider than the frame (so there is something to pan
   across); for `dissolve`, two keyframes are painted.
4. **Frames are made** by a dispatch table on the motion's name:
   - `still`, `push_in`, `pull_out`, `pan` — no new painting. ffmpeg's
     zoom-and-pan filter moves a virtual camera over the keyframe, frame by
     frame, eased slow-fast-slow. Cheap: seconds of CPU.
   - `drift` — each new frame is an image-to-image repaint of the previous
     one at low strength with the same seed, so detail shimmers and shifts
     while the composition holds. Expensive: one diffusion call per painted
     frame. To keep it affordable, only every *k*-th frame is painted
     (default: 3 painted frames per second) and the frames between are
     crossfaded.
   - `dissolve` — ffmpeg crossfades keyframe A into keyframe B over the
     shot's length, with a slight push-in so it does not sit dead.
5. **Frames are encoded** to `<shot id>.mp4` (H.264, the film's fps).
   Encoding of different shots happens in parallel on the CPU thread pool.
6. **The gif road**: the shot's `score` file is handed to the gif
   generator's renderer with the film's size and the shot's length; the gif
   that comes back is converted to `<shot id>.mp4` at the film's fps so the
   editor sees one kind of file.

## Out

`<shot id>.mp4` in the run folder, exactly `lasts` seconds long (the clip
length is checked; a clip of the wrong length is an error, because the
editor's timing depends on it), and a render-log line per shot.

## Why motion lives outside the diffusion model

No motion model is installed (see hardware-and-models.md), and SD 1.5
repainting every frame from noise flickers badly. Camera moves over a single
painted frame look intentional and cost nothing; drift gives life where it
is wanted. When a motion model is installed later, it becomes one more entry
in the motion dispatch table — nothing upstream changes.
