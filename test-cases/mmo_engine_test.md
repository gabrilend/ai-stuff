# MMO Engine Test Case - AzerothCore Integration

## Test Scenario: Anbernic MMO with AzerothCore Server Integration

This test demonstrates the MMO engine running on multiple Anbernic devices with different connection modes:
1. Desktop AzerothCore server connection
2. Peer-to-peer swarm networking
3. Offline single-player mode

### Setup Instructions

1. **Build the MMO engine**:
```bash
cargo build --release --bin mmo-demo
```

2. **Terminal 1 - Simulate AzerothCore Server**:
```bash
# Start a mock AzerothCore server on port 8085
netcat -l 8085 &
echo "Mock AzerothCore server listening on 8085"
```

3. **Terminal 2 - Anbernic Client 1 (Server Connection)**:
```bash
# Run first client connecting to AzerothCore server
echo "1" | ./target/release/mmo-demo
```

4. **Terminal 3 - Anbernic Client 2 (P2P Mode)**:
```bash
# Start P2P bootstrap peers
netcat -l 8086 &
netcat -l 8087 &

# Run second client in P2P swarm mode
echo "2" | ./target/release/mmo-demo
```

5. **Terminal 4 - Anbernic Client 3 (Offline Mode)**:
```bash
# Run third client in offline mode
echo "3" | ./target/release/mmo-demo
```

### Expected Behavior

#### AzerothCore Connection Mode (Client 1)
```
🏰 Anbernic MMO Engine - AzerothCore Style
   WotLK-inspired networking without Blizzard assets!
   Perfect for handheld MMO gaming 🎮⚔️

🌍 Initializing game world...
   Generated map: Starter Valley (100x100)
👤 Player created: AnbernicHero (Level 1)

🔗 Connection Options:
   1. Connect to desktop AzerothCore server
   2. Join peer-to-peer swarm network
   3. Play offline (single-player mode)
   Enter 1, 2, or 3:
1
🖥️  Connecting to AzerothCore server...
✅ Connected to AzerothCore server!

🎮 Game Controls (Anbernic Style):
   WASD: Movement  |  QE: Turn  |  Space: Jump
   12345: Spells   |  I: Inventory  |  T: Chat
   C: Camera mode  |  TAB: Target  |  ESC: Menu
   Type 'help' for full commands | 'quit' to exit

Session: 0m 0s | Commands: 0
```

#### P2P Swarm Mode (Client 2)
```
🏰 Anbernic MMO Engine - AzerothCore Style
   WotLK-inspired networking without Blizzard assets!
   Perfect for handheld MMO gaming 🎮⚔️

🌍 Initializing game world...
   Generated map: Starter Valley (100x100)
👤 Player created: AnbernicHero (Level 1)

🔗 Connection Options:
   1. Connect to desktop AzerothCore server
   2. Join peer-to-peer swarm network
   3. Play offline (single-player mode)
   Enter 1, 2, or 3:
2
🌐 Joining P2P swarm network...
✅ Joined swarm network!

Session: 0m 0s | Commands: 0
```

#### Offline Mode (Client 3)
```
🏰 Anbernic MMO Engine - AzerothCore Style
   WotLK-inspired networking without Blizzard assets!
   Perfect for handheld MMO gaming 🎮⚔️

🌍 Initializing game world...
   Generated map: Starter Valley (100x100)
👤 Player created: AnbernicHero (Level 1)

🔗 Connection Options:
   1. Connect to desktop AzerothCore server
   2. Join peer-to-peer swarm network
   3. Play offline (single-player mode)
   Enter 1, 2, or 3:
3
🏠 Playing in offline mode

Session: 0m 0s | Commands: 0
```

### Test Commands

Run these commands in each client to test different features:

1. **Movement Test**:
```
w
w
e
w
stats
```

2. **Network Test** (in P2P and Server modes):
```
ping
who
sync
```

3. **Demo Sequence**:
```
demo
```

4. **Combat Test**:
```
attack
1
2
3
```

### Validation Checklist

- [ ] All three connection modes start successfully
- [ ] ASCII world rendering works on all clients
- [ ] Movement commands work (w/a/s/d/q/e)
- [ ] Camera mode cycling works (c command)
- [ ] Network status shows correct peer connections
- [ ] Player stats display correctly
- [ ] Demo sequence completes without errors
- [ ] All clients can quit cleanly

### Expected Network Packets

#### AzerothCore Server Mode
- AUTH_LOGON_CHALLENGE packets sent to server
- MSG_MOVE_START_FORWARD packets during movement
- SMSG_UPDATE_OBJECT packets received from server

#### P2P Swarm Mode
- P2P_SWARM_ANNOUNCE packets to bootstrap peers
- P2P_WORLD_STATE_SYNC packets between clients
- P2P_PLAYER_UPDATE packets during movement

### Performance Metrics

Expected performance on Anbernic RG35XX (ARM Cortex-A9):
- World generation: < 100ms
- Frame rendering: < 16ms (60 FPS target)
- Network packet processing: < 5ms
- Memory usage: < 32MB RAM

### Cross-Platform Compatibility

This test validates compatibility with:
- Anbernic RG35XX (ARM32)
- Anbernic RG405M (ARM64) 
- Anbernic RG503 (ARM64)
- Desktop Linux x86_64 (development)

### Cleanup

After testing, clean up background processes:
```bash
pkill -f "netcat"
pkill -f "mmo-demo"
```