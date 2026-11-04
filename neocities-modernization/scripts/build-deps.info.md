# build-deps.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/build-deps.sh: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
scripts/build-deps.sh
Downloads CUDA and llama.cpp source into the RAM-backed tmp/ tree, builds
llama.cpp there, then installs the finished binaries + shared libraries
into libs/ so the project owns a clean, disk-backed copy. Replaces the
system-installed Ollama daemon as the embedding backend per issue 10-049.

CUDA install: download CUDA 12.9 from NVIDIA (~5 GB) into tmp/downloads/
and install via the runfile installer DIRECTLY into libs/cuda/ using
--toolkitpath. No sudo required — nothing touches /usr/local or /var/log.
CUDA 12.9 was chosen because it is the most recent toolkit that still
supports Pascal (sm_61, the 1080 Ti) AND officially supports gcc up to
14.x — so no -allow-unsupported-compiler workaround is needed on
rolling-distro hosts running gcc 14.

CUDA 13.0+ would solve gcc compatibility officially but dropped Pascal
entirely, so this project is pinned to the 12.x line for as long as it
cares about the 1080 Ti. Ollama's bundled CUDA was tried as a download-
free shortcut, but its bundled libs are built without Pascal in the arch
list, so the binaries do not actually run on the 1080 Ti even though the
toolkit metadata says they should. Removed in favor of the one path that
is known to work end-to-end.

llama.cpp source/build live in tmp/llamacpp-src/ (RAM-backed), and the
install step copies only the finished bin/, lib/, and include/ into
libs/llama.cpp/ via "cmake --install --prefix". This way disk holds the
~100 MB of artifacts that need to persist, and RAM absorbs the 1–3 GB of
build churn.

Usage:
  ./scripts/build-deps.sh                  # Build into the default project DIR
  ./scripts/build-deps.sh /custom/dir      # Build into a different project DIR
  ./scripts/build-deps.sh --clean          # Wipe tmp source AND libs install
  ./scripts/build-deps.sh --no-model       # Skip the GGUF model download
  ./scripts/build-deps.sh --skip-cuda      # Trust whatever CUDA is already present
  ./scripts/build-deps.sh --force-cuda     # Wipe libs/cuda/ before installing
  ./scripts/build-deps.sh --help           # Show this message

Environment:
  BUILD_JOBS=N                             # Parallel cmake build jobs (default: 8)
                                           # Lower this if the host CPU is overheating.

What this gives you on success:
  $DIR/libs/cuda/                  — the CUDA toolkit (nvcc, libcudart, etc.)
  $DIR/libs/llama.cpp/bin/         — llama-server, llama-cli, llama-embedding
  $DIR/libs/llama.cpp/lib/         — libllama.so, libggml*.so
  $DIR/tmp/llamacpp-src/           — RAM-backed clone + build (ephemeral)
  $DIR/assets/models/<model>.gguf  — the embedding model file
  A smoke-tested working install ready for the 10-049 migration.
```

## Functions

### `parse_arguments()`
(No comment above it in the source.)

### `get_nvcc_version()`

```
Returns the version string an nvcc binary reports (e.g. "12.6.77"), or
empty if the path does not point to a working nvcc. Used both to validate
the install we already have, and to decide which gcc-compat flags to set.
```

### `get_nvcc_major_minor()`

```
Returns just the "12.6" or "12.9" prefix of an nvcc version string. Used to
decide which max-gcc constant applies, since point releases (.77, .41, etc)
never affect host-compiler support.
```

### `detect_cuda_arch()`

```
Asks nvidia-smi what the local GPU's compute capability is and returns it
without the dot (e.g. "61" for the 1080 Ti's 6.1). We use this to target
cmake at exactly the architecture we will actually run on, instead of
relying on cmake's default arch list (which in CUDA 12.6+ may or may not
include Pascal sm_61, since Pascal is officially deprecated).
```

### `host_gcc_major()`

```
Returns the host gcc's major version number (e.g. "14" for gcc 14.2.1).
```

### `check_requirements()`

```
Verifies the build tools are available before we attempt anything serious.
Unlike previous versions of this script, a missing nvcc is NOT fatal here —
build_cuda() will install one. We only bail on truly required upstream
tools (compilers, build system, downloader).
```

### `ensure_directories()`

```
Create the destination directories with mkdir -p. tmp/ is symlinked
to a RAM-backed location for ephemeral working files (per the project's
convention of keeping intermediate state out of the disk-backed tree).
```

### `already_have_libs_cuda()`

```
True if libs/cuda already has a CUDA install matching REQUIRED_CUDA_PREFIX
(e.g. "12.9"). A mismatched version triggers a reinstall, since the script
now has exactly one supported toolkit version and a hybrid layout would
silently break the build. Caller decides what to do with the answer.
```

### `force_clean_libs_cuda()`

```
--force-cuda wipes libs/cuda before installing, in case the previous
install is corrupt or the wrong version.
```

### `download_cuda_installer()`
(No comment above it in the source.)

### `install_cuda_runfile()`

```
Runs the .run installer with --toolkit and --toolkitpath pointing at the
project-local libs/cuda/. Because the install target is user-writable, no
sudo is required — nothing lands in /usr/local. The CUDA 12.9 installer
writes its internal log to a hardcoded /var/log/cuda-installer.log (which
fails silently as non-root) and exposes NO flag to redirect it, so we
instead capture the installer's stdout+stderr to a project-local log
file via shell redirection. That covers most failure modes (bad flags,
missing toolkit components, permission issues on the install path).
```

### `patch_cuda_headers()`

```
CUDA 12.9.0's math_functions.h declares sinpi/sinpif/cospi/cospif WITHOUT
noexcept(true), while glibc 2.40+ declares the same functions WITH it via
__MATHCALL_VEC. nvcc rejects the exception-specification mismatch, breaking
every CUDA compilation on hosts with modern glibc. CUDA 12.9.1+ ships with
the noexcept already in place; this function applies the same patch to the
12.9.0 headers so the user does not have to re-download to fix the build.

