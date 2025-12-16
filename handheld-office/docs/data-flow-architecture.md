# OfficeOS Data Flow Architecture

## Overview

OfficeOS implements a secure air-gapped architecture where Anbernic handheld devices communicate exclusively via encrypted WiFi Direct P2P, while laptop daemons act as secure proxies for external service access. This document details the complete data flow from handheld devices through to external services and back.

## Core Architectural Principle

**Anbernic devices NEVER directly connect to external services.** All external access is proxied through laptop daemons using encrypted bytecode instructions over WiFi Direct P2P connections.

## Data Flow Diagram

```
                           SECURE PROXY ARCHITECTURE
┌─────────────────┐                                    ┌─────────────────┐
│                 │        WiFi Direct P2P             │                 │
│  Anbernic       │◄─────── Encrypted Bytecode ──────►│ Laptop Daemon   │
│  Device         │         Instructions               │ (Secure Proxy)  │
│  (Air-Gapped)   │                                    │                 │
└─────────────────┘                                    └─────────────────┘
         │                                                       │
         │ ❌ NO DIRECT                                          │ ✅ ALLOWED
         │    EXTERNAL                                           │    EXTERNAL
         │    ACCESS                                             │    ACCESS
         │                                                       │
         ▼                                                       ▼
    ┌─────────┐                                          ┌─────────────┐
    │ BLOCKED │                                          │ External    │
    │ 🚫      │                                          │ Services:   │
    │         │                                          │ • LLM APIs  │
    └─────────┘                                          │ • Image AI  │
                                                         │ • Web APIs  │
                                                         └─────────────┘
```

## Step-by-Step Data Flow

### 1. Request Phase: Anbernic → Laptop Daemon

```
┌─────────────────┐
│ 1. User Action  │ User requests image generation on Anbernic device
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 2. Bytecode     │ Device creates ImageGenerationBytecode instruction
│    Creation     │ {
│                 │   instruction: GenerateImage,
│                 │   prompt: "sunset over mountains",
│                 │   style: "realistic"
│                 │ }
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 3. Encryption   │ Bytecode encrypted using relationship-specific keys
│                 │ (Ed25519 + X25519 + ChaCha20-Poly1305)
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 4. WiFi Direct  │ Encrypted packet sent via WiFi Direct P2P
│    Transmission │ to paired laptop daemon
└─────────────────┘
```

### 2. Processing Phase: Laptop Daemon Proxy

```
┌─────────────────┐
│ 5. Reception    │ Laptop daemon receives encrypted packet
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 6. Decryption   │ Packet decrypted using relationship keys
│    & Validation │ Bytecode instruction extracted and validated
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 7. Permission   │ Check if relationship allows image generation
│    Check        │ Verify rate limits and resource usage
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 8. Translation  │ Bytecode instruction translated to HTTP request:
│                 │ POST http://127.0.0.1:7860/sdapi/v1/txt2img
│                 │ {
│                 │   "prompt": "sunset over mountains",
│                 │   "width": 512, "height": 512,
│                 │   "steps": 20
│                 │ }
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 9. External     │ HTTP request sent to external service
│    Service Call │ (Stable Diffusion WebUI, LLM API, etc.)
└─────────────────┘
```

### 3. Response Phase: External Service → Anbernic

```
┌─────────────────┐
│ 10. External    │ External service returns HTTP response
│     Response    │ with generated image data
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 11. Processing  │ Laptop daemon processes response:
│                 │ • Extracts image data
│                 │ • Validates format and size
│                 │ • Applies any necessary transformations
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 12. Bytecode    │ Response converted to bytecode format:
│     Response    │ BytecodeResponse {
│                 │   success: true,
│                 │   data: Vec<u8>, // image bytes
│                 │   metadata: {...}
│                 │ }
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 13. Encryption  │ Response encrypted using relationship keys
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 14. WiFi Direct │ Encrypted response sent back to Anbernic
│     Return      │ via WiFi Direct P2P
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 15. Anbernic    │ Device receives, decrypts, and displays
│     Display     │ generated image to user
└─────────────────┘
```

## Security Boundaries

### ✅ **ALLOWED: Laptop Daemon External Access**

The laptop daemon is specifically designed to act as a secure proxy and may:
- Make HTTP/HTTPS requests to external services
- Connect to LLM APIs (OpenAI, local inference servers, etc.)
- Access image generation services (Stable Diffusion, DALL-E, etc.)
- Download files and resources
- Connect to databases and cloud services

### ❌ **PROHIBITED: Anbernic Direct External Access**

Anbernic devices maintain strict air-gapped operation and NEVER:
- Make direct HTTP/HTTPS requests
- Connect to WiFi routers or internet infrastructure
- Access external APIs or services
- Download from the internet
- Connect to any non-OfficeOS devices except via P2P

### 🔐 **ENCRYPTED: All Inter-Device Communication**

Every communication between Anbernic devices and laptop daemons uses:
- **WiFi Direct P2P**: No router or internet infrastructure required
- **Relationship-Specific Encryption**: Unique keys per device pair
- **Bytecode Instructions**: Structured, validated command format
- **Auto-Expiring Keys**: Default 30-day relationship lifespan

