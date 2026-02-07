# Quick Start: SPIRE Overlay Build System

**Updated**: January 27, 2026

This guide shows how to use the new overlay-based SPIRE build system.

---

## TL;DR

```bash
# Extract current SPIRE modifications
./scripts/spire-extract-changes.sh

# Build custom SPIRE
./scripts/spire-build.sh

# Test build
./scripts/spire-test.sh

# Update to latest SPIRE
./scripts/spire-update.sh
```

---

## Why This Approach?

### Before ❌
- Full SPIRE fork in repo (17,315 files)
- Hard to identify custom vs upstream code
- Manual rebasing nightmare
- Can't test against new SPIRE versions easily

### After ✅
- Only our changes in repo (~50 files)
- Clean separation of custom code
- Automated build system
- Easy to test compatibility

---

## Directory Structure

```
AegisSovereignAI/
├── spire-overlay/              # ONLY our modifications
│   ├── proto-patches/          # Proto API changes
│   ├── core-patches/           # Core SPIRE patches
│   ├── plugins/                # Custom plugins
│   └── patches.json            # Metadata
│
├── scripts/
│   ├── spire-extract-changes.sh   # Extract from current fork
│   ├── spire-build.sh             # Build custom SPIRE
│   ├── spire-test.sh              # Test build
│   └── spire-update.sh            # Update to latest
│
├── upstream-contributions/     # Ready for upstream
│   └── spire-tpm-devid-plugin/
│
├── build/                      # Temporary (gitignored)
│   ├── spire/                  # Cloned SPIRE
│   └── spire-binaries/         # Built binaries
│
└── .spire-version              # Tracks SPIRE version
```

---

## Step 1: Extract Current Changes

**Run once** to extract modifications from existing fork:

```bash
./scripts/spire-extract-changes.sh
```

**What it does**:
1. Compares `hybrid-cloud-poc/spire/` against upstream
2. Extracts proto modifications to patches
3. Extracts core API changes to patches
4. Copies custom plugins
5. Creates metadata file

**Output**: `spire-overlay/` directory with only your changes

---

## Step 2: Build Custom SPIRE

```bash
./scripts/spire-build.sh
```

**What it does**:
1. Clones upstream SPIRE (default: v1.10.3)
2. Applies proto patches
3. Applies core patches
4. Installs custom plugins
5. Regenerates proto files
6. Builds binaries

**Output**: `build/spire-binaries/spire-server` and `spire-agent`

**Options**:
```bash
# Build specific version
SPIRE_VERSION=v1.11.0 ./scripts/spire-build.sh

# Build from HEAD
SPIRE_VERSION=main ./scripts/spire-build.sh
```

---

## Step 3: Test Build

```bash
./scripts/spire-test.sh
```

**What it tests**:
1. Binary verification
2. Unit tests
3. Custom plugin tests
4. Proto file consistency
5. Code quality checks

---

## Step 4: Update to Latest SPIRE

```bash
./scripts/spire-update.sh
```

**What it does**:
1. Fetches latest SPIRE release
2. Compares with current version
3. Tests if patches apply cleanly
4. Reports compatibility

---

## Upstream Strategy

### Phase 1: Proto API (Week 1-2)

**Prepare**:
```bash
cd upstream-contributions
mkdir spire-hardware-attestation-api
# Copy proto patches, write design doc
```

**Submit**: API-only PR to spiffe/spire

### Phase 2: Plugin Interface (Week 3-4)

**After Phase 1 merged**: Submit plugin interface PR

### Phase 3: Reference Implementation (Week 5-6)

**After Phase 2 merged**: Submit TPM example

---

## Migration Timeline

### Week 1 (This Week)
- [x] Create overlay build scripts ✅
- [ ] Extract current modifications
- [ ] Test extraction builds
- [ ] Commit overlay to repo

### Week 2
- [ ] Delete `hybrid-cloud-poc/spire/`
- [ ] Update documentation
- [ ] Set up CI/CD

### Week 3+
- [ ] Prepare Phase 1 upstream PR
- [ ] Submit to spiffe/spire
- [ ] Iterate on feedback

---

## Common Tasks

### Build for Development
```bash
# Build with current config
./scripts/spire-build.sh

# Binaries in build/spire-binaries/
```

### Test Changes
```bash
# Edit files in spire-overlay/plugins/
# Rebuild
./scripts/spire-build.sh

# Test
./scripts/spire-test.sh
```

### Update Patches
```bash
# Manual approach:
cd build/spire
# Make changes
git diff > ../../spire-overlay/core-patches/my-change.patch

# Rebuild to verify
cd ../..
./scripts/spire-build.sh
```

### Deploy Binaries
```bash
# Copy to deployment location
cp build/spire-binaries/spire-server /usr/local/bin/
cp build/spire-binaries/spire-agent /usr/local/bin/

# Or create symlinks
ln -s $(pwd)/build/spire-binaries/spire-server /usr/local/bin/
ln -s $(pwd)/build/spire-binaries/spire-agent /usr/local/bin/
```

---

## CI/CD Integration

### GitHub Actions

**File**: `.github/workflows/spire-build.yml`

```yaml
name: SPIRE Build

on:
  push:
    paths:
      - 'spire-overlay/**'
      - 'scripts/spire-*.sh'
  schedule:
    - cron: '0 0 * * 0'  # Weekly

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        spire-version: [v1.10.3, v1.11.0, latest]
    
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.21'
      
      - name: Build
        run: SPIRE_VERSION=${{ matrix.spire-version }} ./scripts/spire-build.sh
      
      - name: Test
        run: ./scripts/spire-test.sh
      
      - name: Upload
        uses: actions/upload-artifact@v4
        with:
          name: spire-${{ matrix.spire-version }}
          path: build/spire-binaries/
```

---

## Troubleshooting

### Patches Don't Apply

```bash
# Check what failed
cd build/spire
git status

# See conflicts
git diff

# Fix manually, regenerate patch
git diff > ../../spire-overlay/core-patches/updated.patch
```

### Build Fails

```bash
# Check build log
cat /tmp/spire-build.log

# Common issues:
# - Missing dependencies: make sure Go 1.21+ installed
# - Proto errors: run 'make generate' in build/spire
```

### Tests Fail

```bash
# See detailed output
cat /tmp/spire-test.log

# Run specific test
cd build/spire
go test ./pkg/server/plugin/credentialcomposer/unifiedidentity -v
```

---

## Maintenance

### Weekly
- Run `./scripts/spire-update.sh` to check for new releases
- Test patches apply cleanly

### Before Releases
- Build with latest SPIRE version
- Run full test suite
- Update `.spire-version`

### When Upstream Changes
- Rebase patches if needed
- Test compatibility
- Update documentation

---

## Benefits

| Metric | Before | After |
|--------|--------|-------|
| **Repo files** | 17,315 | ~50 |
| **Lines committed** | 3.5M | ~5K |
| **Build time** | Manual | 5 min automated |
| **Update testing** | Manual | 1 command |
| **Upstream prep** | Hard | Easy |

---

## Questions?

See detailed docs:
- [SPIRE_FORK_MAINTENANCE_STRATEGY.md](SPIRE_FORK_MAINTENANCE_STRATEGY.md)
- [UPSTREAM_SOVEREIGN_ATTESTATION_PROPOSAL.md](UPSTREAM_SOVEREIGN_ATTESTATION_PROPOSAL.md)

---

**Prepared by**: Bala Siva Sai Akhil Malepati  
**Date**: January 27, 2026
