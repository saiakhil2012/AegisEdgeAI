#!/bin/bash
set -e

# Extract AegisSovereignAI SPIRE modifications from current fork
# This creates a clean overlay structure for maintainability

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SPIRE_FORK="$PROJECT_ROOT/hybrid-cloud-poc/spire"
SPIRE_API_SDK="$PROJECT_ROOT/hybrid-cloud-poc/spire-api-sdk"
OUTPUT_DIR="$PROJECT_ROOT/spire-overlay"
UPSTREAM_BRANCH="upstream/main"

echo "🔍 Extracting AegisSovereignAI SPIRE modifications"
echo "   Source: $SPIRE_FORK"
echo "   API SDK: $SPIRE_API_SDK"
echo "   Output: $OUTPUT_DIR"
echo ""

# Verify SPIRE fork exists
if [ ! -d "$SPIRE_FORK" ]; then
    echo "❌ SPIRE fork not found at $SPIRE_FORK"
    exit 1
fi

# Create output structure
mkdir -p "$OUTPUT_DIR"/{proto-patches,core-patches,plugins,docs}

echo "📋 Step 1: Extract proto modifications"

# Check spire-api-sdk for custom proto files
PROTO_COUNT=0
if [ -d "$SPIRE_API_SDK/proto" ]; then
    echo "   Checking spire-api-sdk proto files..."
    
    # Copy sovereignattestation.proto
    if [ -f "$SPIRE_API_SDK/proto/spire/api/types/sovereignattestation.proto" ]; then
        mkdir -p "$OUTPUT_DIR/proto-patches/files/spire-api-sdk/spire/api/types"
        cp "$SPIRE_API_SDK/proto/spire/api/types/sovereignattestation.proto" \
           "$OUTPUT_DIR/proto-patches/files/spire-api-sdk/spire/api/types/"
        echo "   ✓ Copied sovereignattestation.proto"
        ((PROTO_COUNT++))
    fi
    
    # Copy attestation.proto if custom
    if [ -f "$SPIRE_API_SDK/proto/spire/api/types/attestation.proto" ]; then
        cp "$SPIRE_API_SDK/proto/spire/api/types/attestation.proto" \
           "$OUTPUT_DIR/proto-patches/files/spire-api-sdk/spire/api/types/"
        echo "   ✓ Copied attestation.proto"
        ((PROTO_COUNT++))
    fi
    
    # Also check for server/agent proto modifications
    for proto_dir in "$SPIRE_API_SDK/proto/spire/api/server/agent/v1" "$SPIRE_API_SDK/proto/spire/api/server/svid/v1"; do
        if [ -d "$proto_dir" ]; then
            rel_path="${proto_dir#$SPIRE_API_SDK/proto/}"
            for proto_file in "$proto_dir"/*.proto; do
                if [ -f "$proto_file" ] && grep -q "SovereignAttestation\|HardwareAttestation" "$proto_file" 2>/dev/null; then
                    dest_dir="$OUTPUT_DIR/proto-patches/files/spire-api-sdk/$rel_path"
                    mkdir -p "$dest_dir"
                    cp "$proto_file" "$dest_dir/"
                    echo "   ✓ Copied $(basename $proto_file)"
                    ((PROTO_COUNT++))
                fi
            done
        fi
    done
fi

if [ $PROTO_COUNT -gt 0 ]; then
    cat > "$OUTPUT_DIR/proto-patches/README.md" << 'EOFPROTO'
# Proto Patches

Modified proto files for SovereignAttestation/HardwareAttestation API.

## Files
- `files/spire-api-sdk/` - Custom proto from spire-api-sdk

## Usage
During build, these files are copied to ../spire-api-sdk/proto/ in the build directory.
EOFPROTO
    echo "   ✓ Extracted $PROTO_COUNT proto files"
else
    echo "   ⚠️  No custom proto files found"
fi

cd "$SPIRE_FORK"

echo ""
echo "📋 Step 2: Extract server API modifications"
if [ -d "pkg/server/api" ]; then
    git diff $UPSTREAM_BRANCH -- pkg/server/api/ > "$OUTPUT_DIR/core-patches/server-api.patch" 2>/dev/null || true
    
    if [ -s "$OUTPUT_DIR/core-patches/server-api.patch" ]; then
        echo "   ✓ Extracted server API patches"
    else
        echo "   ⚠️  No server API modifications found"
        rm -f "$OUTPUT_DIR/core-patches/server-api.patch"
    fi
fi

echo ""
echo "📋 Step 3: Extract server core modifications"
if [ -d "pkg/server/endpoints" ]; then
    git diff $UPSTREAM_BRANCH -- pkg/server/endpoints/ > "$OUTPUT_DIR/core-patches/server-endpoints.patch" 2>/dev/null || true
fi

if [ -d "pkg/common/fflag" ]; then
    git diff $UPSTREAM_BRANCH -- pkg/common/fflag/ > "$OUTPUT_DIR/core-patches/feature-flags.patch" 2>/dev/null || true
fi

echo ""
echo "📋 Step 4: Extract custom plugins and modules"

# Extract common packages (used by patches)
if [ -d "pkg/common/tlspolicy" ]; then
    echo "   Copying tlspolicy package..."
    mkdir -p "$OUTPUT_DIR/common-packages/tlspolicy"
    cp -r "pkg/common/tlspolicy/"* "$OUTPUT_DIR/common-packages/tlspolicy/"
    echo "   ✓ tlspolicy package copied"
fi

if [ -d "pkg/common/pluginconf" ]; then
    echo "   Copying pluginconf package..."
    mkdir -p "$OUTPUT_DIR/common-packages/pluginconf"
    cp -r "pkg/common/pluginconf/"* "$OUTPUT_DIR/common-packages/pluginconf/"
    echo "   ✓ pluginconf package copied"
fi

# Extract server cache packages (used by patches)
if [ -d "pkg/server/cache/nodecache" ]; then
    echo "   Copying nodecache package..."
    mkdir -p "$OUTPUT_DIR/cache-packages/nodecache"
    cp -r "pkg/server/cache/nodecache/"* "$OUTPUT_DIR/cache-packages/nodecache/"
    echo "   ✓ nodecache package copied"
fi

# Extract server support modules (dependencies for plugins)
if [ -d "pkg/server/keylime" ]; then
    echo "   Copying Keylime integration..."
    cp -r "pkg/server/keylime" "$OUTPUT_DIR/plugins/server-keylime/"
    echo "   ✓ Keylime module copied"
fi

if [ -d "pkg/server/policy" ]; then
    echo "   Copying policy engine..."
    cp -r "pkg/server/policy" "$OUTPUT_DIR/plugins/server-policy/"
    echo "   ✓ Policy module copied"
fi

# Server unified identity module
if [ -d "pkg/server/unifiedidentity" ]; then
    echo "   Copying unified identity server module..."
    cp -r "pkg/server/unifiedidentity" "$OUTPUT_DIR/plugins/server-unifiedidentity/"
    echo "   ✓ Server unified identity module copied"
fi

# Agent plugin
if [ -d "pkg/agent/plugin/nodeattestor/unifiedidentity" ]; then
    echo "   Copying unified identity agent plugin..."
    cp -r "pkg/agent/plugin/nodeattestor/unifiedidentity" \
          "$OUTPUT_DIR/plugins/agent-nodeattestor-unifiedidentity/"
    echo "   ✓ Agent plugin copied"
fi

# Credential composer
if [ -d "pkg/server/plugin/credentialcomposer/unifiedidentity" ]; then
    echo "   Copying unified identity credential composer..."
    cp -r "pkg/server/plugin/credentialcomposer/unifiedidentity" \
          "$OUTPUT_DIR/plugins/server-credentialcomposer-unifiedidentity/"
    echo "   ✓ Credential composer copied"
fi

# TPM DevID (if not already in upstream-contributions)
if [ -d "pkg/agent/plugin/nodeattestor/tpmdevid" ]; then
    if [ ! -d "$PROJECT_ROOT/upstream-contributions/spire-tpm-devid-plugin" ]; then
        echo "   Copying TPM DevID plugin..."
        mkdir -p "$OUTPUT_DIR/plugins/tpm-devid"
        cp -r "pkg/agent/plugin/nodeattestor/tpmdevid" \
              "$OUTPUT_DIR/plugins/tpm-devid/agent/"
        cp -r "pkg/server/plugin/nodeattestor/tpmdevid" \
              "$OUTPUT_DIR/plugins/tpm-devid/server/" 2>/dev/null || true
        cp -r "pkg/common/plugin/tpmdevid" \
              "$OUTPUT_DIR/plugins/tpm-devid/common/" 2>/dev/null || true
        echo "   ✓ TPM DevID plugin copied"
    else
        echo "   ℹ️  TPM DevID already in upstream-contributions/"
    fi
fi

echo ""
echo "📋 Step 5: Create metadata file"

# Get current SPIRE version
SPIRE_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "unknown")
CURRENT_COMMIT=$(git rev-parse HEAD)

# Count extracted files
PLUGIN_COUNT=$(find "$OUTPUT_DIR/plugins" -name "*.go" 2>/dev/null | wc -l | tr -d ' ')
PROTO_FILE_COUNT=$(find "$OUTPUT_DIR/proto-patches/files" -name "*.proto" 2>/dev/null | wc -l | tr -d ' ')
PATCH_COUNT=$(find "$OUTPUT_DIR/core-patches" -name "*.patch" 2>/dev/null | wc -l | tr -d ' ')

cat > "$OUTPUT_DIR/patches.json" << EOF
{
  "version": "1.0.0",
  "extraction_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "base_spire_version": "$SPIRE_VERSION",
  "base_spire_commit": "$CURRENT_COMMIT",
  "proto_files": $PROTO_FILE_COUNT,
  "core_patches": $PATCH_COUNT,
  "plugin_files": $PLUGIN_COUNT,
  "modules": [
    {
      "name": "keylime",
      "path": "plugins/server-keylime",
      "type": "server-module",
      "description": "Keylime verifier integration"
    },
    {
      "name": "policy",
      "path": "plugins/server-policy",
      "type": "server-module",
      "description": "Policy engine for attestation"
    },
    {
      "name": "unifiedidentity-server",
      "path": "plugins/server-unifiedidentity",
      "type": "server-module",
      "description": "Unified identity context and claims"
    },
    {
      "name": "unifiedidentity-agent",
      "path": "plugins/agent-nodeattestor-unifiedidentity",
      "type": "agent-plugin",
      "description": "Unified identity agent attestor"
    },
    {
      "name": "unifiedidentity-composer",
      "path": "plugins/server-credentialcomposer-unifiedidentity",
      "type": "server-plugin",
      "description": "Sovereign SVID credential composer"
    }
  ]
}
EOF

echo ""
echo "📋 Step 6: Create README"

cat > "$OUTPUT_DIR/README.md" << 'EOF'
# SPIRE Overlay - AegisSovereignAI Modifications

This directory contains **only** the modifications AegisSovereignAI makes to SPIRE.

## Structure

```
spire-overlay/
├── proto-patches/          # Proto API modifications
│   └── files/              # Actual proto files
├── core-patches/           # Core SPIRE patches  
│   ├── server-api.patch
│   ├── server-endpoints.patch
│   └── feature-flags.patch
├── plugins/                # Custom plugins and modules
│   ├── server-keylime/     # Keylime integration
│   ├── server-policy/      # Policy engine
│   ├── server-unifiedidentity/  # Server module
│   ├── agent-nodeattestor-unifiedidentity/  # Agent plugin
│   └── server-credentialcomposer-unifiedidentity/  # Composer
├── patches.json            # Metadata
└── README.md              # This file
```

## Usage

**Build custom SPIRE**:
```bash
./scripts/spire-build.sh
```

**Test build**:
```bash
./scripts/spire-test.sh
```

## Components

### Proto Files
- SovereignAttestation API for hardware attestation
- Modified agent/server APIs to support hardware evidence

### Core Patches
- Server API integration for unified identity
- Feature flags for unified identity
- Endpoint modifications

### Plugins & Modules
- **Keylime**: Integration with Keylime verifier
- **Policy**: Policy engine for geolocation/attestation
- **Unified Identity**: Server-side context and claims
- **Agent Plugin**: Unified identity node attestor
- **Credential Composer**: Sovereign SVID generation

## Upstream Strategy

See [../docs/SPIRE_FORK_MAINTENANCE_STRATEGY.md](../docs/SPIRE_FORK_MAINTENANCE_STRATEGY.md)

EOF

cd "$PROJECT_ROOT"

echo ""
echo "✅ Extraction complete!"
echo ""
echo "📊 Summary:"
echo "   Proto files:    $PROTO_FILE_COUNT files"
echo "   Core patches:   $PATCH_COUNT patches"
echo "   Plugin files:   $PLUGIN_COUNT Go files"
echo ""
echo "📁 Output directory: $OUTPUT_DIR"
echo ""
echo "🚀 Next steps:"
echo "   1. Review extracted files in $OUTPUT_DIR"
echo "   2. Test build: ./scripts/spire-build.sh"
echo "   3. Commit overlay: git add spire-overlay/ && git commit"
echo ""
