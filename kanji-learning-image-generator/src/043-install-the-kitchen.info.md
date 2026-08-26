# 043-install-the-kitchen — info

For a general: everything else here writes recipes. Nothing here has ever cooked one, because cooking needs a diffusion model and a graphics card. This installs the cooker -- ComfyUI, the arithmetic library it runs on, and the two model files the recipes name -- entirely inside this project's own libs/ directory, so that removing it is removing one folder.

WHAT IS BUILT FROM SOURCE AND WHAT IS NOT, since it was asked:

```
  ComfyUI      source. It is Python; a clone is the source, and it is what
               gets run. No build step exists to skip.

  PyTorch      a published build, and this is a real compromise. Building it
               here is possible -- the CUDA compiler is installed -- and costs
               several hours, tens of gigabytes of scratch space, and a
               dependency list longer than everything else in this script put
               together. --build-torch attempts it anyway and says what it is
               getting into.

  the models   neither. A model file is several billion numbers that came out
               of a training run somebody else paid for. There is no source to
               compile; the weights ARE the artifact.

```

Safe to run again. Every step checks whether it has already been done, and downloads resume where they left off.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `043-install-the-kitchen.sh` and
run the sweep again.*

## Invocation

```
src/043-install-the-kitchen.sh [--dir ROOT] [--models-only] [--skip-models]
[--build-torch] [--check]
```

## Where it sits

Used by `044-run-the-pictures`.
