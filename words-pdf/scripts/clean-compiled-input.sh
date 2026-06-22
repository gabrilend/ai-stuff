#!/bin/bash
# clean-compiled-input.sh — Produce a cleaned copy of input/compiled.txt that
# the embedding pipeline can safely feed to llama-server.
#
# Two classes of garbage have shown up in compiled.txt over time:
#
# 1) Whole poem-blocks that are actually binary files (one was a 13 KB
#    embedded PDF). Random binary bytes happen to form syntactically valid
#    UTF-8 starters by chance; a single-byte sanitizer can't tell the noise
#    from real text, so the only honest fix is to skip the block entirely.
#    We detect by magic markers (%PDF-, PNG header, ELF, etc.) — anything
#    that smells binary at the start of a block.
#
# 2) Individual broken UTF-8 sequences inside otherwise-normal text. The
#    usual cause is upstream tools that line-wrap through the middle of a
#    multi-byte character — the ╭──╮ box-drawing borders around dividers
#    in this corpus are the typical victims. iconv -t UTF-8//IGNORE drops
#    the half-bytes; the rest of the surrounding text stays intact.
#
# The input file is read-only (it is the user's source of truth); cleaned
# output is written to ${DIR}/tmp/compiled-cleaned.txt and overwritten on
# every invocation, so re-running this script is always safe and produces
# the same bytes for the same input.

set -euo pipefail

# {{{ DIR + paths
DIR="${1:-/home/ritz/programming/ai-stuff/words-pdf}"
INPUT="${INPUT:-${DIR}/input/compiled.txt}"
OUTPUT="${OUTPUT:-${DIR}/tmp/compiled-cleaned.txt}"
# }}}

# {{{ preflight
if [ ! -f "${INPUT}" ]; then
    echo "❌ ${INPUT} not found" >&2
    exit 1
fi
"${DIR}/scripts/ensure-tmp-symlink" "${DIR}" >/dev/null
mkdir -p "$(dirname "${OUTPUT}")"
# }}}

# {{{ strip_binary_blocks(stdin → stdout)
# Walks the file as a sequence of 80-dash-separated poem blocks. Drops any
# block whose body starts with a recognized binary magic. The separator
# itself is kept once per surviving boundary, so the block count drops by
# exactly the number of dropped blocks.
#
# Implementation note: awk accumulates each block in a buffer and prints
# only after seeing the closing separator. This is O(file size) memory in
# the worst case (one block ≈ one file) but in practice each poem is
# small, so memory stays low.
strip_binary_blocks() {
    awk '
        BEGIN {
            sep = "";
            for (i = 0; i < 80; i++) sep = sep "-";
            block = "";
            have_block = 0;
            dropped = 0;
        }
        $0 == sep {
            if (have_block && block ~ /%PDF-|\x89PNG|\x7fELF|GIF8[79]a|^PK\x03\x04/) {
                # Drop both the block AND its closing separator — leaving
                # the separator alone would produce an empty block in the
                # output, which downstream code might still try to embed.
                dropped++;
            } else {
                if (have_block) printf "%s", block;
                print $0;
            }
            block = ""; have_block = 0;
            next;
        }
        {
            block = block $0 "\n";
            have_block = 1;
        }
        END {
            if (have_block && !(block ~ /%PDF-|\x89PNG|\x7fELF|GIF8[79]a|^PK\x03\x04/)) {
                printf "%s", block;
            }
            if (dropped > 0) {
                printf("[clean-compiled-input] dropped %d binary-looking block(s)\n", dropped) > "/dev/stderr";
            }
        }
    ' "$@"
}
# }}}

# {{{ pipeline
# strip binary blocks, then have iconv drop any orphan/half-of-multibyte
# bytes. iconv -t UTF-8//IGNORE -c silently skips the bytes that would
# otherwise abort decoding — exactly the lossy-but-localized behavior we
# want — but iconv still returns non-zero whenever it dropped anything
# (by design; same convention as grep returning 1 on no-match). That
# clashes with pipefail, so we accept the nonzero on the pipeline and
# verify the result by checking the output file is non-empty below.
set +o pipefail
strip_binary_blocks "${INPUT}" | iconv -f UTF-8 -t UTF-8//IGNORE -c > "${OUTPUT}" || true
set -o pipefail

if [ ! -s "${OUTPUT}" ]; then
    echo "❌ ${OUTPUT} is empty after cleaning; aborting" >&2
    exit 1
fi

orig_size=$(stat -c %s "${INPUT}")
out_size=$(stat -c %s "${OUTPUT}")
echo "🧹 cleaned ${INPUT}: ${orig_size} → ${out_size} bytes (${OUTPUT})"
# }}}
