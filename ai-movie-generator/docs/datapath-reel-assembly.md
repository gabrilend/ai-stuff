# Datapath — reel assembly (clips and sound to one film)

## In

The shot list, every clip it names, and the film's sound file.

## Through

1. **Check.** Every shot has its clip, every clip has the length its shot
   says, and the shots tile the film's length without gaps or overlaps. Any
   failure stops assembly and names the shot.
2. **Concatenate.** ffmpeg's concat reads a list file of the clips in shot
   order. Cuts are hard by default; a shot may ask for a short crossfade
   into the next.
3. **Lay the sound.** The film's sound is muxed under the picture, trimmed to
   the picture's length. Monologue audio is mixed over it at its `at` time.
4. **Encode.** `reel.mp4`, H.264 + AAC.
5. **Contact sheet.** One keyframe per shot, tiled with its id and timing
   underneath, as `contact-sheet.png` — the fastest way to see the whole
   film at once.

## Out

`output/<run>/reel.mp4`, `output/<run>/contact-sheet.png`, and the run's
goodbye receipt in `output/goodbye`: when it ended, the film's seed, shots
rendered, diffusion calls made, seconds of film, seconds spent.

## Partial re-assembly

Assembly only reads files; re-running it after one clip is re-rendered
costs one ffmpeg pass. This is the inner loop of iteration.