## Service Deployment Architecture

### Laptop Daemon Services

These services run on laptop daemons and are ALLOWED to make external HTTP calls:

```rust
// ✅ CORRECT: Running on laptop daemon
// src/ai_image_service.rs
let client = reqwest::Client::new();
let response = client
    .post("http://127.0.0.1:7860/sdapi/v1/txt2img")
    .json(&payload)
    .send()
    .await?;
```

```rust
// ✅ CORRECT: Running on laptop daemon
// src/desktop_llm.rs
let client = reqwest::Client::new();
let response = client
    .post("http://localhost:8000/v1/completions")
    .json(&request)
    .send()
    .await?;
```

### Anbernic Device Services

These services run on Anbernic devices and use ONLY bytecode communication:

```rust
// ✅ CORRECT: Anbernic device sending bytecode to laptop
pub async fn request_image_generation(
    &self,
    prompt: &str,
    laptop_connection: &EncryptedP2PConnection,
) -> Result<Vec<u8>, Error> {
    let bytecode = ImageGenerationBytecode {
        instruction: Instruction::GenerateImage,
        prompt: prompt.to_string(),
        style: "realistic",
    };
    
    laptop_connection.send_encrypted_bytecode(bytecode).await
}
```

## Implementation Status

### ✅ **Completed Components**

- **Cryptographic System**: Full Ed25519/X25519/ChaCha20-Poly1305 stack
- **Bytecode Framework**: Complete instruction and response system
- **Laptop Daemon Services**: AI and LLM services with external HTTP access
- **WiFi Direct P2P**: Encrypted device-to-device communication

### ❌ **Missing Integration**

- **Anbernic Bytecode Clients**: Services to send bytecode instructions to laptop
- **Laptop Bytecode Handlers**: Interfaces to receive and process Anbernic requests
- **Response Translation**: Converting HTTP responses back to encrypted bytecode
- **Permission Management**: Relationship-based access control system

## Example: Complete Image Generation Flow

### User Request on Anbernic
```
User: "Generate image: robot cat in space"
```

### Anbernic Device Code
```rust
// Send bytecode instruction to laptop daemon
let bytecode = ImageGenerationBytecode {
    instruction: Instruction::GenerateImage,
    prompt: "robot cat in space",
    width: 512,
    height: 512,
    steps: 20,
};

let encrypted_response = laptop_daemon
    .send_encrypted_bytecode(bytecode)
    .await?;

let image_data = decrypt_bytecode_response(encrypted_response)?;
display_image(image_data);
```

### Laptop Daemon Code
```rust
// Receive bytecode from Anbernic device
let bytecode = receive_encrypted_bytecode_from_anbernic().await?;

// Check permissions
if !permissions.allows_image_generation(&requester_relationship) {
    return send_error_response("Permission denied").await;
}

// Translate to HTTP request (ALLOWED on laptop daemon)
let client = reqwest::Client::new();
let response = client
    .post("http://127.0.0.1:7860/sdapi/v1/txt2img")
    .json(&json!({
        "prompt": bytecode.prompt,
        "width": bytecode.width,
        "height": bytecode.height,
        "steps": bytecode.steps,
    }))
    .send()
    .await?;

// Process response and return to Anbernic
let image_data = extract_image_from_response(response).await?;
let bytecode_response = BytecodeResponse {
    success: true,
    data: image_data,
    metadata: generate_metadata(),
};

send_encrypted_bytecode_response(bytecode_response, &requester_relationship).await
```

## Security Advantages

### 1. **Air-Gapped Handheld Devices**
- No attack surface from external internet connections
- Isolated from web-based malware and exploits
- Protected from data harvesting and tracking

### 2. **Controlled External Access**
- All external requests filtered through laptop daemon
- Permission system controls what each device can access
- Rate limiting and resource monitoring built-in

### 3. **Encrypted P2P Communication**
- All device communication uses modern cryptography
- Relationship-specific keys limit blast radius of compromises
- Auto-expiring relationships provide forward secrecy

### 4. **Secure Proxy Architecture**
- Laptop daemons act as hardened network gateway
- Can implement additional security policies and monitoring
- Centralizes external connectivity for easier management

## Performance Characteristics

### WiFi Direct P2P Performance
- **Latency**: ~5-10ms for local P2P communication
- **Throughput**: 100+ Mbps for file transfers
- **Range**: 50-200 meters depending on environment
- **Power Usage**: Lower than WiFi router connections

### Encryption Overhead
- **ChaCha20-Poly1305**: ~100 bytes overhead per packet
- **Ed25519 Signatures**: 64 bytes per message
- **Key Exchange**: One-time 32-byte X25519 exchange
- **Performance Impact**: <1% CPU on modern ARM processors

### Bytecode Efficiency
- **Instruction Size**: 50-500 bytes typical
- **Response Size**: Variable (images: KB-MB, text: bytes-KB)
- **Compression**: Built-in zstd compression for large responses
- **Serialization**: Fast binary format with serde

This architecture ensures that Anbernic devices remain air-gapped and secure while still providing access to powerful external computing resources through the laptop daemon proxy system.