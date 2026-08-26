#!/usr/bin/env bash
#
# 043-install-the-kitchen -- puts a working image generator inside this project
#
# For a general: everything else here writes recipes. Nothing here has ever
# cooked one, because cooking needs a diffusion model and a graphics card. This
# installs the cooker -- ComfyUI, the arithmetic library it runs on, and the two
# model files the recipes name -- entirely inside this project's own libs/
# directory, so that removing it is removing one folder.
#
# WHAT IS BUILT FROM SOURCE AND WHAT IS NOT, since it was asked:
#
#   ComfyUI      source. It is Python; a clone is the source, and it is what
#                gets run. No build step exists to skip.
#
#   PyTorch      a published build, and this is a real compromise. Building it
#                here is possible -- the CUDA compiler is installed -- and costs
#                several hours, tens of gigabytes of scratch space, and a
#                dependency list longer than everything else in this script put
#                together. --build-torch attempts it anyway and says what it is
#                getting into.
#
#   the models   neither. A model file is several billion numbers that came out
#                of a training run somebody else paid for. There is no source to
#                compile; the weights ARE the artifact.
#
# Safe to run again. Every step checks whether it has already been done, and
# downloads resume where they left off.
#
#   src/043-install-the-kitchen.sh [--dir ROOT] [--models-only] [--skip-models]
#                                  [--build-torch] [--check]

# {{{ DIR -- the project root, hard-coded, overridable by an argument
DIR="/mnt/mtwo/programming/ai-stuff/kanji-learning-image-generator"
if [ -n "${1:-}" ] && [ -d "$1" ]; then DIR="$1"; shift; fi
# }}}

set -u

KITCHEN="${DIR}/libs/kitchen"
COMFY="${KITCHEN}/ComfyUI"
VENV="${KITCHEN}/venv"
PYTHON=""
MODELS_ONLY=0
SKIP_MODELS=0
BUILD_TORCH=0
CHECK_ONLY=0

for argument in "$@"; do
  case "$argument" in
    --models-only) MODELS_ONLY=1 ;;
    --skip-models) SKIP_MODELS=1 ;;
    --build-torch) BUILD_TORCH=1 ;;
    --check)       CHECK_ONLY=1 ;;
    --dir)         ;;
    *)             if [ -d "$argument" ]; then DIR="$argument"; fi ;;
  esac
done

# {{{ say, complain -- everything this script tells you
say()      { printf "  %s\n" "$*"; }
step()     { printf "\n== %s\n" "$*"; }
complain() { printf "\n!! %s\n" "$*" >&2; }
die()      { complain "$*"; exit 1; }
# }}}

# {{{ need -- a tool this cannot be done without
need() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is not on this machine, and $2"
}
# }}}

# {{{ have_space -- refuse rather than fill the disk
#
# Downloading six gigabytes onto a disk with four left does not fail cleanly --
# it fails most of the way through, having taken twenty minutes, and leaves a
# truncated model file that looks finished.
have_space() {
  local wanted_gb="$1"
  local free_kb
  free_kb=$(df -Pk "$DIR" | awk 'NR==2 {print $4}')
  local free_gb=$((free_kb / 1024 / 1024))
  if [ "$free_gb" -lt "$wanted_gb" ]; then
    die "this needs about ${wanted_gb}GB and there are ${free_gb}GB free on the disk holding $DIR"
  fi
  say "${free_gb}GB free, about ${wanted_gb}GB needed"
}
# }}}

# {{{ fetch -- one large file, resumably
#
# Downloads resume, because a model file is gigabytes and a connection that
# drops at ninety percent should not mean starting again. The size is checked
# afterwards: a truncated safetensors file loads far enough to look plausible
# and then fails somewhere unrelated.
fetch() {
  local url="$1" target="$2" least_mb="$3" what="$4"
  if [ -f "$target" ]; then
    local have_mb=$(( $(stat -c %s "$target") / 1048576 ))
    if [ "$have_mb" -ge "$least_mb" ]; then
      say "$what is already here (${have_mb}MB)"
      return 0
    fi
    say "$what is here but only ${have_mb}MB; resuming"
  fi
  say "fetching $what"
  curl --location --fail --continue-at - --progress-bar --output "$target" "$url" \
    || die "could not fetch $what from $url"
  local got_mb=$(( $(stat -c %s "$target") / 1048576 ))
  if [ "$got_mb" -lt "$least_mb" ]; then
    die "$what came out at ${got_mb}MB and should be at least ${least_mb}MB; it is truncated"
  fi
  say "$what is ${got_mb}MB"
}
# }}}

