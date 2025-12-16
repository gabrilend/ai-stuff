#!/bin/bash
# {{{ GitHub HTTPS Authentication Setup
# Sets up GitHub authentication for dependency sync system

echo "🔐 GitHub HTTPS Authentication Setup"
echo "════════════════════════════════════════════"
echo ""

# Check if git credential helper is already configured
current_helper=$(git config --global credential.helper 2>/dev/null || echo "none")
echo "Current credential helper: $current_helper"
echo ""

if [[ "$current_helper" != "none" ]]; then
    echo "⚠️  Git credential helper already configured."
    echo "   Current setting: $current_helper"
    echo ""
    read -p "Do you want to reconfigure? (y/N): " reconfigure
    if [[ ! "$reconfigure" =~ ^[Yy]$ ]]; then
        echo "Keeping existing configuration."
        exit 0
    fi
fi

echo "Setting up GitHub credential helper..."

# Configure git to use credential helper
git config --global credential.helper store
echo "✅ Credential helper configured to store credentials"

# Configure git to use HTTPS for GitHub
git config --global url."https://github.com/".insteadOf git@github.com:
echo "✅ Git configured to use HTTPS for GitHub"

echo ""
echo "📋 Next Steps:"
echo "1. Create a GitHub Personal Access Token:"
echo "   → Go to GitHub → Settings → Developer Settings → Personal Access Tokens"
echo "   → Generate new token (classic)"
echo "   → Select 'repo' scope"
echo "   → Copy the token"
echo ""
echo "2. The first time you sync dependencies, you'll be prompted for:"
echo "   Username: your-github-username"
echo "   Password: paste-your-personal-access-token"
echo ""
echo "3. Credentials will be stored for future use"
echo ""
echo "🔧 Test the setup by running:"
echo "   ./libs/dependency-sync.sh clean"
echo "   ./libs/dependency-sync.sh sync"
echo ""