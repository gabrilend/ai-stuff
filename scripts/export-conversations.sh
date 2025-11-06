#!/bin/bash
# {{{ export-conversations
# Export Claude conversations at all verbosity levels
# Usage: ./scripts/export-conversations.sh [project_dir]

DIR="${1:-/mnt/mtwo/programming/ai-stuff/risc-v-university}"
EXPORTER_SCRIPT="/home/ritz/programming/ai-stuff/scripts/claude-conversation-exporter.sh"

# Ensure we're in the correct directory
cd "$DIR" || exit 1

# Create llm-transcripts directory if it doesn't exist
mkdir -p llm-transcripts

echo "Exporting conversations at all verbosity levels..."

# Export v1 (compact)
echo "Exporting v1 (compact)..."
"$EXPORTER_SCRIPT" -v1 risc-v-university all > llm-transcripts/v1-compact.md

# Export v2 (standard)
echo "Exporting v2 (standard)..."
"$EXPORTER_SCRIPT" -v2 risc-v-university all > llm-transcripts/v2-standard.md

# Export v3 (verbose)
echo "Exporting v3 (verbose)..."
"$EXPORTER_SCRIPT" -v3 risc-v-university all > llm-transcripts/v3-verbose.md

# Export v4 (complete)
echo "Exporting v4 (complete)..."
"$EXPORTER_SCRIPT" -v4 risc-v-university all > llm-transcripts/v4-complete.md

# Export v5 (raw)
echo "Exporting v5 (raw)..."
"$EXPORTER_SCRIPT" -v5 risc-v-university all > llm-transcripts/v5-raw.md

echo "All conversation exports completed!"
echo "Files created/updated:"
ls -la llm-transcripts/v*.md
# }}}