# 008 — Open questions

Each of these blocks a design decision somewhere. They are asked one at a time;
an answer is written into the document or issue it affects, and the question is
then marked answered here with where the answer went.

## Waiting

3. **Is the context policy two settings or a slider?** The vision says
   "encouraged or discouraged". A number between 0 and 1 holds both ends and
   everything between; two named settings are easier to reason about. (`105`)
2b. **Which checkpoint?** The server has `Chroma1-HD`, `NetaYume_v4_all_in_one`,
   `juggernautXL_ragnarokBy`, and three `waiIllustriousSDXL` versions. The
   Illustrious and NetaYume models are anime-styled; Juggernaut XL is
   photographic, which suits "this is what 280 kg of flour looks like". (`402`)
10. **When the pointer leaves before the picture is done**, does the work
    finish (so the picture is cached for next time) or cancel (so the server
    is free)? With no waiting before a hover is sent, a pointer sweeping across
    a page of quantities could start many pictures. (`204`, `403`)
11. **A quantity inside a link, middle-clicked:** open the link in a new tab as
    Firefox normally does, or re-roll? (`502`)
12. **Saving pictures — is this the right reading?** RAM by default; a setting
    to keep the cache on disk instead; and a list of recent pictures in the
    Extensions menu with a save action for each. (`403`, `503`)
13. **Which text-writing model for the ComfyUI route?** The server's only text
    model is a T5 encoder, which cannot write sentences. ComfyUI's
    `TextGenerate` needs a generative model in its text-encoder folder. Until
    one is installed, the `local` route on the reader's machine is the only one
    that works — and it needs its own answer: which local server and model.
    (`303`)

## Answered

1. **Which language model, and where?** — "run everything for this project in
   the comfyui system if we can. Otherwise, we can do the language models on my
   side and send them as prompts." Two routes behind one setting, both built.
   → `303`, `docs/004`. Follow-up: 13.
2. **Which ComfyUI?** — `192.168.0.88:8188`. → `204`, `402`, `docs/005`.
   Checkpoint still open: 2b.
4. **How does the reader say "I didn't understand"?** — middle click. → `502`,
   `docs/004`, `docs/006`.
5. **How long must the pointer rest?** — "however it takes to generate. We
   should cache them to redisplay unless middle-clicked." No waiting before a
   hover is sent; a cache that redisplays. → `103`, `202`, `403`, `501`,
   `docs/002`, `docs/005`. Follow-up: 10.
6. **Is a bare number a quantity?** — yes; the model picks the object ("55
   crocodiles looks like this"). And: "we need to be sure to draw the correct
   amount of objects on screen and say 'this one goes here, that one goes
   there'… subdivision maybe, into a rough grid or hexagonal shape? with the
   edges unused or specified as 'half of a *whatever*' as they stick off the
   page". → `102`, `303`, `401`, `402`, `docs/003`, `docs/005`.
7. **Undeclared language, `1.234 kg`?** — "leave it to the AI judgement". Both
   readings go to the model. → `102`, `303`, `docs/003`.
8. **Keep pictures?** — "only in RAM, but the user should be able to save them
   through the extensions menu. and also they should be able to save to disk
   instead." → `403`, `503`, `docs/005`. Reading to confirm: 12.
9. **Is `notes/vision` the right place?** — yes.
