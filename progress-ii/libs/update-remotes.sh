#!/bin/bash
# {{{ Update Repository Remotes to HTTPS
# Updates existing git remotes from SSH to HTTPS

echo "🔄 Updating Git Remotes to HTTPS"
echo "═══════════════════════════════════════"
echo ""

# Update adroit repository if it exists
ADROIT_PATH="/mnt/mtwo/programming/ai-stuff/adroit"

if [[ -d "$ADROIT_PATH/.git" ]]; then
    echo "📦 Updating adroit repository remote..."
    cd "$ADROIT_PATH" || exit 1
    
    current_remote=$(git remote get-url origin 2>/dev/null || echo "none")
    echo "   Current remote: $current_remote"
    
    # Update remote to HTTPS
    git remote set-url origin https://github.com/gabrilend/adroit.git
    new_remote=$(git remote get-url origin)
    echo "   New remote: $new_remote"
    echo "   ✅ Adroit remote updated"
else
    echo "   ⚠️  Adroit repository not found at $ADROIT_PATH"
fi

echo ""

# Update progress-ii repository 
PROGRESS_II_PATH="/home/ritz/programming/ai-stuff/progress-ii"

if [[ -d "$PROGRESS_II_PATH/.git" ]]; then
    echo "📦 Updating progress-ii repository remote..."
    cd "$PROGRESS_II_PATH" || exit 1
    
    current_remote=$(git remote get-url origin 2>/dev/null || echo "none")
    echo "   Current remote: $current_remote"
    
    if [[ "$current_remote" == *"progress-ii"* ]]; then
        # Update to HTTPS if it's using SSH
        if [[ "$current_remote" == git@* ]]; then
            # Extract the repo path from SSH URL and convert to HTTPS
            repo_path=$(echo "$current_remote" | sed 's/git@github[^:]*://g')
            new_url="https://github.com/$repo_path"
            git remote set-url origin "$new_url"
            echo "   New remote: $new_url"
            echo "   ✅ Progress-ii remote updated"
        else
            echo "   ✅ Progress-ii already using HTTPS"
        fi
    fi
else
    echo "   ⚠️  Progress-ii repository not found at $PROGRESS_II_PATH"
fi

echo ""
echo "🎯 Remote updates complete!"
echo "   All repositories now use HTTPS authentication"
echo ""
echo "🔧 Next: Run './libs/setup-github-auth.sh' to configure credentials"