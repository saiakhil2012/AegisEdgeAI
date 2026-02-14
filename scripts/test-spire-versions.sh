#!/bin/bash
set -e

# Test SPIRE overlay across multiple versions
# Usage: ./scripts/test-spire-versions.sh [version1] [version2] ...
# Example: ./scripts/test-spire-versions.sh v1.14.1 main

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default versions to test
DEFAULT_VERSIONS=("v1.14.1" "main")
VERSIONS=("${@:-${DEFAULT_VERSIONS[@]}}")

echo "🧪 Testing SPIRE Overlay Across Multiple Versions"
echo "=================================================="
echo ""

# Test results tracking
PASSED=()
FAILED=()
TOTAL=0

for VERSION in "${VERSIONS[@]}"; do
    TOTAL=$((TOTAL + 1))
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Test $TOTAL/${#VERSIONS[@]}: SPIRE $VERSION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Clean previous build
    echo "🧹 Cleaning previous build..."
    rm -rf "$PROJECT_ROOT/build"
    
    # Set version and build
    echo "🔨 Building SPIRE $VERSION with overlay..."
    export SPIRE_VERSION="$VERSION"
    
    if SPIRE_VERSION="$VERSION" "$SCRIPT_DIR/spire-build.sh" > "/tmp/spire-build-${VERSION}.log" 2>&1; then
        # Build succeeded
        echo "   ✅ Build: SUCCESS"
        
        # Verify binaries
        if [ -f "$PROJECT_ROOT/build/spire-binaries/spire-server" ] && \
           [ -f "$PROJECT_ROOT/build/spire-binaries/spire-agent" ]; then
            
            SERVER_VERSION=$("$PROJECT_ROOT/build/spire-binaries/spire-server" --version 2>/dev/null || echo "unknown")
            AGENT_VERSION=$("$PROJECT_ROOT/build/spire-binaries/spire-agent" --version 2>/dev/null || echo "unknown")
            
            echo "   ✅ Binaries: VERIFIED"
            echo "      Server: $SERVER_VERSION"
            echo "      Agent:  $AGENT_VERSION"
            
            # Check proto compilation
            if [ -f "$PROJECT_ROOT/build/spire-api-sdk/proto/spire/api/types/sovereignattestation.pb.go" ]; then
                echo "   ✅ Proto: COMPILED"
                
                # Verify our custom types exist
                if grep -q "SovereignAttestation" "$PROJECT_ROOT/build/spire-api-sdk/proto/spire/api/types/sovereignattestation.pb.go" 2>/dev/null; then
                    echo "   ✅ Custom Types: PRESENT"
                    PASSED+=("$VERSION")
                    echo ""
                    echo "🎉 PASS: SPIRE $VERSION"
                else
                    echo "   ❌ Custom Types: MISSING"
                    FAILED+=("$VERSION (custom types missing)")
                    echo ""
                    echo "❌ FAIL: SPIRE $VERSION"
                fi
            else
                echo "   ❌ Proto: NOT COMPILED"
                FAILED+=("$VERSION (proto compilation failed)")
                echo ""
                echo "❌ FAIL: SPIRE $VERSION"
            fi
        else
            echo "   ❌ Binaries: NOT FOUND"
            FAILED+=("$VERSION (binaries not found)")
            echo ""
            echo "❌ FAIL: SPIRE $VERSION"
        fi
    else
        # Build failed
        echo "   ❌ Build: FAILED"
        echo "      Log: /tmp/spire-build-${VERSION}.log"
        FAILED+=("$VERSION (build failed)")
        echo ""
        echo "❌ FAIL: SPIRE $VERSION"
    fi
    
    # Show last 20 lines of log if failed
    if [[ " ${FAILED[@]} " =~ " ${VERSION} " ]] || [[ " ${FAILED[@]} " =~ " ${VERSION} (" ]]; then
        echo ""
        echo "📝 Build log tail:"
        tail -20 "/tmp/spire-build-${VERSION}.log" 2>/dev/null || echo "   (log not available)"
    fi
done

# Summary
echo ""
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Total Tests:  $TOTAL"
echo "Passed:       ${#PASSED[@]}"
echo "Failed:       ${#FAILED[@]}"
echo ""

if [ ${#PASSED[@]} -gt 0 ]; then
    echo "✅ Passed Versions:"
    for v in "${PASSED[@]}"; do
        echo "   - $v"
    done
    echo ""
fi

if [ ${#FAILED[@]} -gt 0 ]; then
    echo "❌ Failed Versions:"
    for v in "${FAILED[@]}"; do
        echo "   - $v"
    done
    echo ""
    echo "Build logs available at: /tmp/spire-build-*.log"
    exit 1
fi

echo "🎉 All versions passed!"
echo ""
echo "Tested versions are compatible with the overlay system."
exit 0
