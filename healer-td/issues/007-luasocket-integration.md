# Issue #007: Luasocket Integration (F005 partial)

**Priority**: High  
**Phase**: 3.1 (Networking Foundation)  
**Estimated Effort**: 2-3 days  
**Dependencies**: #005  

## Problem Description

Integrate Luasocket library and establish the foundation for peer-to-peer 
networking. This includes basic TCP/UDP socket handling, platform-specific 
setup, and error handling infrastructure.

## Current Behavior

Single-player game works but no networking capabilities exist.

## Expected Behavior

Luasocket properly integrated with basic socket creation, connection 
handling, and platform compatibility across Linux, macOS, and Windows.

## Implementation Approach

### Luasocket Integration
```lua
-- {{{ NetworkCore
local socket = require("socket")
local NetworkCore = {
  sockets = {},
  isInitialized = false
}

-- {{{ init
function NetworkCore:init()
  -- Test Luasocket functionality
  -- Initialize platform-specific networking
  -- Set up error handling
  -- Configure socket defaults
  local test = socket.udp()
  if test then
    test:close()
    self.isInitialized = true
    return true
  end
  return false
end
-- }}}

-- {{{ createTCPSocket
function NetworkCore:createTCPSocket()
  local sock = socket.tcp()
  if sock then
    sock:settimeout(0) -- Non-blocking
    sock:setoption("reuseaddr", true)
    sock:setoption("tcp-nodelay", true)
    return sock
  end
  return nil
end
-- }}}

-- {{{ createUDPSocket
function NetworkCore:createUDPSocket()
  local sock = socket.udp()
  if sock then
    sock:settimeout(0) -- Non-blocking
    sock:setoption("reuseaddr", true)
    return sock
  end
  return nil
end
-- }}}
```

### Connection Management
```lua
-- {{{ ConnectionManager
local ConnectionManager = {
  connections = {},
  servers = {},
  nextId = 1
}

-- {{{ createServer
function ConnectionManager:createServer(port)
  local server = socket.tcp()
  local success, err = server:bind("*", port or 0)
  
  if not success then
    return nil, err
  end
  
  success, err = server:listen(4)
  if not success then
    server:close()
    return nil, err
  end
  
  server:settimeout(0)
  
  local serverId = self.nextId
  self.nextId = self.nextId + 1
  
  self.servers[serverId] = {
    id = serverId,
    socket = server,
    port = server:getsockname()
  }
  
  return serverId
end
-- }}}

-- {{{ acceptConnection
function ConnectionManager:acceptConnection(serverId)
  local server = self.servers[serverId]
  if not server then
    return nil, "Invalid server ID"
  end
  
  local client, err = server.socket:accept()
  if client then
    client:settimeout(0)
    
    local connId = self.nextId
    self.nextId = self.nextId + 1
    
    self.connections[connId] = {
      id = connId,
      socket = client,
      address = client:getpeername(),
      lastActivity = socket.gettime(),
      state = "CONNECTED"
    }
    
    return connId
  end
  
  return nil, err
end
-- }}}

-- {{{ connectTo
function ConnectionManager:connectTo(address, port)
  local client = socket.tcp()
  client:settimeout(0)
  
  local result, err = client:connect(address, port)
  
  if result == 1 or err == "already connected" then
    -- Connection successful
    local connId = self.nextId
    self.nextId = self.nextId + 1
    
    self.connections[connId] = {
      id = connId,
      socket = client,
      address = address .. ":" .. port,
      lastActivity = socket.gettime(),
      state = "CONNECTED"
    }
    
    return connId
  elseif err == "timeout" then
    -- Connection in progress
    local connId = self.nextId
    self.nextId = self.nextId + 1
    
    self.connections[connId] = {
      id = connId,
      socket = client,
      address = address .. ":" .. port,
      lastActivity = socket.gettime(),
      state = "CONNECTING"
    }
    
    return connId
  else
    -- Connection failed
    client:close()
    return nil, err
  end
end
-- }}}
```

