# P2P Mesh System - Quick Reference Guide

## Overview
This quick reference shows how to use P2P features across all handheld office applications with different controller types.

## Controller Layouts

### Game Boy Style (4 buttons + D-pad)
```
     ┌─────┐
   ┌─┤  ↑  ├─┐
 ┌─┤← │  ●  │ →├─┐         [SELECT] [START]
 │ └─┤  ↓  ├─┘ │              ●      ●
 │   └─────┘   │
 │             │              [B]    [A]
 │    D-PAD    │               ●      ●
 │             │
 └─────────────┘
```

### SNES Style (6 buttons + D-pad)
```
     ┌─────┐
   ┌─┤  ↑  ├─┐
 ┌─┤← │  ●  │ →├─┐    [L]            [R]
 │ └─┤  ↓  ├─┘ │      ●              ●
 │   └─────┘   │
 │             │    [SELECT] [START]
 │    D-PAD    │        ●      ●       [X]
 │             │                       ●
 └─────────────┘                   [Y] ● ● [A]
                                       ●
                                      [B]
```

## P2P Controls by Application

### 🎵 Media Player

#### Game Boy Controls
| Button | Action |
|--------|--------|
| START | Open P2P browser (if P2P enabled) |
| SELECT | Toggle playback modes |
| A | Select/play media |
| B | Back/stop |
| D-PAD | Navigate media library |

#### SNES Controls
| Button | Action |
|--------|--------|
| START | Open P2P browser |
| Y | Toggle P2P on/off |
| X | Share current media file |
| A | Select/play media |
| B | Back/stop |
| L | Browse shared media (previous) |
| R | Browse shared media (next) |
| D-PAD | Navigate media library |

#### P2P Browser Mode (Media Player)
| Button | Action |
|--------|--------|
| A | Download selected media |
| X | Share current media |
| B/SELECT | Exit P2P browser |
| UP/DOWN | Browse available files |
| LEFT/RIGHT | Filter by media type |

---

### 🎨 Paint Program

#### Game Boy Controls
| Button | Action |
|--------|--------|
| START | Open P2P browser (if P2P enabled) |
| SELECT | Toggle drawing modes |
| A | Draw/select |
| B | Erase/back |
| D-PAD | Move cursor/navigate |

#### SNES Controls
| Button | Action |
|--------|--------|
| START | Open P2P browser |
| Y | Start/join collaborative art session |
| X | Share current artwork |
| A | Draw/select |
| B | Erase/back |
| L + R | Export artwork to P2P network |
| D-PAD | Move cursor/navigate |

#### Collaborative Art Mode
| Button | Action |
|--------|--------|
| A | Continue drawing |
| X | Share current state |
| Y | View participants |
| B/SELECT | Exit collaboration |
| D-PAD | Move cursor |

---

### 📝 Enhanced Input/Word Processor

#### Game Boy Controls
| Button | Action |
|--------|--------|
| START | Open P2P browser (if P2P enabled) |
| SELECT | Enter/exit edit mode |
| A | Select character/action |
| B | Backspace |
| D-PAD | Navigate/move cursor |

#### SNES Controls
| Button | Action |
|--------|--------|
| START | Open P2P browser |
| Y | Toggle P2P on/off |
| X | Open document saver |
| SELECT | Enter/exit edit mode |
| A | Select character/action |
| B | Backspace |
| D-PAD | Navigate/radial menus |

#### P2P Browser Mode (Documents)
| Button | Action |
|--------|--------|
| A | Download/open selected document |
| X | Share current document |
| Y | Enter collaboration mode |
| B/SELECT | Exit P2P browser |
| UP/DOWN | Browse available documents |

#### Collaboration Mode (Real-time Editing)
| Button | Action |
|--------|--------|
| A | Sync current changes |
| X | View participant list |
| Y | Send cursor position |
| B/SELECT | Exit collaboration mode |
| D-PAD | Move cursor (synced with others) |

#### Document Saver Mode
| Button | Action |
|--------|--------|
| A | Save document locally |
| X | Export to P2P network |
| Y | Toggle auto-save on/off |
| B/SELECT | Exit document saver |
| UP/DOWN | Choose save location |

## P2P Status Indicators

