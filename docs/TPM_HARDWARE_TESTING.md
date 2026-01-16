# TPM Hardware Testing Guide

**Date**: January 16, 2026  
**Hardware**: Intel NUC / Server with TPM 2.0 chip  
**Access**: SSH to Ramki's machine

---

## Quick Start (5 Minutes)

### **1. Verify TPM Hardware**

```bash
# SSH into the machine
ssh user@<ramki-machine-ip>

# Check TPM device
ls -la /dev/tpm*
# Expected output:
# /dev/tpm0     - Character device for TPM access
# /dev/tpmrm0   - Resource manager (preferred)

# Check TPM manufacturer
sudo tpm2_getcap properties-fixed | grep -A 3 "TPM2_PT_VENDOR_STRING"
# Example: Infineon, Nuvoton, STMicroelectronics

# Check TPM firmware version
sudo tpm2_getcap properties-fixed | grep "TPM2_PT_FIRMWARE_VERSION"
```

### **2. Test TPM Operations**

```bash
# Get endorsement key certificate from TPM NV index
sudo tpm2_nvread 0x01c00002 | openssl x509 -inform DER -text -noout
# Should show manufacturer certificate (Infineon, etc.)

# Create a test key (verify TPM is functional)
tpm2_createprimary -C o -g sha256 -G rsa -c /tmp/primary.ctx
# Success = TPM working correctly

# Clean up
rm /tmp/primary.ctx
```

---

## Testing SPIRE Plugin on Real Hardware

### **Step 1: Prepare DevID Credentials**

The plugin requires IEEE 802.1AR DevID credentials. For testing, we can generate them:

```bash
# Create test DevID CA (in production, this would be manufacturer CA)
openssl req -x509 -newkey rsa:2048 -keyout devid-ca-key.pem \
  -out devid-ca-cert.pem -days 365 -nodes \
  -subj "/CN=Test DevID CA"

# Create DevID key pair
openssl genrsa -out devid-key-temp.pem 2048
openssl rsa -in devid-key-temp.pem -pubout -out devid-pub-temp.pem

# Create DevID certificate (signed by CA)
openssl req -new -key devid-key-temp.pem \
  -out devid-csr.pem \
  -subj "/CN=Test Device/serialNumber=12345678"

openssl x509 -req -in devid-csr.pem \
  -CA devid-ca-cert.pem -CAkey devid-ca-key.pem \
  -CAcreateserial -out devid-cert.pem -days 365

# Wrap DevID private key with TPM (so it can only be used on this TPM)
# This requires go-tpm tooling - for now, use unwrapped key for testing
```

### **Step 2: Import DevID to TPM**

```bash
# Create Storage Root Key (SRK) in TPM
tpm2_createprimary -C o -g sha256 -G rsa \
  -c /tmp/srk.ctx \
  -a "restricted|decrypt|fixedtpm|fixedparent|sensitivedataorigin|userwithauth"

# Import DevID private key under SRK
# Convert PEM to TPM format
openssl rsa -in devid-key-temp.pem -outform DER -out devid-key.der

# Import to TPM (creates TPM-wrapped blob)
tpm2_import -C /tmp/srk.ctx \
  -G rsa \
  -i devid-key.der \
  -u devid-pub.blob \
  -r devid-priv.blob

# Verify import worked
tpm2_load -C /tmp/srk.ctx \
  -u devid-pub.blob \
  -r devid-priv.blob \
  -c /tmp/devid.ctx

echo "DevID import successful!"
```

### **Step 3: Run SPIRE Agent with TPM Plugin**

Create `/tmp/spire-agent.conf`:
```hcl
agent {
    data_dir = "/tmp/spire-agent-data"
    log_level = "DEBUG"
    server_address = "127.0.0.1"
    server_port = "8081"
    socket_path = "/tmp/spire-agent/public/api.sock"
    trust_domain = "example.org"
}

plugins {
    NodeAttestor "tpmdevid" {
        plugin_cmd = "./bin/spire-agent"  # Built-in plugin
        plugin_data {
            devid_cert_path = "/tmp/devid-cert.pem"
            devid_priv_path = "/tmp/devid-priv.blob"
            devid_pub_path  = "/tmp/devid-pub.blob"
            # tpm_device_path will auto-detect /dev/tpm0 or /dev/tpmrm0
        }
    }
}
```

Run agent:
```bash
cd /path/to/AegisSovereignAI/hybrid-cloud-poc/spire

# Build SPIRE with TPM plugin
make build

# Run agent (requires root for TPM access)
sudo ./bin/spire-agent run -config /tmp/spire-agent.conf
```

**Expected Output** (with our new structured logging):
```
DEBUG agent.tpmdevid: TPM device auto-detected device_path=/dev/tpmrm0
DEBUG agent.tpmdevid.tpmutil: TPM session opened device_path=/dev/tpmrm0
INFO  agent.tpmdevid: Starting node attestation
```

---

## Testing Checklist for Meeting Demo

### **Pre-Meeting Setup** (30 mins)