# {{{ find_python -- an interpreter PyTorch has a build for
#
# Asked rather than assumed. PyTorch publishes builds for a specific set of
# interpreter versions, and a machine whose only Python is newer than all of
# them cannot install it at all -- which is a clear thing to be told at the
# start and a baffling one to discover in the middle of a dependency resolution.
find_python() {
  local candidates="python3.13 python3.12 python3.11 python3.14 python3"
  for candidate in $candidates; do
    if command -v "$candidate" >/dev/null 2>&1; then
      PYTHON="$candidate"
      say "using $($candidate --version 2>&1)"
      return 0
    fi
  done
  die "no python3 on this machine, and ComfyUI is written in it"
}
# }}}

# {{{ report -- what is installed, and whether the card works
report() {
  step "what is here"
  [ -d "$COMFY" ] && say "ComfyUI      $COMFY" || say "ComfyUI      not installed"
  [ -d "$VENV" ]  && say "its python   $VENV"  || say "its python   not installed"
  for pair in \
    "checkpoints/v1-5-pruned-emaonly.safetensors:the model that draws" \
    "controlnet/control_v1p_sd15_qrcode_monster.safetensors:the one that hides the character"
  do
    local path="${pair%%:*}" what="${pair#*:}"
    if [ -f "${COMFY}/models/${path}" ]; then
      say "$(printf '%-12s' "$(basename "$path" .safetensors | cut -c1-12)") $(( $(stat -c %s "${COMFY}/models/${path}") / 1048576 ))MB  -- $what"
    else
      say "missing      ${path}  -- $what"
    fi
  done

  if [ -x "${VENV}/bin/python" ]; then
    step "does the card work"
    "${VENV}/bin/python" - <<'PYEOF'
try:
    import torch
except Exception as problem:
    print("  torch will not import:", problem)
    raise SystemExit(0)
print("  torch", torch.__version__)
if not torch.cuda.is_available():
    print("  no CUDA. It would run on the processor, very slowly.")
    raise SystemExit(0)
name = torch.cuda.get_device_name(0)
capability = torch.cuda.get_device_capability(0)
print(f"  {name}, compute capability {capability[0]}.{capability[1]}")
supported = torch.cuda.get_arch_list()
print("  this build was made for:", " ".join(supported))
tag = f"sm_{capability[0]}{capability[1]}"
if tag not in supported:
    print()
    print(f"  !! This build of torch was not made for {tag}, which is what this")
    print( "     card is. Recent builds drop older cards. Either install an")
    print( "     older torch, or run on the processor and expect minutes per")
    print( "     picture rather than seconds.")
    raise SystemExit(0)
# The only test that means anything: make it actually do arithmetic on the card.
a = torch.randn(512, 512, device="cuda")
b = torch.randn(512, 512, device="cuda")
c = (a @ b).sum().item()
print(f"  a real multiplication on the card came back with {c:.1f} -- it works")
PYEOF
  fi
}
# }}}

step "the kitchen goes in ${KITCHEN}"
say "everything this installs lives inside this project. Removing it is"
say "removing that one folder."

if [ "$CHECK_ONLY" -eq 1 ]; then
  report
  exit 0
fi

need curl "the models are several gigabytes each"
need git "ComfyUI is fetched as source"

mkdir -p "$KITCHEN" || die "cannot make $KITCHEN"

