# Issue Reorganization Plan v2

## Overview

Consolidating 13 phases into 10 functional phases based on logical feature groupings.

## New Phase Structure

| New | Theme | Source Phases | Description |
|-----|-------|---------------|-------------|
| 1 | Core Infrastructure | 1 + 4 | Foundation, threadpool, parallel ball processing |
| 2 | World & Physics | 2 + 3 | World structure, ball physics, collisions |
| 3 | Feedback Systems | 5 + 9 + particles from 8 | Scoring, particles, visual feedback |
| 4 | Display | 6 + UI from 8,13 | Viewport, window, UI elements |
| 5 | Gameplay | 7 + spawn from 13 | Spawn system, gameplay mechanics |
| 6 | Progression | upgrades from 8 | Upgrade system, player progression |
| 7 | Competition | adversary from 8 + 13 | Adversary AI, combat, cross-board physics |
| 8 | Stages | 10 + stage from 13 | Stage system, ramps, world expansion |
| 9 | Editor | 11 + 12 | All editor functionality |
| 10 | Dynamic & Advanced | 13 (remaining) | Rotors, tracks, sleep, config |

## Detailed Mapping

### Phase 1: Core Infrastructure
| Old | New | Description |
|-----|-----|-------------|
| 101 | 101 | Create Makefile build system |
| 102 | 102 | Implement threadpool |
| 103 | 103 | Create raylib window |
| 104 | 104 | Create basic project structure |
| 105 | 105 | Create local dependency build script |
| 106 | 106 | Detect system threads |
| 401 | 107 | Create ball task data structure |
| 402 | 108 | Implement parallel ball update |
| 403 | 109 | Implement synchronization barriers |
| 404 | 110 | Integrate parallel updates main |
| 405 | 111 | Create performance benchmark |

### Phase 2: World & Physics
| Old | New | Description |
|-----|-----|-------------|
| 201 | 201 | Create world state structure |
| 202 | 202 | Implement peg grid generation |
| 203 | 203 | Implement score zones |
| 204 | 204 | Integrate world rendering |
| 205 | 205 | Center table in window |
| 206 | 206 | Add guard rails |
| 301 | 207 | Create ball state structure |
| 302 | 208 | Implement ball physics |
| 303 | 209 | Implement peg collision |
| 304 | 210 | Implement boundary collision |
| 305 | 211 | Implement ball spawning input |
| 306 | 212 | Add ball collisions |

### Phase 3: Feedback Systems
| Old | New | Description |
|-----|-----|-------------|
| 501 | 301 | Implement score zone detection |
| 502 | 302 | Implement scoring ball capture |
| 503 | 303 | Add visual polish colors |
| 504 | 304 | Add particle effects |
| 505 | 305 | Final gameplay polish |
| 506 | 306 | Fix ball scoring bug |
| 507 | 307 | Improve particle effects |
| 901 | 308 | Particle system double buffering |
| 902 | 309 | Particle task data structure |
| 903 | 310 | Parallel simple ripple update |
| 904 | 311 | Parallel fragment collision |
| 905 | 312 | Particle integration synchronization |
| 812 | 313 | Particle effects overhaul |
| 813 | 314 | Fix persistent splash particles |
| 815 | 315 | Directional explosion fragments |
| 1321 | 316 | Allow multiple gate scoring |
| 1323 | 317 | GateRow scoring never called |
| 1324 | 318 | Grid zone dispatch system |

### Phase 4: Display
| Old | New | Description |
|-----|-----|-------------|
| 601 | 401 | Add scrolling viewport |
| 602 | 402 | Dynamic window resize |
| 603 | 403 | Scroll limits |
| 604 | 404 | Fix info box resize |
| 811 | 405 | Escape key behavior |
| 1314 | 406 | Editor panel UI system |
| 1315 | 407 | Hide game UI keybind |
| 1316 | 408 | Minimum window width |
| 1317 | 409 | Collapsible drawer UI |

### Phase 5: Gameplay
| Old | New | Description |
|-----|-----|-------------|
| 701 | 501 | Auto spawn toggle |
| 702 | 502 | Move info boxes to top |
| 703 | 503 | Movable spawn point |
| 704 | 504 | Improve spawn visual |
| 705 | 505 | Spawn buffering system |
| 1309 | 506 | Unified spawner system |
| 1325 | 507 | Adversary spawn toggle keybind |

### Phase 6: Progression
| Old | New | Description |
|-----|-----|-------------|
| 801 | 601 | Upgrade system framework |
| 802 | 602 | Spawn rate upgrade |
| 803 | 603 | Ball radius upgrade |
| 810 | 604 | Granular upgrade levels |

### Phase 7: Competition
| Old | New | Description |
|-----|-----|-------------|
| 804 | 701 | Adversary board layout |
| 805 | 702 | Adversary spawning AI |
| 806 | 703 | Shared gates ball passthrough |
| 807 | 704 | Cross board ball physics |
| 808 | 705 | Gate bumpers |
| 809 | 706 | Ball health damage system |
| 814 | 707 | Glancing collision damage scaling |
| 1302 | 708 | Adversary board flip axis |
| 1318 | 709 | Separate player adversary scores |
| 1320 | 710 | Remove adversary board tinting |