- [ ] SSH access to Ramki's TPM machine confirmed
- [ ] `/dev/tpm0` or `/dev/tpmrm0` detected
- [ ] `tpm2-tools` installed and working
- [ ] Test DevID credentials generated
- [ ] DevID imported to TPM successfully

### **Live Demo Script** (10 mins)

1. **Show Hardware Detection**:
   ```bash
   sudo ./bin/spire-agent run -config /tmp/spire-agent.conf
   # Point out: "TPM device auto-detected device_path=/dev/tpmrm0"
   ```

2. **Show Structured Logging**:
   ```bash
   # Search logs for structured fields
   grep "device_path=" /var/log/spire-agent.log
   # Show: attempt=1 max_attempts=3 (not fmt.Sprintf!)
   ```

3. **Show Attestation Flow**:
   ```bash
   # Watch agent logs during attestation
   sudo journalctl -u spire-agent -f
   # Should see: DevID loaded → AK created → Challenge solved
   ```

### **Talking Points for Meeting**

1. **Code Quality**:
   - ✅ Already uses `hclog.Logger` (SPIRE SDK compliant)
   - ✅ Already uses `google/go-tpm` (no CLI dependencies)
   - ✅ **NEW**: Structured logging for better observability
   - ✅ **NEW**: Debug logging for TPM device path

2. **Upstream Readiness**:
   - ✅ Full SPIRE Plugin SDK compliance
   - ✅ Comprehensive test coverage
   - ✅ Production-ready error handling
   - ✅ Documentation and examples prepared

3. **Testing Strategy**:
   - ✅ Unit tests with mocked TPM
   - ✅ Integration tests (agent ↔ server)
   - ✅ **IN PROGRESS**: Real hardware testing today
   - ⏳ **NEXT**: CI/CD with swtpm for automated testing

4. **Timeline**:
   - **Week 1 (This week)**: Finalize hardware testing, address any edge cases
   - **Week 2**: Submit PR to `spiffe/spire` upstream
   - **Week 3-4**: Address maintainer feedback, iterate on code review
   - **Month 2**: Merge to SPIRE main branch → release in v1.11

---

## Troubleshooting

### **Issue: "cannot open TPM: permission denied"**

**Solution**:
```bash
# Check TPM device permissions
ls -la /dev/tpm*

# Add user to tpm group (if exists)
sudo usermod -a -G tpm $USER

# Or run as root (for testing only)
sudo ./bin/spire-agent run -config /tmp/spire-agent.conf
```

### **Issue: "TPM device not found"**

**Solution**:
```bash
# Check kernel modules
lsmod | grep tpm
# Should see: tpm_tis, tpm_crb, or tpm_vtpm_proxy

# Load TPM module if missing
sudo modprobe tpm_tis
# or
sudo modprobe tpm_crb

# For virtual TPM (QEMU/KVM)
sudo modprobe tpm_vtpm_proxy
```

### **Issue: "EK certificate not found at NV index 0x01c00002"**

**Workaround**:
```bash
# Some TPMs store EK cert at different index or don't have one
# For testing, we can skip EK cert validation by modifying server config

# Check what's in NV indexes
tpm2_nvreadpublic

# If no EK cert, generate EK and create cert manually
tpm2_createek -c /tmp/ek.ctx -G rsa -u /tmp/ek.pub
# Then create self-signed EK cert (for testing only)
```

### **Issue: "TPM busy - resource manager conflict"**

**Solution**:
```bash
# Use /dev/tpmrm0 instead of /dev/tpm0
# tpmrm0 = resource manager, handles concurrent access

# Or restart TPM resource manager
sudo systemctl restart tpm2-abrmd
```

---

## Performance Benchmarks

### **Expected Latency**

| Operation | Hardware TPM | swtpm | Notes |
|-----------|--------------|-------|-------|
| Open TPM | 50-100ms | 10-20ms | Cold start |
| Load DevID | 100-200ms | 20-50ms | Decrypt + import |
| Create AK | 200-500ms | 50-100ms | RSA keygen |
| Certify | 100-200ms | 20-50ms | Signature operation |
| **Total Attestation** | **~1 second** | **~200ms** | Full flow |

### **Optimization Opportunities**

1. **Cache AK**: Create AK once, persist handle → Save 200-500ms
2. **Parallel Operations**: Load DevID + Get EK cert concurrently
3. **Use TPM Resource Manager** (`/dev/tpmrm0`): Better performance under load

---

## Next Steps After Meeting

1. **Gather Feedback**:
   - What edge cases did Ramki encounter with real TPM hardware?
   - Any specific manufacturer quirks (Infineon vs Nuvoton)?

2. **Document Hardware Compatibility**:
   - Create matrix of tested TPM chips
   - Note any firmware-specific workarounds

3. **Prepare Upstream PR**:
   - Finalize commit messages
   - Update SPIRE documentation
   - Create PR template with testing evidence

4. **Community Engagement**:
   - Post on SPIFFE Slack about upcoming PR
   - Schedule SPIRE community meeting demo

---

**Last Updated**: January 16, 2026  
**Status**: Ready for hardware testing with Ramki's machine
