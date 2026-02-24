# 11-002: 3D WiFi Spatial Mapping via Drone Chains

## Status
- **Priority:** MEDIUM
- **Category:** Infrastructure / Civilian Mapping
- **Dependencies:** 11-001 (DirectWiFi Mesh Networking)
- **Affected Files:** `src/mesh/`, `tools/spatial-map/`

## Overview

Create a 3D spatial mapping system using WiFi signal propagation patterns from mesh-connected drone chains. Each node in the chain acts as a radar-like sensor, measuring signal reflections and strengths to build a volumetric model of the explored space. Range extends as far as the drone chain reaches.

```
                    ╭──────────────────────────────────────╮
                    │  3D Spatial Map (top-down slice)     │
    [Base]          │  ░░░░░▓▓▓▓░░░░░░░░░▓▓▓▓▓░░░░░░░░░░  │
       │            │  ░░░░▓████▓░░░░░░░▓█████▓░░░░░░░░░░  │
    [Drone1]────────│  ░░░▓██████▓░░░░░▓███████▓░░░░░░░░░  │
       │            │  ░░░▓██████▓░░░░░▓███████▓░░░░░░░░░  │
    [Drone2]────────│  ░░░░▓████▓░░░░░░░▓█████▓░░░░░░░░░░  │
       │            │  ░░░░░▓▓▓▓░░░░░░░░░▓▓▓▓▓░░░░░░░░░░░  │
    [Drone3]        │  ░ = open space  ▓ = structure edge  │
       │            │  █ = solid mass                      │
      ...           ╰──────────────────────────────────────╯
```

## The Vision

Most of the world is fine. We just don't have good maps of it.

Civilians generating complete mappings of their spaces - homes, towns, nations - reveals that anomalies are rare. The monotony is worth celebrating. When we can see that infrastructure works, that buildings stand, that roads connect, we stop imagining threats in every shadow.

What if we automated the anxious parts for a year or three? Let the drones map while we pick projects we actually care about. The transition is smooth when we can *see* the terrain.

## Current Behavior

- Mesh networking provides connectivity but no spatial awareness
- No way to visualize the physical space the network spans
- Drone range limited to direct control, not relay chains
- Signal strength data discarded after connection established

## Intended Behavior

### Signal-Based Spatial Sensing

WiFi signals reflect, refract, and attenuate through materials. By analyzing:
- **RSSI patterns** - Signal strength from multiple angles
- **Time-of-flight** - Distance estimation via round-trip timing
- **Multipath analysis** - Reflections reveal surfaces
- **Attenuation mapping** - Material density estimation

Each drone becomes a radar node, painting the space around it.

### Drone Chain Architecture

```
[Base Station]
      │
      │ ← Direct control range (~100m outdoor)
      │
  [Drone 1] ─── scans sector, relays to base
      │
      │ ← Extended range via relay
      │
  [Drone 2] ─── scans sector, relays via Drone 1
      │
      │
  [Drone 3] ─── edge of explored space
      │
     ... ← Chain extends as needed
```

Each drone maintains:
- Uplink to previous node (toward base)
- Downlink to next node (away from base)
- Local scan data buffer
- Position estimate (GPS or dead-reckoning)

### 3D Voxel Map Output

```lua
VoxelMap = {
    resolution = 0.5,        -- meters per voxel
    origin = {x=0, y=0, z=0},
    dimensions = {x=1000, y=1000, z=100},

    -- Voxel states
    UNKNOWN = 0,             -- Not yet scanned
    EMPTY = 1,               -- Open air, signals pass
    SOFT = 2,                -- Partial attenuation (foliage, drywall)
    SOLID = 3,               -- Full attenuation (concrete, metal)
    REFLECTIVE = 4,          -- Strong reflection (water, metal surfaces)
}
```

## Suggested Implementation Steps

### Part 1: Signal Analysis Module

```c
/* src/mesh/spatial-scan.h */

typedef struct {
    float rssi_dbm;          /* Received signal strength */
    float noise_floor_dbm;   /* Background noise level */
    uint32_t timestamp_us;   /* Microsecond precision */
    uint8_t channel;         /* WiFi channel used */
} SignalSample;

typedef struct {
    float x, y, z;           /* Position in local frame */
    float yaw, pitch;        /* Antenna orientation */
    SignalSample samples[360]; /* Full rotation scan */
} ScanFrame;

/* Collect signal samples during antenna rotation */
ScanFrame* spatial_scan_capture(MeshNode* node);

/* Extract distance estimates from time-of-flight */
float estimate_distance(SignalSample* sample);

/* Detect reflection surfaces from multipath */
ReflectionSet* detect_reflections(ScanFrame* frame);
```

### Part 2: Drone Chain Protocol

```lua
-- Drone chain message types
CHAIN_MSG = {
    EXTEND = 0x01,       -- Request next drone join chain
    SCAN = 0x02,         -- Trigger local scan
    DATA = 0x03,         -- Scan data packet
    RETRACT = 0x04,      -- Pull chain back one node
    HEARTBEAT = 0x05,    -- Chain health check
    POSITION = 0x06,     -- Position update
}

-- {{{ send_chain_scan_request
local function send_chain_scan_request(chain)
    -- Propagate scan command down the chain
    -- Each node scans its sector, relays results upstream
    for i = #chain, 1, -1 do
        local node = chain[i]
        send_to_node(node, {
            type = CHAIN_MSG.SCAN,
            scan_id = generate_scan_id(),
            relay_to = chain[i-1] or BASE_STATION,
        })
    end
end
-- }}}

-- {{{ process_scan_data
local function process_scan_data(data, voxel_map)
    -- Integrate scan data into 3D map
    local frame = data.frame
    local node_pos = data.position

    for angle, sample in ipairs(frame.samples) do
        local distance = estimate_distance(sample)
        local direction = angle_to_vector(angle, frame.yaw, frame.pitch)
        local hit_pos = node_pos + direction * distance

        -- Update voxel at hit position
        local voxel = voxel_map:get(hit_pos)
        voxel:update_from_sample(sample)
    end
end
-- }}}
```

