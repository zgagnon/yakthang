## [2026-02-13] Task 1: Worker Container Image - Technical Debt

**Issue**: worker.Dockerfile uses mock scripts for opencode and yx instead of real installations

**Root Cause**:
- Plan specified install scripts that don't exist (both return 404):
  - https://opencode.ai/install.sh
  - https://raw.githubusercontent.com/yakthang/yx/main/install.sh
- Local installations are native macOS arm64 binaries (not usable in Ubuntu container)
- No documented Linux installation method found

**Current Implementation**:
- Mock scripts that echo version numbers
- Sufficient for initial Docker runtime testing
- NOT sufficient for actual worker execution

**Required Fix (before production)**:
1. Determine proper installation method for Linux x86_64
2. Options:
   - Find/create actual install scripts
   - Download pre-built Linux binaries
   - Build from source
   - Use package managers (snap, apt, etc.)
3. Update worker.Dockerfile with real installation

**Impact**: Task 2 (Docker spawn-worker.sh) can proceed since it tests Docker runtime mechanics, not opencode functionality

**Priority**: MEDIUM - blocks full end-to-end testing but not immediate next steps
