-- Lua orchestration script for handheld office project
-- Handles building, running, and managing the multi-component system

local json = require("json")
local os = require("os")
local io = require("io")

local Orchestrator = {}
Orchestrator.__index = Orchestrator

function Orchestrator:new()
    local self = setmetatable({}, Orchestrator)
    self.components = {
        daemon = {
            name = "daemon",
            binary_path = "target/release/daemon",
            port = 8080,
            status = "stopped"
        },
        handheld = {
            name = "handheld",
            binary_path = "target/release/handheld",
            status = "stopped"
        },
        desktop_llm = {
            name = "desktop-llm",
            binary_path = "target/release/desktop-llm",
            status = "stopped"
        }
    }
    self.build_state = {}
    return self
end

function Orchestrator:log(message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    print(string.format("[%s] %s", timestamp, message))
    
    -- Save to files/build for state tracking
    local log_file = io.open("files/build/orchestrator.log", "a")
    if log_file then
        log_file:write(string.format("[%s] %s\n", timestamp, message))
        log_file:close()
    end
end

function Orchestrator:save_state()
    local state = {
        components = self.components,
        build_state = self.build_state,
        timestamp = os.time()
    }
    
    local state_file = io.open("files/build/orchestrator_state.json", "w")
    if state_file then
        state_file:write(json.encode(state))
        state_file:close()
    end
end

function Orchestrator:load_state()
    local state_file = io.open("files/build/orchestrator_state.json", "r")
    if state_file then
        local content = state_file:read("*all")
        state_file:close()
        
        local state = json.decode(content)
        if state then
            self.components = state.components or self.components
            self.build_state = state.build_state or {}
            self:log("Loaded previous state")
        end
    end
end

function Orchestrator:build_all()
    self:log("Starting build process...")
    
    -- Step 1: Check dependencies
    self:log("Checking Rust toolchain...")
    local rust_check = os.execute("rustc --version > /dev/null 2>&1")
    if rust_check ~= 0 then
        self:log("ERROR: Rust toolchain not found")
        return false
    end
    
    -- Step 2: Build with validation at each step
    self:log("Building daemon...")
    local daemon_build = os.execute("cargo build --release --bin daemon")
    if daemon_build ~= 0 then
        self:log("ERROR: Daemon build failed")
        self.build_state.daemon = "failed"
        self:save_state()
        return false
    end
    self.build_state.daemon = "success"
    self:save_state()
    
    self:log("Building handheld client...")
    local handheld_build = os.execute("cargo build --release --bin handheld")
    if handheld_build ~= 0 then
        self:log("ERROR: Handheld build failed")
        self.build_state.handheld = "failed"
        self:save_state()
        return false
    end
    self.build_state.handheld = "success"
    self:save_state()
    
    self:log("Building desktop LLM service...")
    local llm_build = os.execute("cargo build --release --bin desktop-llm")
    if llm_build ~= 0 then
        self:log("ERROR: Desktop LLM build failed")
        self.build_state.desktop_llm = "failed"
        self:save_state()
        return false
    end
    self.build_state.desktop_llm = "success"
    self:save_state()
    
    self:log("All components built successfully")
    return true
end

function Orchestrator:start_daemon()
    if self.components.daemon.status == "running" then
        self:log("Daemon already running")
        return true
    end
    
    self:log("Starting daemon on port " .. self.components.daemon.port)
    local cmd = string.format("./%s &", self.components.daemon.binary_path)
    local result = os.execute(cmd)
    
    if result == 0 then
        self.components.daemon.status = "running"
        self:log("Daemon started successfully")
        self:save_state()
        return true
    else
        self:log("ERROR: Failed to start daemon")
        return false
    end
end

function Orchestrator:start_llm_service()
    if self.components.desktop_llm.status == "running" then
        self:log("LLM service already running")
        return true
    end
    
    self:log("Starting desktop LLM service...")
    local cmd = string.format("./%s &", self.components.desktop_llm.binary_path)
    local result = os.execute(cmd)
    
    if result == 0 then
        self.components.desktop_llm.status = "running"
        self:log("LLM service started successfully")
        self:save_state()
        return true
    else
        self:log("ERROR: Failed to start LLM service")
        return false
    end
end

function Orchestrator:start_handheld()
    self:log("Starting handheld client...")
    local cmd = string.format("./%s", self.components.handheld.binary_path)
    local result = os.execute(cmd)
    
    if result == 0 then
        self:log("Handheld client started successfully")
        return true
    else
        self:log("ERROR: Failed to start handheld client")
        return false
    end
end

function Orchestrator:run_full_system()
    self:log("Starting full handheld office system...")
    
    if not self:build_all() then
        self:log("Build failed, aborting startup")
        return false
    end
    
    if not self:start_daemon() then
        self:log("Daemon startup failed, aborting")
        return false
    end
    
    -- Wait a moment for daemon to initialize
    os.execute("sleep 2")
    
    if not self:start_llm_service() then
        self:log("LLM service startup failed, continuing without AI")
    end
    
    -- Start handheld client (blocking)
    self:start_handheld()
    
    return true
end

function Orchestrator:stop_all()
    self:log("Stopping all components...")
    
    -- Kill processes by name (simple approach)
    os.execute("pkill -f daemon")
    os.execute("pkill -f desktop-llm")
    os.execute("pkill -f handheld")
    
    -- Reset status
    for _, component in pairs(self.components) do
        component.status = "stopped"
    end
    
    self:save_state()
    self:log("All components stopped")
end

function Orchestrator:status()
    self:log("=== Handheld Office System Status ===")
    for name, component in pairs(self.components) do
        self:log(string.format("%s: %s", component.name, component.status))
    end
    
    self:log("=== Build State ===")
    for component, state in pairs(self.build_state) do
        self:log(string.format("%s: %s", component, state))
    end
end

-- CLI interface
local function main(args)
    local orchestrator = Orchestrator:new()
    orchestrator:load_state()
    
    local command = args[1] or "help"
    
    if command == "build" then
        orchestrator:build_all()
    elseif command == "run" then
        orchestrator:run_full_system()
    elseif command == "start-daemon" then
        orchestrator:start_daemon()
    elseif command == "start-llm" then
        orchestrator:start_llm_service()
    elseif command == "start-handheld" then
        orchestrator:start_handheld()
    elseif command == "stop" then
        orchestrator:stop_all()
    elseif command == "status" then
        orchestrator:status()
    else
        print("Handheld Office Orchestrator")
        print("Usage:")
        print("  lua scripts/orchestrator.lua build         - Build all components")
        print("  lua scripts/orchestrator.lua run           - Build and run full system")
        print("  lua scripts/orchestrator.lua start-daemon  - Start daemon only")
        print("  lua scripts/orchestrator.lua start-llm     - Start LLM service only")
        print("  lua scripts/orchestrator.lua start-handheld- Start handheld client")
        print("  lua scripts/orchestrator.lua stop          - Stop all components")
        print("  lua scripts/orchestrator.lua status        - Show system status")
    end
end

-- Run if called directly
if arg and arg[0] and arg[0]:match("orchestrator%.lua") then
    main(arg)
end

return Orchestrator