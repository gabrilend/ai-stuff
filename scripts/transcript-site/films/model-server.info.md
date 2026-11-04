# model-server.lua

Talks to the local model server: asks the vision model about a picture, and turns text into a list of numbers.

Part of the films (see README.md here). Read this file rather than the source.
function is misbehaving; this is for everything else.

## What it is for

The one place that speaks to Ollama, the program serving models on this
computer's graphics card. Requests and answers go through files in RAM and
curl, so no message text ever passes through shell quoting.

Every failure raises with the server's own words. Nothing returns "no answer"
for a caller to carry on past.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `new(address, scratch)` | "host:port", and a folder in RAM | a client: `{ address, scratch }`, both strings |
| `alive(client)` | a client | true if the server answers |
| `describe(client, model, prompt, image_path)` | a client, three strings | the model's description, a string |
| `embed(client, model, texts)` | a client, a string, a list of strings | a list of vectors in the same order; each vector a list of numbers (768 for embeddinggemma) |

## Timing worth knowing

The first request after the server starts loads the model onto the card, a
minute or two for the vision model. Asking about a new picture takes about
forty seconds on this card after that. The vision model and the embedding
model do not both fit at once; switching between them reloads.
