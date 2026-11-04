# 001 — What this makes

A Firefox extension. You move the mouse pointer onto a quantity written in a
web page — `1234 kg`, `15 m2`, `99 newtons`, or just `55` — and a small panel
appears beside the pointer holding a picture of that quantity made of things
you already know the size of: a horse leaning into a cart, eleven sacks of
flour and a fifth of one stacked on a kitchen floor, fifty-five crocodiles
piled on a riverbank. The picture holds exactly that many: the frame is divided
into cells and each object is drawn in its own. One sentence under the picture
says what the comparison is. If it does not land, you middle-click, and a new
picture arrives built from a different *kind* of subject.

Nothing else is asked of the reader. No selecting, no right-click menu, no
typing. The pointer on the number is the whole request; the middle button is
the whole complaint. A quantity hovered before shows its picture again at once.

## The core terms

These are the words the rest of the documentation and the issue files use. Each
names one piece of the machine.

| Term | What it is |
|---|---|
| **quantity** | A number in running text, found and understood: its value, its unit, the physical dimension the unit measures (mass, area, force…), and the same amount converted into SI base units. A number with no unit is a quantity of dimension `count`. |
| **unit lexicon** | The data file listing every unit the reader recognises: its spellings, its dimension, and the factor that turns it into SI. |
| **hover** | One moment of the pointer resting over text: the whole paragraph, broken into lines and words, with where each word sits on the screen and where the pointer is. |
| **proximity spectrum** | A list of numbers, one per word in the paragraph, each between 0 and 1, saying how near that word is to the pointer. The word under the pointer is 1; words further away fade toward 0. Lines above and below fade faster than words along the same line. |
| **context policy** | The one setting the reader controls: whether the reasoning is *encouraged* to use the surrounding paragraph (a sentence about bridge cables gets a picture of bridge-ish things) or *discouraged* from it (the quantity alone, compared to the plainest thing that fits). It reshapes the proximity spectrum before anything else reads it. |
| **reference object** | A thing whose size is known and written down: a horse can pull about so many newtons, a sack of flour weighs so many kilograms, a car occupies so many square metres. Kept in a catalogue, grouped by dimension. |
| **kind** | A family of reference objects: animals, food, vehicles, buildings, the human body, sports. "Show me something different" means "change the kind", not "change the object". |
| **analogy** | What the reasoning produces for one quantity: which reference object, how many of it, one plain sentence for the reader, and a scene description for the picture-maker. |
| **re-roll** | The reader middle-clicking to say "I didn't understand that one". The next analogy must come from a kind not yet shown for this hover. |
| **layout** | The frame divided into cells, one per object, in a grid or a hexagonal packing, with a partial object hanging off the edge for a fractional count. Computed by the host so the picture holds exactly the right number. |
| **host** | The LuaJIT program the extension talks to. Everything that thinks — finding quantities, measuring proximity, choosing reference objects, asking the language model, asking ComfyUI — happens here. |
| **panel** | What the reader sees: the picture, the sentence, and the way to ask for another. |

## Why it is split the way it is

A Firefox extension can only run JavaScript. The owner's projects are written
in Lua. So the extension is kept as thin as it can be made: it **observes**
(where the words are, where the pointer is) and it **shows** (the panel). Every
decision between those two happens in the host, which Firefox launches and
talks to over a pipe using its *native messaging* mechanism — a stream of JSON
messages, each preceded by a four-byte length. See
[the bridge datapath](006-datapath-the-bridge.md).

This also keeps the generation of data apart from the viewing of it: the host
could be fed hover records from a file, or from a different browser, and would
not know the difference.

## The outside machine

**ComfyUI**, at `192.168.0.88:8188`: a server that accepts a graph of
processing nodes as JSON and runs it. It draws the pictures, and — by the
owner's preference, "run everything for this project in the comfyui system if
we can" — it also runs the language model, through its built-in text-generation
node. The neighbouring project `kanji-learning-image-generator` already has a
writer for these graphs, and `world-edit-to-execute` already reuses it; this
project reuses it too. See [the picture datapath](005-datapath-the-picture.md).

**The language model** does the part that is genuinely judgement: given this
paragraph and this quantity, which reference object makes the best picture,
and what setting it should be drawn in. It is *not* trusted with arithmetic.
The host computes "how many sacks" itself from the catalogue and gives the
model the answer. Where ComfyUI has no text-writing model installed, a model on
the reader's own machine does this instead, chosen by a setting. See
[the analogy datapath](004-datapath-the-analogy.md).
