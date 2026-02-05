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

