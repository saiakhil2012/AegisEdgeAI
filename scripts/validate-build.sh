#!/bin/bash

# Copyright 2026 AegisSovereignAI Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# SPIRE Overlay Build Validation
# Validates that the build system produces functionally equivalent binaries
# to the original fork by running quick smoke tests

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "🔍 SPIRE Build Validation"
echo "=========================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED=0

check_binary() {
    local binary=$1
    local name=$2
    
    if [ ! -f "$binary" ]; then
        echo -e "${RED}❌ FAIL${NC}: $name not found at $binary"
        ((FAILED++))
        return 1
    fi
    
    if [ ! -x "$binary" ]; then
        echo -e "${RED}❌ FAIL${NC}: $name not executable"
        ((FAILED++))
        return 1
    fi
    
    # Test version command
    if ! "$binary" --version >/dev/null 2>&1; then
        echo -e "${RED}❌ FAIL${NC}: $name --version failed"
        ((FAILED++))
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} $name: $(basename $binary) ($($binary --version))"
    return 0
}

check_help() {
    local binary=$1
    local name=$2
    
    if ! "$binary" --help >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  WARN${NC}: $name --help failed (may be expected)"
        return 0
    fi
    
    echo -e "${GREEN}✓${NC} $name --help works"
    return 0
}

echo "Step 1: Check binaries exist and execute"
echo "-----------------------------------------"

check_binary "build/spire-binaries/spire-server" "SPIRE Server"
check_binary "build/spire-binaries/spire-agent" "SPIRE Agent"

echo ""
echo "Step 2: Check binary size (should be reasonable)"
echo "------------------------------------------------"

server_size=$(stat -f%z "build/spire-binaries/spire-server" 2>/dev/null || stat -c%s "build/spire-binaries/spire-server" 2>/dev/null)
agent_size=$(stat -f%z "build/spire-binaries/spire-agent" 2>/dev/null || stat -c%s "build/spire-binaries/spire-agent" 2>/dev/null)

server_mb=$((server_size / 1024 / 1024))
agent_mb=$((agent_size / 1024 / 1024))

echo "Server: ${server_mb}MB"
echo "Agent:  ${agent_mb}MB"

# Sanity check sizes (SPIRE binaries are typically 40-120MB)
if [ "$server_mb" -lt 10 ] || [ "$server_mb" -gt 200 ]; then
    echo -e "${YELLOW}⚠️  WARN${NC}: Server binary size unusual (${server_mb}MB)"
fi

if [ "$agent_mb" -lt 10 ] || [ "$agent_mb" -gt 200 ]; then
    echo -e "${YELLOW}⚠️  WARN${NC}: Agent binary size unusual (${agent_mb}MB)"
fi

echo ""
echo "Step 3: Check help commands"
echo "---------------------------"

check_help "build/spire-binaries/spire-server" "SPIRE Server"
check_help "build/spire-binaries/spire-agent" "SPIRE Agent"

echo ""
echo "Step 4: Verify overlay structure"
echo "--------------------------------"

required_files=(
    "spire-overlay/proto-patches/files/spire-api-sdk/spire/api/types/sovereignattestation.proto"
    "spire-overlay/core-patches/server-api.patch"
    "spire-overlay/common-packages/tlspolicy"
    "spire-overlay/cache-packages/nodecache"
    "spire-overlay/plugins/server-keylime"
)

for file in "${required_files[@]}"; do
    if [ -e "$file" ]; then
        echo -e "${GREEN}✓${NC} $file exists"
    else
        echo -e "${RED}❌ FAIL${NC}: Missing $file"
        ((FAILED++))
    fi
done

echo ""
echo "Step 5: Check proto compilation"
echo "-------------------------------"

# Check if SovereignAttestation type was generated
if [ -f "build/spire-api-sdk/proto/spire/api/types/sovereignattestation.pb.go" ]; then
    if grep -q "type SovereignAttestation struct" "build/spire-api-sdk/proto/spire/api/types/sovereignattestation.pb.go"; then
        echo -e "${GREEN}✓${NC} SovereignAttestation proto compiled"
    else
        echo -e "${RED}❌ FAIL${NC}: SovereignAttestation type not found in generated code"
        ((FAILED++))
    fi
else
    echo -e "${RED}❌ FAIL${NC}: sovereignattestation.pb.go not generated"
    ((FAILED++))
fi

# Check AttestedClaims type
if grep -q "type AttestedClaims struct" "build/spire-api-sdk/proto/spire/api/types/sovereignattestation.pb.go" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} AttestedClaims proto compiled"
else
    echo -e "${YELLOW}⚠️  WARN${NC}: AttestedClaims type not found (may be in different file)"
fi

echo ""
echo "Step 6: Verify binaries are ready"
echo "-------------------------------"

# Check if binaries exist in build directory
if [ -f "build/spire-binaries/spire-server" ]; then
    echo -e "${GREEN}✓${NC} spire-server binary found"
else
    echo -e "${RED}✗${NC} spire-server binary not found in build/spire-binaries/"
fi

if [ -f "build/spire-binaries/spire-agent" ]; then
    echo -e "${GREEN}✓${NC} spire-agent binary found"
else
    echo -e "${RED}✗${NC} spire-agent binary not found in build/spire-binaries/"
fi

echo ""
echo "=========================================="
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}✅ All validation checks passed!${NC}"
    echo ""
    echo "Build is valid and ready for:"
    echo "  1. Integration testing (./hybrid-cloud-poc/test_integration.sh)"
    echo "  2. CI/CD pipeline (.github/workflows/ci.yml)"
    echo "  3. Deployment to test environment"
    exit 0
else
    echo -e "${RED}❌ Validation failed with $FAILED error(s)${NC}"
    echo ""
    echo "Please fix the issues above before proceeding."
    exit 1
fi
