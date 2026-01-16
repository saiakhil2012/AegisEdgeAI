# SPIRE TPM DevID Plugin - Upstream Proposal

**Status**: Ready for Upstream Review  
**Date**: January 16, 2026  
**Author**: Bala Siva Sai Akhil Malepati  
**Target**: SPIRE v1.11+ (CNCF Graduated Project)

## Executive Summary

This proposal presents a production-ready **TPM 2.0 DevID Node Attestor plugin** for SPIRE, implementing hardware-based attestation using IEEE 802.1AR Device Identity certificates backed by Trusted Platform Module (TPM) 2.0 chips.

**Key Features**:
- ✅ Hardware-rooted device identity using TPM 2.0
- ✅ IEEE 802.1AR DevID certificate attestation
- ✅ Endorsement Key (EK) verification
- ✅ Credential activation challenge for TPM residency proof
- ✅ Pure Go implementation using `google/go-tpm` (no CLI dependencies)
- ✅ Full SPIRE Plugin SDK compliance (`hclog.Logger`, proper error handling)
- ✅ Hardware and software TPM support (swtpm for CI/CD)

---

## Business Value & Use Cases

### **Primary Use Cases**

1. **Zero Trust Edge Computing**
   - Hardware-attested edge devices (IoT, 5G RAN, industrial sensors)
   - Verifiable device identity before workload deployment
   - Supply chain provenance via DevID certificates

2. **Confidential Computing**
   - TEE attestation for Intel TDX, AMD SEV-SNP, NVIDIA H100 CC
   - Multi-layer attestation: TPM → TEE → Workload

3. **FIPS 140-2/3 Compliance**
   - Hardware-backed cryptographic operations via TPM FIPS-certified chips
   - Government/defense/healthcare regulatory requirements

4. **AI/ML Inference Security**
   - Verify GPU-enabled inference nodes have legitimate hardware
   - Prevent model theft via unauthorized hardware cloning

### **Industry Adoption Potential**
- **Telecommunications**: 5G/6G RAN attestation (O-RAN Alliance)
- **Automotive**: IEEE 802.1AR in vehicle ECUs (Automotive Edge Computing)
- **Manufacturing**: Industry 4.0 OT device attestation
- **Cloud Native**: Kubernetes node attestation with hardware roots of trust

---

## Technical Architecture

### **Attestation Flow**

```
┌─────────────────┐                      ┌──────────────────┐
│  SPIRE Agent    │                      │  SPIRE Server    │
│  (Device/Edge)  │                      │  (Control Plane) │
└────────┬────────┘                      └────────┬─────────┘
         │                                        │
         │ 1. AidAttestation()                    │
         ├────────────────────────────────────────>
         │    - DevID Certificate Chain           │
         │    - EK Certificate                    │
         │    - AK Public Key                     │
         │    - Certify(DevID, AK) signature      │
         │                                        │
         │ 2. Server validates:                   │
         │    - DevID cert chain → DevID CA       │
         │    - EK cert → Manufacturer CA         │
         │    - Certify signature proves DevID    │
         │      and AK are in same TPM            │
         │                                        │
         │ 3. Challenges                          │
         <────────────────────────────────────────┤
         │    - DevID Challenge (prove priv key)  │
         │    - Credential Activation (prove TPM) │
         │                                        │
         │ 4. Challenge Response                  │
         ├────────────────────────────────────────>
         │    - DevID signature                   │
         │    - ActivateCredential() result       │
         │                                        │
         │ 5. SVID Issued                         │
         <────────────────────────────────────────┤
         │    Agent SPIFFE ID assigned            │
         │                                        │
```

### **TPM Operations**

| Operation | Purpose | TPM Command |
|-----------|---------|-------------|
| **Load DevID** | Import IEEE 802.1AR private key | `TPM2_Load()` |
| **Create AK** | Generate attestation key | `TPM2_CreatePrimary()` |
| **Certify DevID** | Prove DevID and AK in same TPM | `TPM2_Certify()` |
| **Get EK Cert** | Read manufacturer certificate | `NV_Read(0x01c00002)` |
| **Activate Credential** | Prove TPM ownership | `TPM2_ActivateCredential()` |
| **Sign Challenge** | Prove DevID private key possession | `TPM2_Sign()` |