### Visual Status Display
```
P2P: [●] ENABLED          P2P: [○] DISABLED
Peers: 3 devices          Peers: 0 devices
Files: 12 shared          Files: 0 shared
Collab: ACTIVE            Collab: INACTIVE
```

### Status Messages
| Message | meaning |
|---------|---------|
| "P2P enabled" | P2P system successfully activated |
| "P2P disabled" | P2P system deactivated |
| "P2P enable failed" | Failed to start P2P (check network) |
| "shared_document_[name]" | Document successfully shared |
| "synced_N_changes" | N collaborative changes synchronized |
| "saved_[filename]" | File saved locally |
| "p2p_not_enabled" | Attempted P2P action without P2P active |

## Common P2P Workflows

### 🔄 Basic File Sharing

1. **Enable P2P**: Press Y (SNES) or navigate to settings (Game Boy)
2. **Share File**: Press X in any application
3. **Browse Files**: Press START to open P2P browser
4. **Download**: Press A on desired file in browser

### 👥 Collaborative Editing (Word Processor)

1. **Enable P2P**: Press Y (SNES)
2. **Enter Edit Mode**: Press SELECT
3. **Start Collaboration**: Press START → Y
4. **Write Together**: Normal typing, changes sync automatically
5. **View Participants**: Press X in collaboration mode
6. **Exit**: Press SELECT or B

### 🎨 Collaborative Art Session

1. **Enable P2P**: Press Y (SNES)
2. **Start Session**: Press Y again in paint mode
3. **Draw Together**: Normal drawing, strokes sync in real-time
4. **Share Final Art**: Press X when finished
5. **Exit Session**: Press B or SELECT

### 📱 Cross-Device Media Sharing

1. **Device A**: Enable P2P, share media file (X button)
2. **Device B**: Enable P2P, open P2P browser (START)
3. **Device B**: Browse and select shared media (A button)
4. **Device B**: Download and enjoy content

## Troubleshooting Quick Fixes

### P2P Not Working
1. **Toggle P2P**: Press Y twice (off then on)
2. **Check Network**: Ensure devices on same WiFi
3. **Restart App**: Exit and restart application
4. **Clear Cache**: In P2P browser, hold L+R+SELECT

### Collaboration Issues
1. **Rejoin Session**: Exit collaboration (B) and rejoin (START → Y)
2. **Manual Sync**: Press A in collaboration mode
3. **Check Participants**: Press X to see who's connected
4. **Restart Session**: Exit and create new session

### File Transfer Failures
1. **Retry Download**: Press A again on failed file
2. **Check Storage**: Ensure device has free space
3. **Clear Transfers**: Hold B+SELECT in P2P browser
4. **Reset P2P**: Toggle P2P off and on

## Battery Conservation Tips

### Efficient P2P Usage
- **Auto-disable**: P2P automatically disables during low battery
- **Manual Control**: Turn off P2P when not needed (Y button)
- **Background Mode**: P2P sleeps when device is idle
- **Quick Transfers**: Use 32KB chunks for fast, efficient transfers

### Best Practices
1. **Share in Bursts**: Transfer multiple files at once
2. **Use Local Storage**: Download important files locally
3. **Monitor Battery**: Check battery level before large transfers
4. **Close Sessions**: Exit collaboration when done

## Advanced Features

### File Tagging
When sharing files, automatic tags are applied:
- **Media Player**: `video`, `audio`, `media`, `entertainment`
- **Paint Program**: `artwork`, `digital_art`, `collaborative`
- **Word Processor**: `document`, `text`, `collaborative`, `handheld`

### Search Functionality
In P2P browser mode:
- **LEFT/RIGHT**: Filter by file type
- **UP/DOWN**: Browse filtered results
- **A**: Download selected file
- **X**: Share file from current app

### Session Management
- **Session IDs**: Collaborative sessions use unique identifiers
- **Auto-cleanup**: Old sessions automatically expire
- **Rejoin**: Can rejoin sessions with same ID
- **Cross-app**: Sessions work across different applications

---

💡 **Tip**: Hold SELECT+START for 3 seconds in any mode to see current P2P status and available actions.

For detailed technical information, see the [complete P2P documentation](p2p-mesh-system.md).