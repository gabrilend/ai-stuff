#!/bin/bash
# {{{ Test GitHub Authentication
# Forces git to authenticate and store credentials

echo "🧪 GitHub Authentication Test"
echo "════════════════════════════════"
echo ""

echo "This script will test GitHub authentication by attempting to access repository metadata"
echo "that requires authentication, forcing git to prompt for credentials."
echo ""

read -p "Continue with authentication test? (y/N): " continue_test
if [[ ! "$continue_test" =~ ^[Yy]$ ]]; then
    echo "Test cancelled."
    exit 0
fi

echo ""
echo "🔍 Testing repository access..."

# Try to access repository information that might require auth
echo "Attempting to list remote branches (may prompt for credentials)..."

if git ls-remote --heads https://github.com/gabrilend/adroit.git; then
    echo ""
    echo "✅ Repository access successful!"
    echo ""
    
    # Check if credentials were stored
    if [[ -f ~/.git-credentials ]]; then
        echo "✅ Credentials stored in ~/.git-credentials"
        echo "   File contains $(wc -l < ~/.git-credentials) credential entry(ies)"
    else
        echo "⚠️  No credentials file found - repository might be public"
    fi
else
    echo ""
    echo "❌ Repository access failed"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "1. Make sure you have a valid GitHub Personal Access Token"
    echo "2. Token should have 'repo' scope for private repositories"
    echo "3. Try running: ./libs/store-github-token.sh"
fi

echo ""
echo "📊 Current git credential configuration:"
echo "Global credential helper: $(git config --global credential.helper || echo 'not set')"
echo "Local credential helper: $(git config credential.helper || echo 'not set')"

if [[ -f ~/.git-credentials ]]; then
    echo ""
    echo "📝 Stored credentials preview:"
    echo "   File: ~/.git-credentials"
    echo "   Permissions: $(stat -c %a ~/.git-credentials 2>/dev/null || echo 'unknown')"
    echo "   Entries: $(grep -c "github.com" ~/.git-credentials 2>/dev/null || echo '0') GitHub entries"
fi