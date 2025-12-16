# Healer-TD User Manual

## Getting Started

### System Requirements
- Terminal with minimum 80x24 character display
- Network connectivity (works on public wifi)
- Keyboard input capability
- No special ports or router configuration needed

### Installation
1. Download and run `healer-td` executable
2. No installation or setup required
3. Game works immediately out of the box

### First Launch
- Configure display preferences
- Set key bindings (optional)
- Choose single or multiplayer mode
- Create or join games with simple invite codes

## Basic Gameplay

### Objective
Survive enemy waves by strategically placing towers that come alive to 
fight. Use minimal gold to achieve maximum efficiency. Prevent enemies 
from "leaking" through your defenses to preserve lives.

### Game Flow
1. **Placement Phase**: Position towers before wave starts
2. **Combat Phase**: Watch towers move and fight enemies
3. **Upgrade Phase**: Choose enhancements every 5 waves
4. **Repeat**: Continue with increasing difficulty

### Victory and Defeat
- **Victory**: Survive all waves with lives remaining
- **Defeat**: Lose all lives when enemies leak through

## Controls

### Basic Navigation
```
Movement:
  W, K, ↑     - Select tower above current position
  A, H, ←     - Select tower to the left
  S, J, ↓     - Select tower below current position  
  D, L, →     - Select tower to the right

Actions:
  SPACE       - Place tower at cursor position
  DELETE      - Remove selected tower
  ENTER       - Confirm action/start wave
  ESC         - Cancel action/pause game

Information:
  I           - Show tower information
  TAB         - Switch between players (multiplayer)
  SHIFT+TAB   - Previous player (multiplayer)
  ?           - Show help screen
```

### Advanced Controls
```
View Management:
  +           - Zoom in (if supported)
  -           - Zoom out (if supported)
  PAGE UP     - Previous player view
  PAGE DOWN   - Next player view

Game Management:
  P           - Pause/unpause game
  Q           - Quit game (with confirmation)
  R           - Restart current wave
  CTRL+S      - Quick save (if enabled)
```

### Selection Behavior
When moving between towers:
- **Vertical Movement**: Finds closest tower on target row
- **Horizontal Movement**: Moves to adjacent tower on same row
- **No Target Found**: Searches alternating rows (±1, ±2, ±3, etc.)
- **Equidistant Towers**: Right tower preferred (configurable)

## Game Mechanics

### Resources
- **Gold**: Currency for purchasing towers
- **Lives**: Lost when enemies reach the end
- **Income**: Gained after surviving each wave
- **Bounty**: Earned by defeating enemies

### Tower System
- Place towers anywhere in your territory (bottom 2/3 of map)
- Each tower has unique stats: health, damage, speed, special abilities
- Towers move and fight autonomously during combat phase
- Collision system prevents overlapping units

### Enemy Behavior
- Spawn from top of map each wave
- Move toward bottom (your territory)
- Fight your towers when encountered
- Must navigate around obstacles and other units

### Combat Resolution
- Turn-based combat between towers and enemies
- Damage calculated based on unit statistics
- Defeated units provide gold bounty
- Surviving enemies continue toward exit

## Multiplayer Mode

### Getting Started
- **Create Game**: Generate a 6-character invite code to share
- **Join Game**: Enter invite code from another player
- **Local Discovery**: Automatically find games on your network
- **No Setup**: Works on public wifi without port forwarding

### Game Modes
- **Cooperative**: Help other players by sharing leaked units
- **Competitive**: Leaked units attack other players
- **Team-based**: Mixed cooperation within teams

### Player Interaction
- Each player has separate rectangular battlefield
- View other players using TAB/SHIFT+TAB
- Leaked units transfer to next player in rotation
- Shared upgrade choices every 5 waves

### Connection and Security
- All communication encrypted automatically
- Peer-to-peer connections for low latency
- Automatic reconnection if network drops
- No personal information required or stored

## Essential Upgrades

### Upgrade System
Every 5 waves, choose from 3 randomly selected upgrades:
- **Unit Enhancements**: Improve tower statistics
- **Economic Bonuses**: Increase gold income or reduce costs
- **Special Abilities**: Unlock new tower capabilities
- **Tactical Advantages**: Improve placement or movement options

### Strategy Tips
- Balance offensive and defensive upgrades
- Consider long-term game progression
- Coordinate with teammates in multiplayer
- Adapt choices based on upcoming enemy types

## Customization

### Display Options
Access via in-game settings menu:
- **Graphics Mode**: ASCII, Unicode, Emoji, Braille, Sixel
- **Color Scheme**: Standard, Colorblind-friendly, High contrast
- **Terminal Size**: Optimize for current display

### Key Bindings
Customize controls in configuration file:
```
~/.config/healer-td/keys.conf
```

### Configuration File
Main settings located at:
```
~/.config/healer-td/config.conf
```

Common options:
```
graphics_mode = unicode
color_scheme = standard
selection_priority = right
auto_pause = false
show_debug_info = false
```

## Tips and Strategies

### Beginner Tips
- Start with basic towers to learn combat mechanics
- Watch enemy movement patterns before placing towers
- Don't spend all gold immediately - save for emergencies
- Use pause function to plan complex strategies

### Advanced Strategies
- Create chokepoints to maximize tower effectiveness
- Balance tower types for different enemy weaknesses
- Manage gold efficiently across multiple waves
- Coordinate tower placement with natural pathing

### Multiplayer Coordination
- Communicate upgrade choices with teammates
- Plan complementary strategies
- Share leaked units strategically
- Balance individual and team objectives

## Troubleshooting

### Display Issues
- **Garbled Characters**: Try different graphics mode
- **Wrong Colors**: Adjust color scheme or terminal settings
- **Size Problems**: Resize terminal to minimum 80x24

### Connection Problems
- **Cannot Connect**: Check network connectivity and invite code
- **Lag Issues**: Game adapts automatically to connection quality
- **Disconnection**: Automatic reconnection attempts

### Performance Issues
- **Slow Response**: Reduce graphics complexity
- **Memory Usage**: Restart game periodically
- **CPU Usage**: Close unnecessary programs

### Getting Help
- **In-Game Help**: Press ? for quick reference
- **Community**: Join game forums for strategy discussion
- **Bug Reports**: Use in-game reporting system

## Accessibility

### Screen Reader Support
- All game information available via text descriptions
- Audio cues for important events (if enabled)
- Keyboard-only navigation

### Visual Accessibility
- High contrast mode for low vision
- Colorblind-friendly palettes
- Adjustable text size (terminal dependent)

### Motor Accessibility
- Customizable key bindings
- Adjustable input timing
- Pause-friendly gameplay

## Advanced Features

### Modding (Future)
- Custom unit types and abilities
- New visual themes
- Community-created content
- Scripting interface

### Tournament Mode (Future)
- Competitive rankings
- Standardized game settings
- Replay system
- Spectator mode

For additional help, consult the community forums or contact the 
development team through the in-game feedback system.