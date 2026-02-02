# Castle Defense Game / Work in progress

A tile-based defense RTS built with Odin and Raylib.

## Requirements

- [Odin Compiler](https://odin-lang.org/docs/install/)
- Raylib (included with Odin's vendor collection)

## Building

```bash
# Navigate to the project directory
cd "castle defense"

# Build the game
odin build src -out:rightward_hold.exe

# Or build and run
odin run src -out:rightward_hold.exe
```

## How to Play

### Objective
Defend your Town Core (right side) from waves of enemies spawning from the left. Survive 20 waves to win!

### Controls

| Key | Action |
|-----|--------|
| **B** | Open/Close Build Menu |
| **1-4** | Train Units (Infantry/Archer/Cavalry/Siege) |
| **H/J/K** | Hire Heroes (Tank/DPS/Support) |
| **SPACE** | Start Wave Early |
| **ESC** | Cancel/Pause |
| **R** | Rally units to mouse position |
| **Left Click** | Place building (when selected) |
| **Right Click** | Cancel building selection |
| **Shift + Click** | Place multiple buildings |

### Resources

- **Gold** - Used for units, heroes, and some buildings
- **Wood** - Used for buildings and defenses
- **Food** - Required to sustain your army (upkeep every 10 seconds)
- **Supply** - Limits your army size (increased by building Houses)

### Buildings

| Building | Cost | Function |
|----------|------|----------|
| House | 50W | +10 Supply capacity |
| Gold Mine | 100G 50W | Produces gold (must be adjacent to mountains) |
| Lumber Mill | 50G 25W | Produces wood |
| Farm | 50G 30W | Produces food |
| Barracks | 150G 100W | Trains Infantry and Siege |
| Archery Range | 175G 125W | Trains Archers |
| Stable | 250G 150W | Trains Cavalry |
| Basic Tower | 100G 75W | Single-target defense |
| Advanced Tower | 250G 150W | AoE defense |
| Wall | 40W | Blocks enemy paths |
| Research Hall | 300G 200W | Unlocks upgrades |

### Units

| Unit | Cost | Supply | Role |
|------|------|--------|------|
| Infantry | 50G | 2 | Melee frontline |
| Archer | 75G | 3 | Ranged support |
| Cavalry | 150G | 5 | Fast, powerful |
| Siege | 300G | 8 | Long-range, slow |

### Heroes (No Supply Cost!)

| Hero | Cost | Role |
|------|------|------|
| Tank | 500G | High HP, holds chokepoints |
| DPS | 600G | High damage, wave clear |
| Support | 550G | Heals nearby allies |

Heroes:
- Level up by killing enemies
- Gain stats on level up
- Respawn 30 seconds after death

### Enemy Types

| Enemy | Appearance | Behavior |
|-------|------------|----------|
| Basic | Red circle | Marches to core |
| Armored | Dark red | High HP, armor |
| Assassin | Purple | Targets economy buildings |
| Siege | Large brown | Targets walls and towers |
| Flyer | Yellow triangle | Ignores walls |


## Project Structure

```
castle defense/
├── src/
│   ├── main.odin      # Entry point and game loop
│   ├── types.odin     # All data structures and constants
│   ├── game.odin      # Core game systems
│   └── render.odin    # Rendering and UI
├── gamespecs.md       # Original game specification
└── README.md          # This file
```

## License

MIT License - Feel free to modify and use!
