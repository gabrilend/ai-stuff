#!/bin/bash
# {{{ Store GitHub Token for HTTPS Authentication

echo "🔐 Store GitHub Personal Access Token"
echo "═══════════════════════════════════════════"
echo ""

# Check if credential helper is configured
credential_helper=$(git config --global credential.helper 2>/dev/null)
if [[ -z "$credential_helper" ]]; then
    echo "⚠️  Git credential helper not configured. Setting up..."
    git config --global credential.helper store
    echo "✅ Credential helper configured"
else
    echo "✅ Credential helper already configured: $credential_helper"
fi

echo ""
echo "📋 To store your GitHub token, you have several options:"
echo ""

echo "Option 1: Manual credential file (recommended)"
echo "─────────────────────────────────────────────"
echo "Create ~/.git-credentials file manually:"
echo ""
read -p "Enter your GitHub username: " username
read -s -p "Enter your GitHub personal access token: " token
echo ""

if [[ -n "$username" && -n "$token" ]]; then
    echo "https://$username:$token@github.com" >> ~/.git-credentials
    chmod 600 ~/.git-credentials
    echo "✅ Credentials stored in ~/.git-credentials"
    echo ""
    echo "🧪 Testing authentication..."
    if git ls-remote https://github.com/gabrilend/adroit.git >/dev/null 2>&1; then
        echo "✅ GitHub authentication working!"
    else
        echo "❌ Authentication test failed. Check your token."
    fi
else
    echo "❌ Username or token not provided"
fi

echo ""
echo "Option 2: Use git credential fill (alternative)"
echo "──────────────────────────────────────────────"
echo "If you prefer, you can also store credentials by running:"
echo "  git credential fill"
echo "Then enter:"
echo "  protocol=https"
echo "  host=github.com"
echo "  username=your-username"
echo "  password=your-token"
echo "  [press Enter twice]"

echo ""
echo "Option 3: Let git prompt naturally"
echo "─────────────────────────────────────────"
echo "Make a test push to trigger credential prompt:"
echo "  cd /mnt/mtwo/programming/ai-stuff/adroit"
echo "  touch test-file"
echo "  git add test-file"
echo "  git commit -m 'test'"
echo "  git push"
echo ""
echo "Git will prompt for username/token and store them automatically."

echo ""
echo "🔍 Current credential status:"
if [[ -f ~/.git-credentials ]]; then
    echo "✅ Credentials file exists: ~/.git-credentials"
    echo "   Contains $(wc -l < ~/.git-credentials) stored credential(s)"
else
    echo "❌ No credentials file found"
fi