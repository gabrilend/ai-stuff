# Unified Task List and Critical Path

This document provides a centralized, organized view of all issues with triage, dependencies, and critical path planning for efficient resolution.

## 📊 **Task Overview Dashboard**

**Last Updated**: 2025-09-23  
**Total Active Tasks**: 15  
**Critical Path Dependencies**: 5 chains identified  
**Estimated Total Effort**: 4-5 weeks with proper sequencing  
**Next Milestone**: Architecture Documentation Compliance

## 🎯 **Critical Path Analysis**

### **Path 1: Architecture Documentation Foundation** (CRITICAL - Blocks development)
**Estimated Time**: 3-5 days | **Dependencies**: None | **Blocks**: Integration work

1. **#015** → [Networking Architecture Documentation Compliance](015-networking-architecture-compliance-violations.md)
2. **#017** → [MMO Engine Networking Architecture Violations](017-mmo-networking-architecture-violations.md) 
3. **#018** → [Code Comments and Strings Networking Violations](018-code-comments-networking-violations.md)

**Critical Impact**: These documentation issues contradict core security architecture and must be resolved before integration work can proceed safely.

### **Path 2: Bytecode System Integration** (HIGH - Implements architecture)
**Estimated Time**: 3-4 days | **Dependencies**: Path 1 completion | **Blocks**: Feature development

1. **#007** → [External API Violations in AI Services](007-external-api-violations-ai-services.md) ⚠️ *Architecture Designed*
2. **#008** → [External LLM API Violations](008-external-llm-api-violations.md) ⚠️ *Architecture Designed*
3. **#013** → [P2P-Only Compliance Violations](013-p2p-only-compliance-violations.md) ⚠️ *Architecture Designed*
4. **#016** → [Daemon TCP Server Architecture Mismatch](016-daemon-tcp-server-architecture-mismatch.md) ⚠️ *Architecture Designed*

**Critical Impact**: These issues have architecture designed but require implementation work to integrate with the existing bytecode system.

### **Path 3: Feature Implementation** (MEDIUM - Parallel development possible)
**Estimated Time**: 1-2 weeks | **Dependencies**: None | **Blocks**: Production readiness

1. **#014** → [Radial Keyboard Implementation Incomplete](014-radial-keyboard-implementation-incomplete.md)
2. **#004** → [AzerothCore Setup Guide Inconsistencies](004-azerothcore-setup-inconsistencies.md)
3. **#025** → [Documentation Structure Reorganization](025-documentation-structure-reorganization.md)

### **Path 4: Project Reorganization** (MEDIUM - Can be done in parallel)
**Estimated Time**: 1-2 weeks | **Dependencies**: None | **Blocks**: Maintainability

1. **#025-game** → [Game Files Reorganization](025-game-files-reorganization.md)
2. **#026** → [Cargo.toml Game Paths Update](026-cargo-toml-game-paths-update.md) 
3. **#027** → [Documentation Game Path Updates](027-documentation-game-path-updates.md)
4. **#028** → [Utilities Directory Reorganization](028-utilities-directory-reorganization.md)
5. **#029** → [Networking Files Reorganization](029-networking-files-reorganization.md)
6. **#030** → [Cargo.toml Comprehensive Reorganization](030-cargo-toml-comprehensive-reorganization.md)
7. **#031** → [Offsite Compute Directory Organization](031-offsite-compute-directory-organization.md)

**Impact**: Core features that can be developed in parallel with architecture work.

### **Path 5: Documentation Mismatch Resolution** (LOW - Nice to have)
**Estimated Time**: 1-2 days | **Dependencies**: Reorganization completion | **Blocks**: Code documentation accuracy

1. **#011** → [Documentation Code Mismatch - MediaPlayer](011-documentation-code-mismatch-mediaplayer.md)
2. **#012** → [Documentation Code Mismatch - Enhanced Input](012-documentation-code-mismatch-enhanced-input.md)