if [ "$MODELS_ONLY" -eq 0 ]; then
  step "room on the disk"
  if [ "$SKIP_MODELS" -eq 1 ]; then have_space 8; else have_space 14; fi

  step "ComfyUI, from source"
  if [ -d "${COMFY}/.git" ]; then
    say "already cloned; bringing it up to date"
    git -C "$COMFY" pull --ff-only 2>&1 | sed 's/^/  /'
  else
    git clone --depth 1 https://github.com/comfyanonymous/ComfyUI "$COMFY" \
      2>&1 | sed 's/^/  /' || die "could not clone ComfyUI"
  fi
  say "at $(git -C "$COMFY" rev-parse --short HEAD)"

  step "a python of its own"
  find_python
  if [ ! -x "${VENV}/bin/python" ]; then
    "$PYTHON" -m venv "$VENV" || die "could not make a virtual environment"
  else
    say "already made"
  fi
  "${VENV}/bin/python" -m pip install --quiet --upgrade pip setuptools wheel \
    2>&1 | sed 's/^/  /'

  step "the arithmetic library"
  if "${VENV}/bin/python" -c "import torch" >/dev/null 2>&1; then
    say "torch is already installed"
  elif [ "$BUILD_TORCH" -eq 1 ]; then
    # Asked for outright, and this says what it is getting into rather than
    # quietly beginning something that runs for an afternoon.
    complain "building torch from source takes several hours, wants tens of"
    complain "gigabytes of scratch space, and needs a matching compiler for the"
    complain "CUDA toolkit at $(command -v nvcc 2>/dev/null || echo 'nowhere')."
    complain "Starting anyway, because it was asked for. Interrupt now if not."
    sleep 5
    git clone --recursive --depth 1 https://github.com/pytorch/pytorch \
      "${KITCHEN}/pytorch-source" 2>&1 | sed 's/^/  /' \
      || die "could not clone pytorch"
    ( cd "${KITCHEN}/pytorch-source" \
      && "${VENV}/bin/python" -m pip install -r requirements.txt \
      && USE_CUDA=1 "${VENV}/bin/python" setup.py install ) 2>&1 | sed 's/^/  /' \
      || die "the torch build failed. The published build is one line above this."
  else
    say "fetching a published build for this card's CUDA"
    say "(building it from source is possible here and takes hours: --build-torch)"
    "${VENV}/bin/python" -m pip install --quiet \
      --index-url https://download.pytorch.org/whl/cu126 \
      torch torchvision torchaudio 2>&1 | sed 's/^/  /' \
      || {
        complain "the CUDA build would not install; trying the ordinary one"
        "${VENV}/bin/python" -m pip install --quiet torch torchvision torchaudio \
          2>&1 | sed 's/^/  /' || die "torch will not install at all"
      }
  fi

  step "everything else ComfyUI wants"
  "${VENV}/bin/python" -m pip install --quiet -r "${COMFY}/requirements.txt" \
    2>&1 | sed 's/^/  /' || die "ComfyUI's requirements would not install"
fi

if [ "$SKIP_MODELS" -eq 0 ]; then
  step "the two model files"
  say "these are weights, not source. There is nothing to compile: the numbers"
  say "are the artifact."
  mkdir -p "${COMFY}/models/checkpoints" "${COMFY}/models/controlnet"

  fetch \
    "https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors" \
    "${COMFY}/models/checkpoints/v1-5-pruned-emaonly.safetensors" \
    4000 "the model that draws"

  # The one that makes a picture obey a grey image. This is the whole trick
  # (docs/003) and the reason the settings name an older generation of model:
  # this family of control net is best understood there, and an eleven-gigabyte
  # Pascal card is happier with it than with anything newer.
  fetch \
    "https://huggingface.co/monster-labs/control_v1p_sd15_qrcode_monster/resolve/main/control_v1p_sd15_qrcode_monster.safetensors" \
    "${COMFY}/models/controlnet/control_v1p_sd15_qrcode_monster.safetensors" \
    1300 "the one that hides the character"
fi

report

step "how to start it"
say "${VENV}/bin/python ${COMFY}/main.py --listen 127.0.0.1 --port 8188"
say ""
say "then, with it running:"
say "  luajit ${DIR}/src/044-run-the-pictures.lua --chars 木"
echo
