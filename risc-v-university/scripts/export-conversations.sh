#!/bin/bash
# {{{ export-conversations
# Export Claude conversations at all verbosity levels
# Usage: ./scripts/export-conversations.sh [project_dir]

DIR="${1:-/mnt/mtwo/programming/ai-stuff/risc-v-university}"
EXPORTER_SCRIPT="/home/ritz/programming/ai-stuff/scripts/claude-conversation-exporter.sh"

# The exporter should run from the parent directory, not the project directory
cd /mnt/mtwo/programming/ai-stuff || exit 1

# Create llm-transcripts directory in the project directory
mkdir -p "$DIR/llm-transcripts"

# Backup current exports and remove old backups to prevent recursive inclusion
echo "Managing conversation export files to prevent recursive inclusion..."

# Remove old backup files
rm -f "$DIR/llm-transcripts/v1-compact.md.bak"
rm -f "$DIR/llm-transcripts/v2-standard.md.bak"
rm -f "$DIR/llm-transcripts/v3-verbose.md.bak"
rm -f "$DIR/llm-transcripts/v4-complete.md.bak"
rm -f "$DIR/llm-transcripts/v5-raw.md.bak"

# Backup current exports (if they exist)
[ -f "$DIR/llm-transcripts/v1-compact.md" ] && mv "$DIR/llm-transcripts/v1-compact.md" "$DIR/llm-transcripts/v1-compact.md.bak"
[ -f "$DIR/llm-transcripts/v2-standard.md" ] && mv "$DIR/llm-transcripts/v2-standard.md" "$DIR/llm-transcripts/v2-standard.md.bak"
[ -f "$DIR/llm-transcripts/v3-verbose.md" ] && mv "$DIR/llm-transcripts/v3-verbose.md" "$DIR/llm-transcripts/v3-verbose.md.bak"
[ -f "$DIR/llm-transcripts/v4-complete.md" ] && mv "$DIR/llm-transcripts/v4-complete.md" "$DIR/llm-transcripts/v4-complete.md.bak"
[ -f "$DIR/llm-transcripts/v5-raw.md" ] && mv "$DIR/llm-transcripts/v5-raw.md" "$DIR/llm-transcripts/v5-raw.md.bak"

echo "Previous exports backed up as .bak files, ready for clean export..."

echo "Exporting conversations at all verbosity levels..."

# Export v1 (compact)
echo "Exporting v1 (compact)..."
"$EXPORTER_SCRIPT" -v1 risc-v-university all > "$DIR/llm-transcripts/v1-compact.md"

# Export v2 (standard)  
echo "Exporting v2 (standard)..."
"$EXPORTER_SCRIPT" -v2 risc-v-university all > "$DIR/llm-transcripts/v2-standard.md"

# Export v3 (verbose)
echo "Exporting v3 (verbose)..."
"$EXPORTER_SCRIPT" -v3 risc-v-university all > "$DIR/llm-transcripts/v3-verbose.md"

# Export v4 (complete)
echo "Exporting v4 (complete)..."
"$EXPORTER_SCRIPT" -v4 risc-v-university all > "$DIR/llm-transcripts/v4-complete.md"

# Export v5 (raw)
echo "Exporting v5 (raw)..."
"$EXPORTER_SCRIPT" -v5 risc-v-university all > "$DIR/llm-transcripts/v5-raw.md"

echo "All conversation exports completed!"
echo "Files created/updated:"
ls -lah "$DIR/llm-transcripts/v*.md"
# }}}