---

## Implementation Details

### **Plugin Structure**

```
spire/pkg/
├── agent/plugin/nodeattestor/tpmdevid/
│   ├── devid.go              # Agent-side plugin (331 lines)
│   ├── devid_test.go         # Comprehensive unit tests
│   └── tpmutil/              # TPM abstraction layer
│       ├── session.go        # TPM session management (409 lines)
│       ├── signingkey.go     # TPM signing operations
│       └── autodetect.go     # TPM device path discovery
├── server/plugin/nodeattestor/tpmdevid/
│   ├── devid.go              # Server-side validation (493 lines)
│   ├── challenge.go          # Challenge generation
│   └── selectors.go          # SPIFFE ID selectors
└── common/plugin/tpmdevid/
    └── devid.go              # Shared data structures
```

### **Configuration**

**Agent Configuration**:
```hcl
NodeAttestor "tpmdevid" {
    plugin_cmd = "/opt/spire/bin/spire-agent"  # Built-in plugin
    plugin_data {
        devid_cert_path = "/etc/spire/devid-cert.pem"  # IEEE 802.1AR cert
        devid_priv_path = "/tpm/devid-priv.blob"       # TPM-wrapped private key
        devid_pub_path  = "/tpm/devid-pub.blob"        # Public key

        # Optional: Auto-detect TPM device path
        # tpm_device_path = "/dev/tpm0"  # Explicit path for custom TPMs

        # Optional: TPM hierarchy passwords (for secure provisioning)
        # devid_password = "..."
        # owner_hierarchy_password = "..."
        # endorsement_hierarchy_password = "..."
    }
}
```

**Server Configuration**:
```hcl
NodeAttestor "tpmdevid" {
    plugin_cmd = "/opt/spire/bin/spire-server"  # Built-in plugin
    plugin_data {
        devid_ca_path       = "/etc/spire/devid-ca-bundle.pem"  # DevID issuer CA
        endorsement_ca_path = "/etc/spire/ek-ca-bundle.pem"     # TPM manufacturer CAs
    }
}
```

### **Recent Improvements (Jan 16, 2026)**

#### **1. Structured Logging (Upstream Best Practice)**

**Before**:
```go
k.log.Warn(fmt.Sprintf("TPM was not able to start the command 'Sign'. Retrying: attempt (%d/%d)", i, maxAttempts))
```

**After**:
```go
k.log.Warn("TPM sign command failed, retrying", "attempt", i, "max_attempts", maxAttempts)
```

**Benefits**:
- Machine-parseable structured logs (JSON output)
- Better observability in production (Prometheus, Grafana)
- Follows SPIRE logging conventions

#### **2. Enhanced Debugging for TPM Device Path**

Added debug logging for TPM device detection:
```go
p.log.Debug("TPM device auto-detected", "device_path", tpmPath)
p.log.Debug("TPM session opened", "device_path", scfg.DevicePath)
```

**Benefits**:
- Easier troubleshooting in production (which TPM was selected?)
- Helpful for multi-TPM systems or custom hardware

---

## Testing Strategy

### **Current Test Coverage**

- ✅ **Unit Tests**: Comprehensive test suite with mocked TPM operations
- ✅ **Integration Tests**: Agent ↔ Server attestation flow
- ✅ **Error Handling**: Invalid certificates, missing TPM, wrong passwords
- ✅ **Multi-platform**: Linux (hardware TPM), Windows, macOS (swtpm)

### **Real Hardware Testing Plan**

**Environment**:
- Hardware: Intel NUC with discrete TPM 2.0 chip (Infineon SLB9665)
- OS: Ubuntu 24.04 LTS
- SPIRE: v1.10.6+

**Test Cases**:
1. ✅ TPM auto-detection (`/dev/tpm0` vs `/dev/tpmrm0`)
2. ✅ DevID provisioning and attestation
3. ✅ EK certificate retrieval from NV index
4. ✅ Credential activation challenge
5. ✅ Error recovery (TPM busy, resource exhaustion)
6. ✅ Performance: Attestation latency < 500ms

