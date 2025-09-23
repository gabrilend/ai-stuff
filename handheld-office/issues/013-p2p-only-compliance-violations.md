# Issue #013: P2P-Only Compliance Violations - External Network Dependencies

## Priority: CRITICAL 🚨

## Description
Multiple applications in the codebase violate the P2P-only requirement by connecting to external HTTP services, localhost servers, and non-P2P network endpoints. This directly violates the architecture specified in `/notes/cryptographic-communication-vision`.

## Architecture Requirement (from claude-next-4)
> "The device should be unable to connect to wifi routers, bluetooth, or other remote devices. Except for other anbernics running our software suite, and laptops who are running a server program. [...] all communications are done in a peer-to-peer fashion with other anbernics on OfficeOS."

## Critical Violations Found

### 🚨 **VIOLATION 1: AI Image Service External HTTP**
**File**: `src/ai_image_service.rs:295`
```rust
.post("http://127.0.0.1:7860/sdapi/v1/txt2img")
```
**Issue**: Connects to external Stable Diffusion WebUI service
**Impact**: Breaks P2P-only architecture, requires external server

### 🚨 **VIOLATION 2: Desktop LLM External HTTP Dependencies**
**File**: `src/desktop_llm.rs:145,172`
```rust
// Line 145
.post("http://localhost:8000/v1/completions")

// Line 172  
.post("http://localhost:5001/api/v1/generate")
```
**Issue**: Connects to llama-cpp-python and KoboldCPP servers
**Impact**: Requires external LLM server infrastructure

### 🚨 **VIOLATION 3: Desktop LLM Daemon Connection**
**File**: `src/desktop_llm.rs:226`
```rust
llm_service.connect_to_daemon("127.0.0.1:8080").await
```
**Issue**: Hardcoded localhost connection
**Impact**: May be acceptable if this is the "laptop server program" mentioned in requirements

### ⚠️ **POTENTIAL VIOLATION 4: MMO Demo Bootstrap Peers**
**File**: `src/mmo_demo.rs:64`
```rust
let bootstrap_peers = vec!["127.0.0.1:8086".parse()?, "127.0.0.1:8087".parse()?];
```
**Issue**: Hardcoded localhost peer discovery
**Impact**: May violate P2P discovery requirements, depends on context

### ⚠️ **POTENTIAL VIOLATION 5: P2P Mesh Placeholder IP**
**File**: `src/p2p_mesh.rs:559`
```rust
Ok("192.168.1.100".parse()?) // Placeholder
```
**Issue**: Placeholder suggests router-based networking
**Impact**: Code comment indicates this is temporary

## Compliance Analysis

### ✅ **ALLOWED (Laptop Server Communication)**
The architecture allows communication with "laptops who are running a server program." 
- `desktop_llm.rs:226` daemon connection may be compliant if it's the approved laptop server

### ❌ **PROHIBITED (External HTTP Services)**
- AI image generation to external WebUI (line ai_image_service.rs:295)
- LLM services to external servers (desktop_llm.rs:145,172)
- Any router-dependent networking

### 🔍 **NEEDS CLARIFICATION**
- MMO bootstrap peers: Are these other Anbernic devices or external services?
- P2P mesh placeholder IP: What's the intended implementation?

## Required Fixes

### **Immediate Actions (CRITICAL)**

#### 1. **Remove AI Image Service External Dependencies**
```rust
// In src/ai_image_service.rs - REMOVE lines 290-300
// Replace with:
// - Local image generation
// - P2P requests to other Anbernic devices with AI capabilities
// - Requests to approved laptop daemon only
```

#### 2. **Remove Desktop LLM External Dependencies** 
```rust
// In src/desktop_llm.rs - REMOVE lines 140-180
// Replace with:
// - Local LLM inference only
// - P2P delegation to other Anbernic devices
// - Proper laptop daemon bytecode interface
```

### **Medium Priority Actions**

#### 3. **Clarify MMO Networking Architecture**
- Determine if bootstrap peers are compliant P2P discovery
- Update to use WiFi Direct discovery if needed

#### 4. **Fix P2P Mesh Placeholder**
- Replace placeholder IP with actual P2P discovery
- Ensure no router dependencies

## Architecture Compliance Strategy

### **Approved Network Communication:**
1. **Anbernic ↔ Anbernic**: Direct P2P over WiFi Direct
2. **Anbernic ↔ Laptop Server**: Encrypted bytecode instructions only
3. **No external HTTP/HTTPS**: Remove all external service dependencies

### **Implementation Path:**
1. **AI Generation**: Move to laptop daemon with bytecode interface
2. **LLM Processing**: Use laptop daemon proxy or local inference
3. **Discovery**: WiFi Direct only, no router-based discovery
4. **All Traffic**: Flow through crypto layer per `/src/crypto/`

## Cross-References
- **Related Issues**: #007, #008 (already identified some violations)
- **Architecture**: `/notes/cryptographic-communication-vision`
- **Crypto Integration**: `/src/crypto/` modules provide compliant networking
- **Request Source**: `/todo/claude-next/claude-next-4`

## Security Impact
- **Data Leakage**: External HTTP calls bypass encryption
- **Attack Surface**: External dependencies increase vulnerability
- **Architecture Violation**: Undermines zero-trust P2P design

## Recommendation
**IMMEDIATE REMOVAL** of all external HTTP dependencies. The existing crypto/P2P infrastructure can handle all networking requirements through compliant channels.

**Filed by**: P2P compliance audit (claude-next-4)  
**Date**: 2025-01-27  
**Severity**: CRITICAL - Architecture violation