### **Path 6: Compilation Tracking** (ONGOING - Continuous)
**Estimated Time**: Ongoing | **Dependencies**: All paths | **Blocks**: Production deployment

1. **#024** → [Compilation Errors Master Tracking Issue](024-compilation-errors-master-tracking.md)

## 📋 **Organized Task Categories**

### 🚨 **CRITICAL (Architecture Foundation) - Week 1 Priority**

#### **#015: Networking Architecture Documentation Compliance** 
- **File**: [015-networking-architecture-compliance-violations.md](015-networking-architecture-compliance-violations.md)
- **Scope**: Major documentation rewrite for air-gapped P2P compliance
- **Effort**: 1-2 days
- **Dependencies**: None
- **Blocks**: Integration work (#007, #008, #013, #016)
- **Status**: Ready to start

#### **#017: MMO Engine Networking Architecture Violations**
- **File**: [017-mmo-networking-architecture-violations.md](017-mmo-networking-architecture-violations.md)  
- **Scope**: Update MMO documentation for P2P-only compliance
- **Effort**: 1 day
- **Dependencies**: #015 completion (consistent approach)
- **Blocks**: MMO feature development
- **Status**: Waiting for #015

#### **#018: Code Comments and Strings Networking Violations**
- **File**: [018-code-comments-networking-violations.md](018-code-comments-networking-violations.md)
- **Scope**: Update user-facing strings and code comments
- **Effort**: 1-2 days  
- **Dependencies**: #015, #017 completion (consistent terminology)
- **Blocks**: User confusion prevention
- **Status**: Waiting for #015, #017

### ⚠️ **HIGH PRIORITY (System Integration) - Week 2 Priority**

#### **#007: External API Violations in AI Services** ⚠️ *Architecture Designed*
- **File**: [007-external-api-violations-ai-services.md](007-external-api-violations-ai-services.md)
- **Scope**: Replace direct HTTP calls in ai_image_service.rs with bytecode interface
- **Effort**: 6-8 hours (implementation work)
- **Dependencies**: #015 completion (architecture clarity)
- **Blocks**: AI image generation features
- **Status**: Bytecode interface exists, HTTP calls at line 283 need replacement

#### **#008: External LLM API Violations** ⚠️ *Architecture Designed*
- **File**: [008-external-llm-api-violations.md](008-external-llm-api-violations.md)
- **Scope**: Replace direct HTTP calls in desktop_llm.rs with laptop daemon proxy
- **Effort**: 6-8 hours (implementation work)
- **Dependencies**: #015 completion (architecture clarity)  
- **Blocks**: LLM functionality
- **Status**: Proxy architecture exists, HTTP calls at lines 146, 176 need replacement

#### **#013: P2P-Only Compliance Violations** ⚠️ *Architecture Designed*
- **File**: [013-p2p-only-compliance-violations.md](013-p2p-only-compliance-violations.md)
- **Scope**: Remove all external HTTP calls from Anbernic-side code
- **Effort**: 8-10 hours (survey and replace all violations)
- **Dependencies**: #007, #008 completion
- **Blocks**: Security compliance
- **Status**: Architecture designed, implementation work required

#### **#016: Daemon TCP Server Architecture Mismatch** ⚠️ *Architecture Designed*
- **File**: [016-daemon-tcp-server-architecture-mismatch.md](016-daemon-tcp-server-architecture-mismatch.md)
- **Scope**: Configure TCP binding for P2P-only operation
- **Effort**: 4-6 hours (configuration and testing)
- **Dependencies**: #007, #008, #013 completion
- **Blocks**: Network security
- **Status**: Architecture designed, configuration work required

### 📋 **MEDIUM PRIORITY (Feature Development) - Week 2-3 Priority**

#### **#014: Radial Keyboard Implementation Incomplete**
- **File**: [014-radial-keyboard-implementation-incomplete.md](014-radial-keyboard-implementation-incomplete.md)
- **Scope**: Complete radial keyboard positioning, rendering, layout
- **Effort**: 1-2 weeks
- **Dependencies**: None (can work in parallel)
- **Blocks**: Core input functionality
- **Status**: Can start immediately

#### **#004: AzerothCore Setup Guide Inconsistencies**
- **File**: [004-azerothcore-setup-inconsistencies.md](004-azerothcore-setup-inconsistencies.md)
- **Scope**: Major documentation overhaul to match P2P architecture
- **Effort**: 2-3 days
- **Dependencies**: #015, #017 completion (consistent architecture)
- **Blocks**: User onboarding
- **Status**: Waiting for architecture docs

#### **#025: Documentation Structure Reorganization**
- **File**: [025-documentation-structure-reorganization.md](025-documentation-structure-reorganization.md)
- **Scope**: Move docs from /src/ to centralized /docs/ and /notes/ with module organization
- **Effort**: 2-3 hours
- **Dependencies**: None (can start immediately)
- **Blocks**: Documentation maintainability
- **Status**: Ready to start

### 🔧 **PROJECT REORGANIZATION (Parallel Development)**

#### **#025-game: Game Files Reorganization**
- **File**: [025-game-files-reorganization.md](025-game-files-reorganization.md)
- **Scope**: Move game files to src/games/ directory structure
- **Effort**: 2-3 hours
- **Dependencies**: None (can start immediately)
- **Blocks**: #026, #027
- **Status**: Ready to start

#### **#026: Cargo.toml Game Paths Update**
- **File**: [026-cargo-toml-game-paths-update.md](026-cargo-toml-game-paths-update.md)
- **Scope**: Update binary paths after game file reorganization
- **Effort**: 1-2 hours
- **Dependencies**: #025-game completion
- **Blocks**: Build system
- **Status**: Waiting for #025-game

#### **#027: Documentation Game Path Updates**
- **File**: [027-documentation-game-path-updates.md](027-documentation-game-path-updates.md)
- **Scope**: Update documentation references to new game file paths
- **Effort**: 2-3 hours
- **Dependencies**: #025-game, #026 completion
- **Blocks**: Documentation accuracy
- **Status**: Waiting for #025-game, #026

#### **#028: Utilities Directory Reorganization**
- **File**: [028-utilities-directory-reorganization.md](028-utilities-directory-reorganization.md)
- **Scope**: Move utility files to src/utilities/ directory
- **Effort**: 2-3 hours
- **Dependencies**: None (can work in parallel with games)
- **Blocks**: #030
- **Status**: Ready to start

#### **#029: Networking Files Reorganization**
- **File**: [029-networking-files-reorganization.md](029-networking-files-reorganization.md)
- **Scope**: Move networking files to src/networking/ directory
- **Effort**: 3-4 hours
- **Dependencies**: None (can work in parallel)
- **Blocks**: #030
- **Status**: Ready to start

#### **#030: Cargo.toml Comprehensive Reorganization**
- **File**: [030-cargo-toml-comprehensive-reorganization.md](030-cargo-toml-comprehensive-reorganization.md)
- **Scope**: Update all binary paths after directory reorganization
- **Effort**: 2-3 hours
- **Dependencies**: #026, #028, #029 completion
- **Blocks**: Build system consistency
- **Status**: Waiting for reorganization completion

#### **#031: Offsite Compute Directory Organization**
- **File**: [031-offsite-compute-directory-organization.md](031-offsite-compute-directory-organization.md)
- **Scope**: Organize desktop/laptop daemon files
- **Effort**: 2-3 hours
- **Dependencies**: None (can work in parallel)
- **Blocks**: Server organization
- **Status**: Ready to start

### 📄 **DOCUMENTATION MISMATCHES (Low Priority)**

#### **#011: Documentation Code Mismatch - MediaPlayer**
- **File**: [011-documentation-code-mismatch-mediaplayer.md](011-documentation-code-mismatch-mediaplayer.md)
- **Scope**: Fix documentation inconsistencies with MediaPlayer implementation
- **Effort**: 1-2 hours
- **Dependencies**: Project reorganization completion
- **Blocks**: Documentation accuracy
- **Status**: Low priority cleanup

#### **#012: Documentation Code Mismatch - Enhanced Input**
- **File**: [012-documentation-code-mismatch-enhanced-input.md](012-documentation-code-mismatch-enhanced-input.md)
- **Scope**: Fix documentation inconsistencies with Enhanced Input implementation
- **Effort**: 1-2 hours
- **Dependencies**: Project reorganization completion
- **Blocks**: Documentation accuracy
- **Status**: Low priority cleanup

### 🔄 **ONGOING (Continuous Integration)**

#### **#024: Compilation Errors Master Tracking Issue**
- **File**: [024-compilation-errors-master-tracking.md](024-compilation-errors-master-tracking.md)
- **Scope**: Monitor and resolve remaining compilation warnings
- **Effort**: Ongoing cleanup
- **Dependencies**: None (warnings don't block compilation)
- **Blocks**: Production polish
- **Status**: All errors resolved, warnings remain for cleanup

## 🎯 **Recommended Execution Order**

### **Phase 1: Foundation (Days 1-5)**
```
Day 1-2: #015 (Networking Architecture Documentation)
Day 3:   #017 (MMO Documentation) 
Day 4-5: #018 (Code Comments and Strings)
```

### **Phase 2: Integration (Days 6-11)**  
```
Day 6-7: #007 (AI Services Implementation)
Day 8-9: #008 (LLM Implementation)
Day 10:  #013 (P2P Compliance Implementation)
Day 11:  #016 (Daemon Configuration)
```

### **Phase 3: Features (Days 12-25)**
```
Day 12-15: #004 (AzerothCore Documentation) - can start after Day 5
Day 12-25: #014 (Radial Keyboard) - can start immediately, parallel work
```

### **Phase 4: Project Reorganization (Days 12-20, Parallel)**
```
Day 12-13: #025-game, #028, #029, #031 (File moves, parallel)
Day 14-15: #026, #030 (Cargo.toml updates after moves)
Day 16-17: #027 (Documentation updates)
Day 18-20: #011, #012 (Documentation cleanup)
```

### **Continuous: Code Quality**
```
Ongoing: #024 (Clean up warnings for production polish)
```

## 📊 **Dependency Matrix**

| Issue | Depends On | Blocks | Can Start | Estimated Effort |
|-------|------------|--------|-----------|------------------|
| #015  | None       | #007, #008, #017, #018, #004 | ✅ Now | 1-2 days |
| #017  | #015       | #004   | After #015 | 1 day |
| #018  | #015, #017 | User confusion | After #017 | 1-2 days |
| #007  | #015       | #013   | After #015 | 6-8 hours |
| #008  | #015       | #013   | After #015 | 6-8 hours |
| #013  | #007, #008 | #016   | After #007, #008 | 8-10 hours |
| #016  | #013       | Network security | After #013 | 4-6 hours |
| #014  | None       | Core input | ✅ Now | 1-2 weeks |
| #004  | #015, #017 | User onboarding | After #017 | 2-3 days |
| #025  | None       | Documentation maintainability | ✅ Now | 2-3 hours |
| #025-game | None  | #026, #027 | ✅ Now | 2-3 hours |
| #026  | #025-game  | Build system | After #025-game | 1-2 hours |
| #027  | #025-game, #026 | Documentation accuracy | After #026 | 2-3 hours |
| #028  | None       | #030   | ✅ Now | 2-3 hours |
| #029  | None       | #030   | ✅ Now | 3-4 hours |
| #030  | #026, #028, #029 | Build consistency | After reorganization | 2-3 hours |
| #031  | None       | Server organization | ✅ Now | 2-3 hours |
| #011  | Reorganization | Documentation accuracy | After reorganization | 1-2 hours |
| #012  | Reorganization | Documentation accuracy | After reorganization | 1-2 hours |
| #024  | None | Production polish | ✅ Ongoing | Cleanup only |

## 🚀 **Quick Win Opportunities**

### **Immediate Starters (No Dependencies)**
1. **#015**: Start immediately - unblocks 6 other issues
2. **#014**: Can work in parallel - core feature implementation
3. **#025**: Quick documentation reorganization - improves maintainability
4. **#025-game**: Game files reorganization - can work in parallel
5. **#028**: Utilities reorganization - can work in parallel
6. **#029**: Networking files reorganization - can work in parallel
7. **#031**: Offsite compute organization - can work in parallel

### **High Impact, Low Effort**  
1. **#025**: Only 2-3 hours, improves project organization immediately
2. **#025-game**: Only 2-3 hours, enables build system updates
3. **#028**: Only 2-3 hours, organizes utility files
4. **#031**: Only 2-3 hours, organizes server files
5. **#017**: Only 1 day effort, unblocks #004
6. **#016**: Only 4-6 hours, completes integration chain

### **Completion Accelerators**
1. **Focus on #015 first**: Unblocks the most other work
2. **Parallel #014 development**: Can happen alongside documentation work
3. **Batch integration work**: #007, #008, #013, #016 can be done consecutively

## 🎖️ **Milestone Definitions**

### **Milestone 1: Architecture Foundation Complete**
- ✅ Issues #015, #017, #018 resolved
- ✅ All documentation consistent with air-gapped P2P architecture
- ✅ Development team has clear, unified architecture guidance

### **Milestone 2: System Integration Complete**  
- ✅ Issues #007, #008, #013, #016 resolved
- ✅ Bytecode interface fully integrated with existing services
- ✅ No external HTTP calls from Anbernic devices
- ✅ Complete air-gapped P2P system operational

### **Milestone 3: Feature Implementation Complete**
- ✅ Issues #004, #014 resolved  
- ✅ Radial keyboard fully functional
- ✅ User documentation accurate and complete
- ✅ Core features ready for production use

### **Milestone 4: Production Ready**
- ✅ Issue #024 resolved
- ✅ Clean compilation across all targets
- ✅ Comprehensive testing passed
- ✅ Performance targets met

## 📈 **Progress Tracking**

### **Completion Metrics**
- **Foundation Progress**: 0/3 issues complete (0%)
- **Integration Progress**: 0/4 issues complete (0%) 
- **Feature Progress**: 0/3 issues complete (0%)
- **Reorganization Progress**: 0/7 issues complete (0%)
- **Documentation Cleanup Progress**: 0/2 issues complete (0%)
- **Overall Progress**: 0/19 issues complete (0%)

### **Velocity Tracking**
*Update after each issue resolution to track actual vs. estimated effort*

| Week | Planned Issues | Completed Issues | Effort Variance | Notes |
|------|----------------|------------------|-----------------|-------|
| Week 1 | #015, #017, #018 | - | - | Foundation phase |
| Week 2 | #007, #008, #013, #016 | - | - | Integration phase |
| Week 3 | #004, #014 | - | - | Feature phase |

## 🔄 **Maintenance Notes**

### **When to Update This File**
- ✅ After completing any issue (update progress, dependencies)
- ✅ When discovering new dependencies or blockers
- ✅ When effort estimates prove significantly wrong
- ✅ When priorities change due to external factors

### **File Relationships**
- **README.md**: High-level status, links to this file for detailed planning
- **COMPLETED.md**: Archive resolved issues, update from this file
- **CLAUDE.md**: Workflow process includes maintaining this file
- **Individual issue files**: Source of truth for detailed requirements

This unified task list provides the strategic overview needed for efficient issue resolution while maintaining the detailed information in individual issue files.