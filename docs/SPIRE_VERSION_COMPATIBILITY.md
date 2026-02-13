# SPIRE Version Compatibility

## Overview

This document tracks SPIRE version compatibility testing for the AegisSovereignAI overlay system.

## Tested Versions

### v1.10.3 (Initial Development)
- **Status**: ✅ Fully Compatible
- **Date Tested**: December 2024 - February 2025
- **Notes**: Original development version. All overlay patches apply cleanly.

### v1.14.1 (Latest Stable)
- **Status**: ✅ Fully Compatible  
- **Date Tested**: February 13, 2025
- **Build Result**: SUCCESS
- **Binary Versions**: `1.14.1-dev-unk`
- **Notes**: Required WITSVID proto updates to overlay. See "Breaking Changes" section.

## Breaking Changes from v1.10.3 → v1.14.1

### WITSVID Support (Added in SPIRE)

**Issue**: SPIRE v1.14.1 added WIT-SVID (Workload Identity Token SVID) support, which introduced new RPC methods in `svid.proto`.

**Error Encountered**:
```
pkg/server/api/svid/v1/service.go:163:64: undefined: svidv1.MintWITSVIDRequest
pkg/server/api/svid/v1/service.go:163:93: undefined: svidv1.MintWITSVIDResponse
pkg/server/api/svid/v1/service.go:394:68: undefined: svidv1.BatchNewWITSVIDRequest
pkg/server/api/svid/v1/service.go:394:101: undefined: svidv1.BatchNewWITSVIDResponse
```

**Resolution**:
Updated `spire-overlay/proto-patches/files/spire-api-sdk/spire/api/server/svid/v1/svid.proto` to include:

1. Import `witsvid.proto`:
   ```proto
   import "spire/api/types/witsvid.proto";
   ```

2. Add RPC methods:
   ```proto
   rpc MintWITSVID(MintWITSVIDRequest) returns (MintWITSVIDResponse);
   rpc BatchNewWITSVID(BatchNewWITSVIDRequest) returns (BatchNewWITSVIDResponse);
   ```

3. Add message types:
   - `MintWITSVIDRequest`
   - `MintWITSVIDResponse`
   - `BatchNewWITSVIDRequest`
   - `BatchNewWITSVIDResponse`
   - `NewWITSVIDParams`

**Commit**: `7481d316` - "Update SPIRE overlay to support v1.14.1"

## Version Jump Strategy

When updating to newer SPIRE versions:

1. **Clone target version**:
   ```bash
   git clone --depth 1 --branch v1.X.Y https://github.com/spiffe/spire.git /tmp/spire-vX.Y
   ```

2. **Check changelog**:
   ```bash
   cd /tmp/spire-vX.Y
   git log v1.10.3..v1.X.Y --oneline | grep -i "proto\|api\|plugin"
   ```

3. **Test build**:
   ```bash
   rm -rf build
   ./scripts/spire-build.sh
   ```

4. **Review build errors** in `/tmp/spire-build.log`

5. **Update overlay patches** to match new SPIRE APIs

6. **Verify binaries**:
   ```bash
   build/spire-binaries/spire-server --version
   build/spire-binaries/spire-agent --version
   ```

## Upstreaming Considerations

Before submitting PRs to `spiffe/spire`, we test overlay compatibility with:

- **Latest stable release** (currently v1.14.1)
- **Previous LTS version** (for backward compatibility)
- **Main branch** (upcoming release)

This ensures our proposed changes work across SPIRE versions maintainers care about.

## CI Multi-Version Testing

TODO: Add GitHub Actions matrix to test overlay on:
- `v1.10.3` (baseline)
- `v1.14.1` (latest stable)
- `main` (development)

## Resources

- [SPIRE Releases](https://github.com/spiffe/spire/releases)
- [SPIRE API SDK Releases](https://github.com/spiffe/spire-api-sdk/releases)
- [WIT-SVID PR](https://github.com/spiffe/spire-api-sdk/pull/80)
