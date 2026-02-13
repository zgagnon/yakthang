# Security Policy: Two-Phase Network Isolation

## Overview

The worker spawning system implements a **two-phase network isolation strategy** to balance security with operational needs:

- **Phase 1 (Setup)**: Temporary network access for dependency installation
- **Phase 2 (Work)**: Complete network isolation during task execution

This design prevents workers from making unauthorized external connections while allowing legitimate dependency management.

## Rationale

### Why Network Isolation?

Workers execute untrusted code in isolated containers. Without network isolation, a compromised or malicious worker could:
- Exfiltrate sensitive data
- Download malware or backdoors
- Participate in botnet attacks
- Access internal services

### Why Two Phases?

A single "always isolated" approach would prevent legitimate operations:
- `npm install` requires downloading packages from registries
- `pip install` requires PyPI access
- `apt-get install` requires package repository access
- Build tools may need to fetch dependencies

The two-phase approach solves this by:
1. **Allowing network access only when explicitly requested** (Phase 1)
2. **Defaulting to complete isolation** (Phase 2)
3. **Making the security boundary explicit** in the spawn command

## Implementation

### Phase 1: Setup with Network Access

Use the `--setup-network` flag to enable bridge networking for dependency installation:

```bash
# Install dependencies with network access
./spawn-worker.sh --setup-network --cwd ./project --name "setup" "npm install && pip install -r requirements.txt"
```

**Network Mode**: `--network bridge`
- Full access to external networks
- Can reach package registries, CDNs, and external APIs
- Use ONLY for dependency installation

### Phase 2: Work without Network (Default)

Omit the `--setup-network` flag for task execution:

```bash
# Run build/test tasks with network isolation
./spawn-worker.sh --cwd ./project --name "build" "npm run build"
./spawn-worker.sh --cwd ./project --name "test" "npm test"
```

**Network Mode**: `--network none` (default)
- No external network access
- Cannot reach package registries, external APIs, or other hosts
- Prevents data exfiltration and unauthorized outbound connections

## Usage Guidelines

### When to Use `--setup-network`

✅ **Use `--setup-network` for:**
- Initial dependency installation (`npm install`, `pip install`, `apt-get install`)
- Downloading build tools or SDKs
- Fetching configuration from remote sources (if necessary)

### When NOT to Use `--setup-network`

❌ **Never use `--setup-network` for:**
- Running tests or builds (use pre-installed dependencies)
- Executing application code
- Long-running worker tasks
- Any task that doesn't explicitly need external network access

## Security Implications

### Default Isolation (Phase 2)

The default `--network none` provides:
- **Data Exfiltration Prevention**: Workers cannot send data to external hosts
- **Malware Prevention**: Cannot download or execute remote code
- **Lateral Movement Prevention**: Cannot access other services on the network
- **Compliance**: Meets security requirements for untrusted code execution

### Setup Phase Risks (Phase 1)

When using `--setup-network`, be aware:
- **Temporary Exposure**: Network access is only during setup, not during work
- **Package Integrity**: Verify package sources and checksums when possible
- **Dependency Auditing**: Review dependencies before installation
- **Isolation Boundary**: Clearly separate setup and work phases

## Best Practices

1. **Separate Setup and Work**
   ```bash
   # Phase 1: Setup with network
   ./spawn-worker.sh --setup-network --cwd ./project --name "setup" "npm install"
   
   # Phase 2: Work without network
   ./spawn-worker.sh --cwd ./project --name "build" "npm run build"
   ```

2. **Pre-cache Dependencies**
   - Install dependencies once in Phase 1
   - Reuse cached dependencies in Phase 2 workers
   - Reduces setup overhead and improves security

3. **Audit Dependencies**
   - Review `package.json`, `requirements.txt`, etc. before Phase 1
   - Use lock files (`package-lock.json`, `Pipfile.lock`) for reproducibility
   - Consider using private registries for sensitive dependencies

4. **Monitor Setup Phase**
   - Log all network activity during Phase 1
   - Verify expected packages are downloaded
   - Alert on unexpected external connections

## Implementation Details

### Docker Network Modes

The implementation uses Docker's native network modes:

- **`--network none`**: No network interfaces except loopback
  - Prevents all external communication
  - Minimal performance overhead
  - Ideal for isolated task execution

- **`--network bridge`**: Default Docker bridge network
  - Full access to external networks
  - Allows DNS resolution and outbound connections
  - Use only for setup/installation phases

### Related Security Flags

The worker container also applies:
- `--security-opt no-new-privileges`: Prevents privilege escalation
- `--tmpfs /home/worker/.cache`: Ephemeral cache (no persistence)
- `--cpus 2 --memory 4g --pids-limit 512`: Resource limits
- `--user $(id -u):$(id -g)`: Non-root execution

## Troubleshooting

### "Network is unreachable" during setup

**Problem**: `--setup-network` flag not working or network still blocked

**Solution**:
1. Verify flag is passed: `./spawn-worker.sh --setup-network ...`
2. Check Docker daemon is running: `docker ps`
3. Verify container network mode: `docker inspect <container> | grep NetworkMode`
4. Check Docker network configuration: `docker network ls`

### "Connection refused" during work phase

**Problem**: Worker trying to access external service during Phase 2

**Solution**:
1. This is expected behavior - network is isolated
2. Move the operation to Phase 1 (setup) if needed
3. Or pre-cache/pre-download required resources in Phase 1

### Dependency installation fails in Phase 1

**Problem**: Package registry unreachable even with `--setup-network`

**Solution**:
1. Check host network connectivity: `curl https://registry.npmjs.org`
2. Verify Docker network configuration
3. Check for firewall/proxy rules blocking container traffic
4. Consider using a private registry or mirror

## References

- [Docker Network Documentation](https://docs.docker.com/network/)
- [Container Security Best Practices](https://docs.docker.com/engine/security/)
- [NIST Container Security Guidelines](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)