### Part 3: Voxel Map Visualization

```lua
-- {{{ render_slice
local function render_slice(voxel_map, z_level, width, height)
    local chars = {
        [UNKNOWN] = '░',
        [EMPTY] = ' ',
        [SOFT] = '▒',
        [SOLID] = '█',
        [REFLECTIVE] = '▓',
    }

    local lines = {}
    for y = 0, height - 1 do
        local line = {}
        for x = 0, width - 1 do
            local voxel = voxel_map:get(x, y, z_level)
            table.insert(line, chars[voxel.state] or '?')
        end
        table.insert(lines, table.concat(line))
    end

    return table.concat(lines, '\n')
end
-- }}}
```

### Part 4: TUI Integration

Add to symbeline-tui.lua:

```lua
panels.spatial = {
    title = "3D Spatial Map",
    keybinds = {
        ["h/l"] = "rotate_view",      -- Horizontal rotation
        ["j/k"] = "change_slice",     -- Z-level up/down
        ["+/-"] = "zoom",             -- Zoom in/out
        ["s"] = "start_scan",         -- Begin drone chain scan
        ["c"] = "connect_chain",      -- Manage drone chain
        ["e"] = "export_map",         -- Export to file
        ["3"] = "toggle_3d",          -- Switch to 3D view
        ["Esc"] = "back",
    },
}

-- Main menu keybind
main.keybinds["gs"] = "spatial"  -- Go to spatial map
```

### Part 5: Export Formats

```lua
-- Export to common 3D formats for external visualization
local exporters = {
    -- Point cloud for photogrammetry tools
    ply = function(voxel_map, filename)
        -- PLY format export
    end,

    -- Mesh for 3D modeling
    obj = function(voxel_map, filename)
        -- Wavefront OBJ export (marching cubes)
    end,

    -- GeoJSON for mapping tools
    geojson = function(voxel_map, filename, geo_origin)
        -- Geographic coordinates for OpenStreetMap overlay
    end,

    -- Custom binary for fast loading
    vxl = function(voxel_map, filename)
        -- Compact binary voxel format
    end,
}
```

## Hardware Considerations

### Drone Requirements
- WiFi adapter with monitor mode (signal analysis)
- GPS or visual odometry (positioning)
- Rotating antenna OR multiple fixed antennas
- Sufficient battery for scan + relay duty
- Mesh firmware from 11-001

### Signal Analysis Limitations
- WiFi frequency (2.4GHz/5GHz) limits resolution to ~6cm/3cm
- Metal structures cause strong reflections (good for detection)
- Foliage and rain scatter signals (noise, not blockers)
- Indoor mapping more accurate than outdoor (more reflections)

### Civilian Applications
- Building inspection (find structural anomalies)
- Search and rescue (map collapsed structures)
- Infrastructure audit (tunnel, bridge, pipe mapping)
- Archaeological survey (non-invasive ground penetration)
- Community mapping projects (know your neighborhood)

## The Wheat-Stalks Principle

The reaper comes for what must be harvested. Rather than building weapons of ever-increasing power, we could grow wheat-stalks in abundance - resources devoted to the cause, shrine-style.

Map the world. Find that most of it is fine. Celebrate the monotony. Automate the anxious surveillance and let humans do what they actually care about.

Liberty asks to be freed from war and poverty. Perhaps the first step is *seeing* - a complete picture that shows the plenty alongside the scarcity, the stability alongside the anomaly.

```
    The drone chain extends not for conquest,
    but for cartography. Not to find targets,
    but to prove their absence.

    Most of the world is fine.
    Now we can see it.
```

## Test Cases

1. Single drone scan -> Produces 360° signal map
2. Two-drone chain -> Data relays to base correctly
3. Five-drone chain -> Latency acceptable, no data loss
4. Scan of known room -> Voxel map matches actual dimensions (±0.5m)
5. Export to PLY -> Opens in MeshLab correctly
6. TUI slice view -> Navigable with h/j/k/l keys
7. Chain extension -> New drone integrates automatically
8. Chain break -> Graceful degradation, reconnection attempt

## Dependencies

- 11-001 (DirectWiFi Mesh) - Base networking layer
- iw / wireless-tools - Signal strength monitoring
- GPS daemon (gpsd) - Position data
- LuaJIT + FFI - Performance-critical signal processing

## Related Documents

- WiFi RTT (Round-Trip Time) specifications
- 802.11mc Fine Timing Measurement
- Voxel-based SLAM literature
- Community mapping initiatives (OpenStreetMap, etc.)

## Notes

- Start with 2D mapping, extend to 3D once proven
- Consider acoustic (ultrasound) as complementary modality
- Privacy considerations: scanning other people's spaces requires consent
- Open data format ensures community can build on maps
- The monotony is the point - stability is worth documenting