### Phase 8: Stages
| Old | New | Description |
|-----|-----|-------------|
| 1001 | 801 | Reticle toggle mouse control |
| 1002 | 802 | Stage system architecture |
| 1003 | 803 | Dynamic world vertical expansion |
| 1004 | 804 | Multi row gate system |
| 1005 | 805 | Ramp obstacle type |
| 1006 | 806 | Stage 2 ramp layout |
| 1007 | 807 | Stage insertion animation |
| 1008 | 808 | Next stage upgrade integration |
| 1009 | 809 | Ball screen wrapping |
| 1010 | 810 | Low speed impact damage reduction |
| 1304 | 811 | Stage spawn broken |
| 1308 | 812 | Expand grid dimensions |

### Phase 9: Editor
| Old | New | Description |
|-----|-----|-------------|
| 1101 | 901 | Board data format JSON schema |
| 1102 | 902 | Grid system architecture |
| 1103 | 903 | Board loader JSON to game |
| 1104 | 904 | Editor mode toggle |
| 1105 | 905 | Object palette UI |
| 1106 | 906 | Object placement system |
| 1107 | 907 | Object removal system |
| 1108 | 908 | Board save functionality |
| 1109 | 909 | Board load functionality |
| 1110 | 910 | Line drawing tool |
| 1111 | 911 | Stage pool system |
| 1112 | 912 | Portal zone system |
| 1113 | 913 | Object property editor |
| 1114 | 914 | Editor overlay mode |
| 1115 | 915 | Fix player ball wrap position |
| 1116 | 916 | Dynamic wrap zones |
| 1117 | 917 | Ball wrap gate reset |
| 1118 | 918 | Player reticle display bug |
| 1119 | 919 | Reticle color inversion |
| 1201 | 920 | Standalone editor application |
| 1202 | 921 | Remove editor from game |
| 1203 | 922 | Editor improvements |
| 1203a | 922a | Editor loading broken |
| 1203b | 922b | Editor guard rails |
| 1203c | 922c | Editor grid intersection snap |
| 1203d | 922d | Editor scrolling |
| 1203e | 922e | Editor filename prompt |
| 1204 | 923 | Erase cursor intersection snap |
| 1205 | 924 | Editor board height mismatch |
| 1206 | 925 | Documentation update |
| 1207 | 926 | Generate default board on compile |
| 1208 | 927 | Editor file browser delete |
| 1209 | 928 | Random first board |
| 1210 | 929 | Random adversary board |
| 1211 | 930 | Standalone editor property panel |
| 1212 | 931 | Editor scroll breaks line placement |
| 1213 | 932 | Editor clickable toolbar buttons |
| 1214 | 933 | Save dialog cursor movement |
| 1215 | 934 | Random board selection not working |
| 1216 | 935 | JSON board overwritten on resize |
| 1217 | 936 | Unify line ramp abstraction |
| 1218 | 937 | Editor file picker vim keybinds |
| 1219 | 938 | Line gravity assist wrong direction |
| 1220 | 939 | Pegs not anchored to guard rails |
| 1221 | 940 | Slot based world layout |
| 1222 | 941 | Velocity dependent restitution |
| 1223 | 942 | Portal improvements |
| 1224 | 943 | In progress board flag |
| 1225 | 944 | RGB property increments |
| 1226 | 945 | Drag select multi edit |
| 1227 | 946 | Portal zone fill cell |
| 1228 | 947 | Editor scroll broken |

### Phase 10: Dynamic & Advanced
| Old | New | Description |
|-----|-----|-------------|
| 1301 | 1001 | Random ball colors |
| 1303 | 1002 | Progress bar color flip |
| 1305 | 1003 | Rotor system |
| 1305a | 1003a | Rotor data structure |
| 1305b | 1003b | Editor rotor placement tool |
| 1305c | 1003c | Line rotation physics |
| 1305d | 1003d | Connected object detection |
| 1305e | 1003e | Collision modes |
| 1305f | 1003f | Ball crushing |
| 1305g | 1003g | Direction config UI |
| 1306 | 1004 | Track mover system |
| 1306a | 1004a | Track data structure |
| 1306b | 1004b | Editor track drawing tool |
| 1306c | 1004c | Mover payload detection |
| 1306d | 1004d | Track following physics |
| 1306e | 1004e | Intersection path selection |
| 1306f | 1004f | Back and forth motion |
| 1306g | 1004g | Track ball interaction |
| 1307 | 1005 | Ball sleep system |
| 1307a | 1005a | Sleep state tracking |
| 1307b | 1005b | Sleep transition logic |
| 1307c | 1005c | Wake conditions |
| 1307d | 1005d | Soft collision response |
| 1307e | 1005e | Stress source distinction |
| 1310 | 1006 | Compile time config |
| 1311 | 1007 | Trajectory history and overlap nudge |
| 1312 | 1008 | Closed polygon detection and fill |
| 1313 | 1009 | Standardize board dimensions |
| 1319 | 1010 | Material type selector |
| 1322 | 1011 | Ball velocity statistics |

## Execution Steps

1. Create backup of issues directory (done)
2. Rename all issue files according to mapping
3. Update "Parent Phase" references in all issue files
4. Delete old phase progress files (11, 12, 13)
5. Create new phase progress files (1-10)
6. Verify all files renamed correctly
7. Commit changes