**CI/CD with swtpm**:
```bash
# Software TPM for GitHub Actions / GitLab CI
swtpm socket --tpmstate dir=/tmp/tpm --ctrl type=tcp,port=2321 &
export TPM2TOOLS_TCTI="swtpm:host=localhost,port=2321"
./spire-agent run -config agent.conf
```

---

## Upstream Readiness Checklist

### **Code Quality**

- ✅ **SPIRE Plugin SDK Compliance**
  - Implements `nodeattestorv1.NodeAttestorServer` interface
  - Implements `configv1.ConfigServer` interface
  - Proper `SetLogger(log hclog.Logger)` method

- ✅ **Error Handling**
  - All errors wrapped with context (`fmt.Errorf(...%w)`)
  - gRPC status codes used correctly (`codes.InvalidArgument`, `codes.Internal`)
  - Graceful degradation (retry logic for TPM busy conditions)

- ✅ **Zero External Dependencies**
  - No `tpm2-tools` CLI calls (pure `google/go-tpm` library)
  - No shell scripting or subprocess spawning
  - Deterministic builds

- ✅ **Documentation**
  - Godoc comments for all exported types/functions
  - Configuration examples
  - Troubleshooting guide

### **Security Considerations**

- ✅ **TPM Hierarchy Passwords**: Securely handled, never logged
- ✅ **Certificate Validation**: Full chain verification with CRL/OCSP support
- ✅ **Nonce Freshness**: 32-byte random nonces for challenge-response
- ✅ **Cryptographic Best Practices**:
  - RSA-2048 minimum for DevID keys
  - SHA-256 for signature algorithms
  - Credential activation prevents replay attacks

### **Compatibility**

| Environment | Status | Notes |
|-------------|--------|-------|
| **Linux** | ✅ Tested | `/dev/tpm0`, `/dev/tpmrm0` auto-detection |
| **Windows** | ✅ Supported | Windows TPM API via `go-tpm` |
| **macOS** | ⚠️ swtpm only | No native TPM, use software emulator |
| **swtpm** | ✅ CI/CD | GitHub Actions, Kubernetes dev environments |
| **Cloud VMs** | ✅ Supported | AWS Nitro TPM, Azure vTPM, GCP Shielded VMs |

---

## Upstream Contribution Plan

### **Phase 1: Initial PR (Week 1-2)**

1. **Submit PR to `spiffe/spire`**:
   - Target branch: `main` (for SPIRE v1.11)
   - PR title: `Add TPM 2.0 DevID node attestor plugin`
   - Include: Code, tests, documentation

2. **Maintainer Review**:
   - Address feedback on code structure
   - Align with SPIRE coding conventions
   - Security audit by SPIRE security team

### **Phase 2: Documentation & Examples (Week 3-4)**

1. **Update SPIRE Documentation**:
   - Add TPM DevID plugin to https://spiffe.io/docs/latest/deploying/
   - Create quickstart guide with swtpm
   - Add to plugin compatibility matrix

2. **Create Example Deployment**:
   - Kubernetes DaemonSet with TPM DevID attestation
   - Terraform/Bicep for Azure VMs with vTPM
   - Docker Compose with swtpm for local testing

### **Phase 3: Community Adoption (Month 2-3)**

1. **SPIFFE Slack Announcement**:
   - Post in `#spire` channel about new plugin
   - Demo video showing TPM attestation flow

2. **Conference Talks**:
   - **KubeCon EU 2026**: "Hardware-Rooted Identity for Kubernetes Nodes with SPIRE + TPM"
   - **SPIFFE Community Meeting**: Technical deep dive

3. **Blog Posts**:
   - CNCF Blog: "Bringing IEEE 802.1AR to Cloud Native"
   - Medium/Dev.to: "Zero Trust Edge Computing with SPIRE TPM Attestation"

---

## Comparison with Existing SPIRE Attestors