The substitution is gated on /noexcept/! so re-running it is a no-op —
already-patched lines do not get a second noexcept appended.
```

### `build_cuda()`

```
Top-level CUDA install entry point. Resolves between three states:
  - --skip-cuda set:           trust the operator, do nothing
  - libs/cuda already correct: do nothing (version-prefix match)
  - otherwise:                 download CUDA 12.9 from NVIDIA, install
                               directly into libs/cuda/ with no sudo
```

### `detect_old_llamacpp_layout()`

```
Earlier versions of this script kept llama.cpp's source checkout at
libs/llama.cpp/ (with .git inside). The new layout puts source in tmp/
and installs the finished bin/lib into libs/llama.cpp/. If the operator
is upgrading without --clean, bail BEFORE the CUDA install step so they
do not eat a 5 GB download just to hit the layout error after. With
--clean we simply continue — clone_llamacpp will wipe libs/llama.cpp
as part of its clean handler.
```

### `clone_llamacpp()`

```
Clone llama.cpp at the pinned version into the RAM-backed tmp/ tree, or
refresh if it already exists. The clone is intentionally NOT under libs/
anymore — only finished artifacts live there. Pinning to a tag keeps the
build reproducible across sessions; the -c advice.detachedHead=false
silences git's cosmetic warning that tagged checkouts produce detached HEAD.
```

### `build_llamacpp()`

```
Configure and build llama.cpp with CUDA support. Build artifacts go to
tmp/llamacpp-src/build/ (RAM-backed) — only the install step copies
finished products into libs/. Three GPU-specific decisions happen here:
  1. CUDAToolkit_ROOT points at libs/cuda/ so cmake never touches the
     host PATH or LD_LIBRARY_PATH. The build is hermetic from CUDA's
     perspective.
  2. CMAKE_CUDA_ARCHITECTURES is set to the detected GPU's compute
     capability (sm_61 for the 1080 Ti). This both speeds up the build
     and guarantees Pascal stays in the compiled arch list — modern
     CUDA defaults silently drop it.
  3. If the host gcc is newer than CUDA 12.9's supported max (14), add
     -allow-unsupported-compiler so nvcc skips its host-compiler gate.
     Not needed for gcc 14 or older; meant as a forward-compat hedge
     against rolling distros that may bump gcc to 15+ before we bump
     CUDA (CUDA 13 is not an option as long as we want Pascal).
```

### `install_llamacpp()`

```
Copy finished binaries + shared libraries + headers from the RAM-backed
tmp/ build tree into the disk-backed libs/llama.cpp/ install prefix via
`cmake --install`. This is the step where artifacts "move from RAM to
disk" — the tmp/ source and build trees can be wiped after this without
affecting the project's ability to run llama-server.
```

### `download_model()`

```
Pull the configured GGUF model file from HuggingFace if it is not
already present. The download is around 280 MB at f16 precision and
typically takes ~30 seconds on a residential connection. Skip with
--no-model when iterating on the build itself.
```

### `smoke_test()`

```
Launch the server briefly, ping it for one embedding, kill it. This
catches obvious "the build linked but does not actually run" failures
before the operator wires the pipeline against it.
```

### `print_env_summary()`

```
Final friendly summary so the operator knows what env vars to set if they
want to invoke llama-server / nvcc by hand outside this script. The build
script handles its own env internally, but downstream tools need the hint.
```

### `main()`
(No comment above it in the source.)
