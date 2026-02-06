# TPM Hardware Testing Checklist

**MUST complete this BEFORE submitting any PRs to SPIRE upstream.**

## Prerequisites

- Linux machine: `10.1.0.10`
- TPM 2.0 chip available
- Clean checkout of `akhil/spire-overlay-clean` branch

## Phase 1: Build Verification

```bash
ssh user@10.1.0.10
cd ~/akhil/Workspace/AegisSovereignAI
git fetch akhil
git checkout akhil/spire-overlay-clean

# Verify build
./scripts/spire-build.sh

# Check binaries
ls -lh build/spire-binaries/
file build/spire-binaries/spire-server
file build/spire-binaries/spire-agent

# Expected:
# spire-server: ~114MB, ELF 64-bit executable
# spire-agent:  ~44MB, ELF 64-bit executable
```

**✅ Pass criteria:** Binaries build successfully, correct size/type

## Phase 2: TPM Detection

```bash
# Verify TPM 2.0 available
ls /dev/tpm*
# Expected: /dev/tpm0 or /dev/tpmrm0

# Check TPM resources
tpm2_getcap properties-fixed
tpm2_getcap handles-persistent

# Test TPM access
tpm2_getrandom 8 --hex
# Expected: Random hex output
```

**✅ Pass criteria:** TPM 2.0 detected and accessible

## Phase 3: SPIRE Server Startup

```bash
cd hybrid-cloud-poc

# Start server
./test_control_plane.sh

# In another terminal, verify server
ps aux | grep spire-server
netstat -tuln | grep 8081  # Server port

# Check logs
tail -f /tmp/spire-server.log
# Expected: No errors, server listening
```

**✅ Pass criteria:** Server starts without errors

## Phase 4: TPM Agent Attestation

```bash
# Start agent with TPM attestation
./test_agents.sh

# Verify agent logs
tail -f /tmp/spire-agent.log
# Expected: TPM DevID attestation successful

# Check agent registration
../build/spire-binaries/spire-server agent list
# Expected: Agent appears with TPM attestation type
```

**✅ Pass criteria:** Agent attests successfully using TPM

## Phase 5: Sovereign Attestation Flow

```bash
# Test hardware attestation
./test_integration.sh --control-plane-host 10.1.0.10

# Expected outputs:
# - TPM quote generation
# - Keylime verification
# - Sovereign attestation claims in SVID
# - Geolocation data in attestation
```

**✅ Pass criteria:** End-to-end attestation succeeds

## Phase 6: Keylime Integration

```bash
# Verify keylime communication
curl -X GET http://localhost:8080/attestation/status
# Expected: JSON with attestation status

# Check keylime verifier logs
journalctl -u keylime_verifier -f
# Expected: Successful verification entries
```

**✅ Pass criteria:** Keylime verifies TPM attestation

## Phase 7: SVID Generation with Claims

```bash
# Fetch workload SVID
../build/spire-binaries/spire-agent api fetch x509

# Expected in output:
# - X.509 SVID with sovereign attestation extension
# - Attested claims (TPM quote hash, geolocation)
# - Valid certificate chain
```

**✅ Pass criteria:** SVID contains sovereign attestation

## Phase 8: Stress Testing

```bash
# Multiple attestations
for i in {1..10}; do
    ./test_agents.sh --iteration $i
    sleep 5
done

# Check for memory leaks, crashes
ps aux | grep spire-server  # Memory should be stable
dmesg | grep -i error       # No kernel errors
```

**✅ Pass criteria:** System stable under repeated attestation

## Phase 9: Log Collection

Collect all evidence for PR documentation:

```bash
# Create evidence package
mkdir -p ~/tpm-test-evidence

# Copy logs
cp /tmp/spire-server.log ~/tpm-test-evidence/
cp /tmp/spire-agent.log ~/tpm-test-evidence/
journalctl -u keylime_verifier > ~/tpm-test-evidence/keylime.log

# TPM info
tpm2_getcap properties-fixed > ~/tpm-test-evidence/tpm-info.txt

# System info
uname -a > ~/tpm-test-evidence/system-info.txt
cat /proc/cpuinfo | grep "model name" | head -1 >> ~/tpm-test-evidence/system-info.txt

# Package versions
dpkg -l | grep tpm2 > ~/tpm-test-evidence/tpm-packages.txt

# Create tarball
cd ~
tar czf tpm-test-evidence.tar.gz tpm-test-evidence/
```

**✅ Pass criteria:** All logs collected, no errors

## Phase 10: Documentation

Create test report:

```markdown
# TPM Testing Report

**Date:** [Date]
**System:** Linux 10.1.0.10, Kernel [version]
**TPM:** TPM 2.0, [manufacturer]
**SPIRE:** v1.10.3 + Aegis overlay

## Test Results

- ✅ Build: Success
- ✅ TPM Detection: Success
- ✅ Server Startup: Success
- ✅ Agent Attestation: Success
- ✅ Sovereign Attestation: Success
- ✅ Keylime Integration: Success
- ✅ SVID Generation: Success
- ✅ Stress Test: Success (10 iterations)

## Attestation Flow Verified

1. Agent detects TPM 2.0 chip
2. Generates DevID from TPM
3. Server verifies TPM attestation
4. Keylime performs remote attestation
5. Sovereign claims added to SVID
6. Geolocation data included

## Evidence

See attached: tpm-test-evidence.tar.gz

## Issues Found

[None / List any issues]

## Conclusion

The SPIRE overlay system successfully performs hardware attestation
on real TPM 2.0 hardware. Ready for upstream submission.
```

## Final Checklist

Before submitting PRs:

- [ ] All 10 phases passed
- [ ] Evidence collected
- [ ] Test report written
- [ ] No errors in any logs
- [ ] Attestation flow works end-to-end
- [ ] Performance acceptable
- [ ] Ready to demonstrate to SPIRE maintainers

**Only proceed to PR submission after ALL boxes checked!**
