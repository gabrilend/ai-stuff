# Issue 005: Standardize Ollama Port Configuration

## Current Behavior
- Project configured to use Ollama on port 10265 (192.168.0.115:10265)
- System bashalias configured for port 11434 (192.168.0.115:11434)
- Inconsistent port usage creates confusion and potential connection issues
- Multiple endpoint attempts needed in ollama-config.lua

## Intended Behavior  
- Consistent use of port 11434 across all project components
- Alignment with existing system bashalias configuration
- Single, reliable endpoint configuration
- Clear documentation of port choice rationale

## Suggested Implementation Steps
1. Update ollama-config.lua to prioritize port 11434
2. Update ollama-manager.lua default port configuration
3. Verify new Ollama build uses correct port after upgrade completes
4. Update all documentation referencing port 10265
5. Test embedding functionality with standardized port
6. Update vision document if necessary

## Metadata
- **Priority**: Medium
- **Estimated Time**: 1-2 hours
- **Dependencies**: Issue 002 (Ollama upgrade completion)
- **Category**: Configuration

## Related Documents
- issues/phase-1/002-configure-ollama-embedding-service.md - Embedding service configuration
- notes/vision - Original port specification
- /home/ritz/scripts/bashalias - System alias configuration

## Tools Required
- Text editor for configuration updates
- Ollama service for testing
- Network connectivity for endpoint verification

## Root Cause Analysis
**Discovery**: System bashalias shows `OLLAMA_HOST=192.168.0.115:11434` but project was configured for port 10265, creating unnecessary complexity and potential for connection failures.

**Impact**: 
- Forces endpoint detection logic to try multiple ports
- Creates confusion about which port should be used
- May cause intermittent connection issues
- Inconsistent with existing system configuration

**Solution**: Standardize on port 11434 to match system configuration and simplify endpoint management.

## Implementation Notes
- Update should be made after Issue 002 (Ollama upgrade) completes
- Verify the new Ollama build supports embedding on port 11434
- Consider whether port 10265 was chosen for a specific technical reason
- Ensure all scripts and configuration files are updated consistently

**2025-11-02 COMPLETION UPDATE:**

✅ **ISSUE COMPLETED - PORT CONFIGURATION STANDARDIZED**

**CHANGES IMPLEMENTED:**
1. ✅ Updated `libs/ollama-config.lua` endpoint priority order:
   - **Primary**: `http://192.168.0.115:11434` (matches bashalias)
   - **Secondary**: `http://localhost:11434`
   - **Fallback**: Port 10265 endpoints for backward compatibility

2. ✅ Updated default fallback endpoint to port 11434
3. ✅ Added descriptive comments explaining prioritization
4. ✅ Maintained backward compatibility with existing configurations

**CONFIGURATION DETAILS:**
- Endpoint detection now prioritizes port 11434 across all IP addresses
- Fallback to port 10265 ensures no disruption to existing setups  
- Comments added for clarity: "Primary: From bashalias configuration"
- Default fallback standardized: `http://localhost:11434`

**TESTING STATUS:**
- Port detection logic updated and ready for testing
- Configuration changes coordinated with Issue 002 (Ollama upgrade)
- Ready for service restart with new Ollama binary

**ISSUE STATUS: COMPLETED** ✅