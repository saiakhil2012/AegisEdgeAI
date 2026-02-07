#!/bin/bash
set -e

# Update to latest SPIRE release and test compatibility

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔄 SPIRE Update Checker"
echo ""

# Get latest SPIRE release
echo "📡 Fetching latest SPIRE release..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/spiffe/spire/releases/latest | jq -r .tag_name)

if [ -z "$LATEST_VERSION" ] || [ "$LATEST_VERSION" = "null" ]; then
    echo "❌ Failed to fetch latest SPIRE version"
    exit 1
fi

# Get current version
CURRENT_VERSION=$(cat "$PROJECT_ROOT/.spire-version" 2>/dev/null || echo "unknown")

echo "   Current: $CURRENT_VERSION"
echo "   Latest:  $LATEST_VERSION"
echo ""

# Compare versions
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    echo "✅ Already on latest version!"
    exit 0
fi

# Ask if user wants to test
read -p "🔍 Test patches against $LATEST_VERSION? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Test build with new version
echo ""
echo "🧪 Testing build with $LATEST_VERSION..."
echo ""

SPIRE_VERSION="$LATEST_VERSION" "$SCRIPT_DIR/spire-build.sh"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ SUCCESS! Patches apply cleanly to $LATEST_VERSION"
    echo ""
    echo "🚀 To update permanently:"
    echo "   echo '$LATEST_VERSION' > .spire-version"
    echo "   git add .spire-version"
    echo "   git commit -m 'Update to SPIRE $LATEST_VERSION'"
    echo ""
else
    echo ""
    echo "❌ FAILED! Patches don't apply to $LATEST_VERSION"
    echo ""
    echo "🔧 Manual rebase required:"
    echo "   1. Check build/spire/ for conflicts"
    echo "   2. Update patches in spire-overlay/"
    echo "   3. Test again: SPIRE_VERSION=$LATEST_VERSION ./scripts/spire-build.sh"
    echo ""
    exit 1
fi
