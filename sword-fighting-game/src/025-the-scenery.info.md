<!-- made by scripts/build-info-pages from the comments in 025-the-scenery.lua; change the comments and rebuild, not this page -->
# 025-the-scenery


The ground a battle stands on, built once from the battle's seed and its
region: the field and its margin, stones and grass, puddles in a swamp
park, fences across a prairie, clouds overhead, and the cat faces the
vision asks for, hidden in all of it:

  a cluster of field stones that is two eyes, a nose and whiskers;
  clouds with two ears.

(The third, rivets on shields, is pressed by 024-figures.lua.) The same
seed always hides the same faces in the same places. None of it carries
gameplay. The result is a part list in the shape 024 makes.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.build` | `config, region, stream` | (no comment in the source) |
| `M.cat_faces` | `parts` | How many cat faces a part list holds, counted by their noses: for tests. |

## Tables of rows

| Name | What it is |
| --- | --- |
| `STONE` | (no comment in the source) |
| `GRASS` | (no comment in the source) |
| `CLOUD` | (no comment in the source) |
| `NOSE` | (no comment in the source) |
| `EYE` | (no comment in the source) |
| `PUPIL` | (no comment in the source) |
| `WATER` | (no comment in the source) |
| `POST` | (no comment in the source) |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `put` | `out, shape, x, y, z, sx, sy, sz, color, look, turn` | (no comment in the source) |
| `shade` | `c, k` | (no comment in the source) |
| `cat_face` | `out, x, z, size, turn` | Two eye stones with pupils, a nose stone between and below them, and grass-tuft whiskers either side, lying in the grass. |
| `cloud` | `out, stream, x, y, z` | A cloud is a few blobs, and two of them on top are ears. |
| `in_deployment` | `config, cy` | Stones and faces are kept off the cells the contingents start on. |
