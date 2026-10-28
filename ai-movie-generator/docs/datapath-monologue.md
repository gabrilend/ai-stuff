# Datapath — the monologue

One person speaks; the camera stays with them for the whole speech, however
long it runs, and cuts away to rendered pictures when they describe
something, then returns.

## In

A `monologue{}` entry: the speaker (a `cast{}` name), the speech as an audio
file, the words as text, and cutaways (times within the speech and what to
show). Where the audio comes from is an open question (open-questions.md):
a recording the person supplies, or a text-to-speech voice.

## Through

1. **The face is painted once.** One portrait keyframe of the speaker, from
   their cast `look` and seed, framed head-and-shoulders.
2. **The speech is measured.** The ear's loudness envelope is run over the
   speech audio alone. Loud windows are "mouth open", quiet are "closed".
3. **The face is kept alive.** The portrait is held for the full length with
   motion that follows the voice: a very slow push-in for the whole speech,
   and drift repaints whose strength rises slightly with loudness, so the
   picture is most alive when the voice is. (Moving the mouth itself — a
   few mouth-shape keyframes painted with inpainting and switched by
   loudness — is a later step in the roadmap.)
4. **Cutaways** are ordinary shots, rendered by the shot-to-clip road, and
   laid over the face track at their times. The speech audio continues
   under them uninterrupted.
5. **The cutaway words** can be found automatically: the director reads the
   text and marks sentences that describe something seeable ("a vision",
   "the reactor") as cutaways.

## Out

`<monologue id>.mp4`, exactly as long as the speech, which the editor treats
as one clip.