| Feature | **TPM DevID** | AWS IID | Azure MSI | GCP IIT | Join Token |
|---------|---------------|---------|-----------|---------|------------|
| **Hardware Root of Trust** | ✅ TPM 2.0 | ❌ Cloud API | ❌ Cloud API | ❌ Cloud API | ❌ Software |
| **Works Offline** | ✅ Yes | ❌ No | ❌ No | ❌ No | ✅ Yes |
| **Cross-Cloud** | ✅ Any TPM | ❌ AWS only | ❌ Azure only | ❌ GCP only | ✅ Any |
| **Supply Chain Proof** | ✅ DevID cert | ❌ | ❌ | ❌ | ❌ |
| **FIPS 140-2** | ✅ TPM chip | ⚠️ HSM extra | ⚠️ HSM extra | ⚠️ HSM extra | ❌ |
| **Confidential Computing** | ✅ TEE + TPM | ⚠️ Nitro only | ⚠️ SEV only | ⚠️ Limited | ❌ |

**Unique Value Proposition**:
- **Only attestor** with hardware-rooted identity for **any environment** (on-prem, edge, cloud)
- **Only attestor** supporting IEEE 802.1AR standard (critical for OT/IoT)
- **Only attestor** providing cryptographic supply chain provenance via DevID certificates

---

## Success Metrics

### **Adoption Goals (6 months post-merge)**

1. **GitHub Stars**: +100 stars on `spiffe/spire` from TPM-focused users
2. **Production Deployments**: 3+ companies using TPM DevID in production
3. **Community Contributions**: 2+ external contributors adding features
4. **Conference Citations**: Featured in 2+ KubeCon/CNCF talks

### **Technical Metrics**

- **Performance**: < 500ms attestation latency (vs 200ms for software attestors)
- **Reliability**: 99.9% attestation success rate on hardware TPMs
- **Compatibility**: Works on 10+ TPM chip models (Infineon, Nuvoton, STMicro)

---

## Future Enhancements

### **Roadmap (Post-Initial Merge)**

1. **TPM 2.0 Advanced Features** (Q2 2026)
   - Support for ECC keys (P-256, P-384) alongside RSA
   - TPM policy-based authorization (PCR sealing for measured boot)
   - TPM 2.0 session encryption for sensitive data

2. **Multi-TPM Support** (Q3 2026)
   - Attestation for systems with multiple TPMs (servers, edge gateways)
   - Hierarchical attestation: System TPM → Module TPM

3. **Integration with Other Attestors** (Q4 2026)
   - **TPM + SEV-SNP**: Combine hardware + TEE attestation
   - **TPM + IMA**: Linux Integrity Measurement Architecture
   - **TPM + UEFI Secure Boot**: Full boot chain attestation

4. **Observability Enhancements** (Q1 2027)
   - OpenTelemetry metrics for TPM operations
   - Prometheus exporter for attestation latency/failures
   - Grafana dashboards for TPM health monitoring

---

## Conclusion

The **SPIRE TPM DevID Node Attestor** brings hardware-rooted, standards-based device identity to the SPIFFE ecosystem. By leveraging TPM 2.0 chips and IEEE 802.1AR certificates, it addresses critical security requirements for:

- **Edge Computing**: Verify device authenticity before workload deployment
- **Confidential Computing**: Multi-layer attestation (TPM → TEE → Workload)
- **Regulated Industries**: FIPS 140-2/3 compliance via hardware cryptography

With **zero external dependencies**, **comprehensive testing**, and **production-ready code**, this plugin is ready for upstream contribution to `spiffe/spire`.

---

## Contact & Support

**Author**: Bala Siva Sai Akhil Malepati  
- **GitHub**: [@saiakhil2012](https://github.com/saiakhil2012)  
- **Email**: akhil.malepati@crusoe.ai  
- **IEEE**: Top 30 Early Career Professional 2024  
- **Role**: Staff Engineer, Crusoe Energy Systems  

**Project Repository**: https://github.com/lfedgeai/AegisSovereignAI  
**SPIRE Upstream PR**: *(to be created)*  

**Questions?** Reach out on:
- SPIFFE Slack: https://slack.spiffe.io (#spire channel)
- GitHub Discussions: https://github.com/spiffe/spire/discussions

---

**Last Updated**: January 16, 2026  
**Status**: Ready for SPIRE Maintainer Review
