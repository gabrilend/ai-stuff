# 145-make-an-image — info

The front door. Recipe, board and model in; an image you can put on a card out.
Issue `502`.

## Invocation

```
luajit src/145-make-an-image.lua --board qemu-uefi-x86-64
```

| Option | Value | What it does |
|---|---|---|
| `--board` | name | the short name from a `src/*-board-<name>.lua` file; required |
| `--recipe` | file | a recipe description; `input/example-recipe.lua` by default |
| `--model` | file | a packed model; the fixture stands in and says so |
| `--to` | file | where the image goes; the RAM artifact tier by default |
| `--dir` | path | project root override |

Three files come out, never only the image: the image, the manifest saying what
went into it, and the identity anyone can arrive at again from the same inputs.

## What it joins

Nothing here decides anything. Every decision belongs to one of these, and this
exists so that they meet.

| | |
|---|---|
| `144` | writes out the machine — work area divided, engine set up, tokenizer prepared, driver's loop entered |
| clang, llvm-objcopy | turn that text into instructions |
| `089` | lays out where everything goes and accounts for it |
| `029` | puts the code in the envelope a firmware will run |
| `141` | puts that file on a medium a firmware will open |

## Why it exists

Everything needed to make a seed existed and nothing joined it up. The thing
that builds a machine lived **inside a test**, so obtaining one meant running a
test. The thing that builds an image was a library nobody could run, whose own
usage note described a command line that did not exist. So there was no way to
make a seed at all, and the builder — unable to reach a real machine — invented
an arrangement of its own, which was correct and described a machine nobody
built, for months.

## Behaviour worth knowing

- **The randomness is made once and handed to both halves.** The machine's
  assembly refers to it and the image carries it, so making it twice would make
  two machines. Same recipe and same seed gives the same machine exactly, which
  is the only kind of reproducibility this project has.
- **The model is always a parameter.** The fixture stands in when nobody named
  one and **says so**, because an image quietly carrying a toy model is the sort
  of thing somebody finds out at first light.
- **It prints where everything landed**, measured from the code's first byte,
  because that is what the engine measures from.
- **It prints the command to boot what it just made**, which is the difference
  between a tool that produced a file and a tool you can follow.

## What checks it

`142`, end to end: a recipe and a board become an image, the manifest says what
went into it, a partition tool finds no fault with the medium, and a machine
built that way boots on a real firmware, thinks, and says words.
