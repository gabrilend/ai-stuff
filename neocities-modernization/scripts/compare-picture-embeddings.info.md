# compare-picture-embeddings

Asks whether the embedding model understands what a picture shows, in
particular a picture of words. Issue 9-013.

## Usage

```
scripts/compare-picture-embeddings [DIR] --port N
```

| argument | type | meaning |
| --- | --- | --- |
| `DIR` | directory | the project (default: this project's folder) |
| `--port` | number | port of a running llama-server started with EmbeddingGemma 2, `--mmproj assets/models/mmproj-embeddinggemma-2-Q8_0.gguf` and `--embeddings`. The script does not start one. |

## What it does

1. Draws three pictures of known words (a line of poetry, a line of C, a
   grocery list) with ImageMagick into `tmp/shared-memory/compare-picture-embeddings/`.
2. Embeds them, four real screenshots from `input/media_attachments/`, and a
   drawing from `input/images/my-art/`, through the server's `/v1/embeddings`
   (each picture sent as a base64 `image_url` content part).
3. Embeds a set of sentences with the poems' clustering prefix, including a
   paraphrase that shares no key words with the poem line, and one unrelated
   sentence.
4. Prints each picture's three closest sentences (cosine) and a
   picture-to-picture table.

Changes nothing outside its scratch folder.