### Error Handling and Timeouts
```lua
-- {{{ NetworkErrorHandler
local NetworkErrorHandler = {}

-- {{{ handleSocketError
function NetworkErrorHandler:handleSocketError(err, operation, socket)
  local errorMap = {
    ["timeout"] = "TIMEOUT",
    ["closed"] = "CONNECTION_CLOSED",
    ["refused"] = "CONNECTION_REFUSED",
    ["broken pipe"] = "BROKEN_PIPE",
    ["host unreachable"] = "HOST_UNREACHABLE"
  }
  
  local errorType = errorMap[err] or "UNKNOWN_ERROR"
  
  return {
    type = errorType,
    message = err,
    operation = operation,
    recoverable = self:isRecoverable(errorType)
  }
end
-- }}}

-- {{{ isRecoverable
function NetworkErrorHandler:isRecoverable(errorType)
  local recoverableErrors = {
    "TIMEOUT",
    "HOST_UNREACHABLE"
  }
  
  for _, recoverable in ipairs(recoverableErrors) do
    if errorType == recoverable then
      return true
    end
  end
  
  return false
end
-- }}}
```

### Platform Compatibility
```lua
-- {{{ PlatformDetection
local PlatformDetection = {}

-- {{{ detectPlatform
function PlatformDetection:detectPlatform()
  local osType = package.config:sub(1,1) == "\\" and "windows" or "unix"
  
  if osType == "unix" then
    local handle = io.popen("uname")
    local result = handle:read("*a")
    handle:close()
    
    if result:match("Darwin") then
      return "macos"
    else
      return "linux"
    end
  end
  
  return "windows"
end
-- }}}

-- {{{ getNetworkInterfaces
function PlatformDetection:getNetworkInterfaces()
  local platform = self:detectPlatform()
  local interfaces = {}
  
  if platform == "linux" or platform == "macos" then
    -- Use ip addr or ifconfig
    local handle = io.popen("ip addr show 2>/dev/null || ifconfig")
    local result = handle:read("*a")
    handle:close()
    
    -- Parse network interfaces
    for line in result:gmatch("[^\r\n]+") do
      local ip = line:match("inet (%d+%.%d+%.%d+%.%d+)")
      if ip and ip ~= "127.0.0.1" then
        table.insert(interfaces, ip)
      end
    end
  elseif platform == "windows" then
    -- Use ipconfig
    local handle = io.popen("ipconfig")
    local result = handle:read("*a")
    handle:close()
    
    -- Parse Windows network interfaces
    for line in result:gmatch("[^\r\n]+") do
      local ip = line:match("IPv4 Address[^:]*: (%d+%.%d+%.%d+%.%d+)")
      if ip and ip ~= "127.0.0.1" then
        table.insert(interfaces, ip)
      end
    end
  end
  
  return interfaces
end
-- }}}
```

## Acceptance Criteria

- [ ] Luasocket loads successfully on all target platforms
- [ ] TCP sockets can be created and configured
- [ ] UDP sockets can be created and configured
- [ ] Server sockets can bind to ports and listen
- [ ] Client sockets can connect to servers
- [ ] Non-blocking I/O works correctly
- [ ] Connection timeouts handled properly
- [ ] Socket errors categorized and handled
- [ ] Platform detection works on Linux, macOS, Windows
- [ ] Network interface detection functional
- [ ] Socket cleanup and resource management working
- [ ] Concurrent connections supported

## Technical Notes

### Platform Considerations
- **Linux**: Standard POSIX sockets
- **macOS**: BSD socket behavior considerations
- **Windows**: Winsock differences and initialization

### Performance Requirements
- Socket operations < 1ms for local connections
- Non-blocking I/O prevents game loop blocking
- Memory usage minimal for socket management

### Security Considerations
- Socket binding permissions
- Local vs. remote connection policies
- Resource limits to prevent DoS

## Test Cases

1. **Basic Socket Operations**
   - TCP and UDP socket creation
   - Socket configuration and options
   - Socket cleanup and resource management

2. **Connection Management**
   - Server creation and client connections
   - Connection state tracking
   - Graceful connection closure

3. **Error Handling**
   - Network unreachable scenarios
   - Connection refused handling
   - Timeout and recovery behavior

4. **Platform Compatibility**
   - Works on Linux distributions
   - Functions on macOS versions
   - Operates on Windows systems

5. **Performance**
   - Multiple concurrent connections
   - Non-blocking operation verification
   - Resource usage monitoring

## Integration Points

- **Game Engine**: Network event integration
- **Configuration**: Network settings and preferences
- **Error System**: Network error reporting
- **Platform Layer**: OS-specific functionality

## Future Considerations

- IPv6 support addition
- Advanced socket options
- Network performance monitoring
- Connection pooling optimization