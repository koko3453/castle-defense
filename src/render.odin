package game

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"

// ============================================================================
// COLORS
// ============================================================================

COLOR_EMPTY       :: rl.Color{60, 60, 60, 255}
COLOR_BLOCKED     :: rl.Color{80, 80, 80, 255}
COLOR_ROAD        :: rl.Color{150, 140, 100, 255}
COLOR_SPAWN       :: rl.Color{200, 50, 50, 255}
COLOR_TOWN_CORE   :: rl.Color{50, 150, 200, 255}

COLOR_HOUSE       :: rl.Color{139, 90, 43, 255}
COLOR_GOLD_MINE   :: rl.Color{255, 215, 0, 255}
COLOR_LUMBER_MILL :: rl.Color{34, 139, 34, 255}
COLOR_FARM        :: rl.Color{144, 238, 144, 255}
COLOR_BARRACKS    :: rl.Color{178, 34, 34, 255}
COLOR_ARCHERY     :: rl.Color{210, 105, 30, 255}
COLOR_STABLE      :: rl.Color{139, 69, 19, 255}
COLOR_TOWER_BASIC :: rl.Color{169, 169, 169, 255}
COLOR_TOWER_ADV   :: rl.Color{192, 192, 192, 255}
COLOR_WALL        :: rl.Color{105, 105, 105, 255}
COLOR_RESEARCH    :: rl.Color{138, 43, 226, 255}

COLOR_UNIT        :: rl.Color{0, 100, 200, 255}
COLOR_ENEMY       :: rl.Color{200, 50, 50, 255}
COLOR_HERO_TANK   :: rl.Color{100, 100, 200, 255}
COLOR_HERO_DPS    :: rl.Color{200, 100, 100, 255}
COLOR_HERO_SUPPORT:: rl.Color{100, 200, 100, 255}

// ============================================================================
// RENDERING
// ============================================================================

render_game :: proc(g: ^Game) {
    rl.BeginDrawing()
    rl.ClearBackground(rl.Color{30, 30, 30, 255})
    
    render_grid(g)
    render_buildings(g)
    render_workers(g)
    render_units(g)
    render_enemies(g)
    render_heroes(g)
    render_projectiles(g)
    render_town_core(g)
    render_ui(g)
    render_build_menu(g)
    
    rl.EndDrawing()
}

render_grid :: proc(g: ^Game) {
    // Draw single ground texture stretched across entire grid
    if g_assets.ground_loaded {
        source_rect := rl.Rectangle{
            0, 0,
            f32(g_assets.ground_texture.width),
            f32(g_assets.ground_texture.height),
        }
        dest_rect := rl.Rectangle{
            0, 0,
            f32(GRID_WIDTH * TILE_SIZE),
            f32(GRID_HEIGHT * TILE_SIZE),
        }
        rl.DrawTexturePro(g_assets.ground_texture, source_rect, dest_rect, rl.Vector2{0, 0}, 0, rl.WHITE)
    }
    
    // Second pass: draw special tiles and individual empty tiles that couldn't fit in 2x2
    for x in 0..<GRID_WIDTH {
        for y in 0..<GRID_HEIGHT {
            tile := g.tiles[x][y]
            rect := rl.Rectangle{
                f32(x) * TILE_SIZE,
                f32(y) * TILE_SIZE,
                TILE_SIZE,
                TILE_SIZE,
            }
            
            // Draw non-empty tiles with colors (skip Town_Core since we draw main hall texture)
            if tile != .Empty && tile != .Town_Core {
                color: rl.Color
                switch tile {
                    case .Empty:      color = COLOR_EMPTY
                    case .Blocked:    color = COLOR_BLOCKED
                    case .Road:       color = COLOR_ROAD
                    case .Spawn_Point: color = COLOR_SPAWN
                    case .Town_Core:  color = COLOR_TOWN_CORE
                }
                rl.DrawRectangleRec(rect, color)
            } else if !g_assets.ground_loaded && tile == .Empty {
                // Fallback if textures not loaded
                rl.DrawRectangleRec(rect, COLOR_EMPTY)
            }
            
            // Highlight mouse tile
            if g.mouse_tile.x == i32(x) && g.mouse_tile.y == i32(y) {
                rl.DrawRectangleLinesEx(rect, 2, rl.YELLOW)
            }
        }
    }
}

render_buildings :: proc(g: ^Game) {
    for x in 0..<GRID_WIDTH {
        for y in 0..<GRID_HEIGHT {
            building := g.buildings[x][y]
            if building.type == .None do continue
            
            center_x := f32(x) * TILE_SIZE + TILE_SIZE / 2
            center_y := f32(y) * TILE_SIZE + TILE_SIZE / 2
            
            dest_rect := rl.Rectangle{
                f32(x) * TILE_SIZE,
                f32(y) * TILE_SIZE,
                TILE_SIZE,
                TILE_SIZE,
            }
            
            // Check if we have a texture for this building
            tex: ^rl.Texture2D = nil
            #partial switch building.type {
                case .Gold_Mine:     tex = &g_assets.building_goldmine
                case .Lumber_Mill:   tex = &g_assets.building_lumbermill
                case .Barracks:      tex = &g_assets.building_knight_house
                case .Archery_Range: tex = &g_assets.building_archer_house
            }
            
            // Draw textured building if available
            if tex != nil && tex.id != 0 {
                source_rect := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
                rl.DrawTexturePro(tex^, source_rect, dest_rect, rl.Vector2{0, 0}, 0, rl.WHITE)
            } else {
                // Fallback to colored rectangles for buildings without textures
                color: rl.Color
                switch building.type {
                    case .None:          continue
                    case .House:         color = COLOR_HOUSE
                    case .Gold_Mine:     color = COLOR_GOLD_MINE
                    case .Lumber_Mill:   color = COLOR_LUMBER_MILL
                    case .Farm:          color = COLOR_FARM
                    case .Barracks:      color = COLOR_BARRACKS
                    case .Archery_Range: color = COLOR_ARCHERY
                    case .Stable:        color = COLOR_STABLE
                    case .Basic_Tower:   color = COLOR_TOWER_BASIC
                    case .Advanced_Tower: color = COLOR_TOWER_ADV
                    case .Wall:          color = COLOR_WALL
                    case .Research_Hall: color = COLOR_RESEARCH
                }
                
                // Draw building
                if building.type == .Wall {
                    rl.DrawRectangle(
                        i32(x) * TILE_SIZE + 4,
                        i32(y) * TILE_SIZE + 4,
                        TILE_SIZE - 8,
                        TILE_SIZE - 8,
                        color,
                    )
                } else if building.type == .Basic_Tower || building.type == .Advanced_Tower {
                    rl.DrawCircle(i32(center_x), i32(center_y), TILE_SIZE / 3, color)
                } else {
                    rl.DrawRectangle(
                        i32(x) * TILE_SIZE + 6,
                        i32(y) * TILE_SIZE + 6,
                        TILE_SIZE - 12,
                        TILE_SIZE - 12,
                        color,
                    )
                }
            }
            
            // Draw tower range indicator when hovered
            if (building.type == .Basic_Tower || building.type == .Advanced_Tower) && g.mouse_tile.x == i32(x) && g.mouse_tile.y == i32(y) {
                rl.DrawCircleLines(
                    i32(center_x), i32(center_y),
                    building.attack_range * TILE_SIZE,
                    rl.Color{255, 255, 255, 100},
                )
            }
            
            // Health bar
            if building.health < building.max_health {
                health_pct := f32(building.health) / f32(building.max_health)
                bar_width := TILE_SIZE - 8
                rl.DrawRectangle(
                    i32(x) * TILE_SIZE + 4,
                    i32(y) * TILE_SIZE + 2,
                    i32(bar_width),
                    3,
                    rl.RED,
                )
                rl.DrawRectangle(
                    i32(x) * TILE_SIZE + 4,
                    i32(y) * TILE_SIZE + 2,
                    i32(f32(bar_width) * health_pct),
                    3,
                    rl.GREEN,
                )
            }
        }
    }
}

render_workers :: proc(g: ^Game) {
    for &worker in g.workers {
        if !worker.active do continue
        
        // Worker body color based on type
        body_color: rl.Color
        switch worker.worker_type {
            case .Gold:   body_color = rl.Color{180, 150, 50, 255}   // Golden-brown for miners
            case .Lumber: body_color = rl.Color{90, 140, 90, 255}   // Green-brown for lumberjacks
        }
        rl.DrawCircleV(worker.pos, 5, body_color)
        
        // Draw resource indicator if carrying
        if worker.carrying {
            resource_pos := rl.Vector2{worker.pos.x, worker.pos.y - 7}
            switch worker.worker_type {
                case .Gold:
                    // Gold nugget above worker
                    rl.DrawCircleV(resource_pos, 3, rl.GOLD)
                case .Lumber:
                    // Wood log above worker (small brown rectangle)
                    rl.DrawRectangle(i32(resource_pos.x) - 4, i32(resource_pos.y) - 2, 8, 4, rl.Color{139, 90, 43, 255})
            }
        }
        
        // Direction indicator (small line showing movement)
        if worker.wait_timer <= 0 {
            dir := worker.target_pos - worker.pos
            dist := rl.Vector2Length(dir)
            if dist > 1 {
                dir = rl.Vector2Normalize(dir)
                line_end := worker.pos + dir * 8
                rl.DrawLineV(worker.pos, line_end, rl.Color{200, 200, 200, 100})
            }
        }
    }
}

render_units :: proc(g: ^Game) {
    for &unit in g.units {
        if !unit.active do continue
        
        color := COLOR_UNIT
        size: f32 = 8
        
        switch unit.type {
            case .Infantry: size = 8
            case .Archer:   size = 7
            case .Cavalry:  size = 12
            case .Siege:    size = 14
        }
        
        rl.DrawCircleV(unit.pos, size, color)
        
        // Health bar
        if unit.health < unit.max_health {
            health_pct := f32(unit.health) / f32(unit.max_health)
            rl.DrawRectangle(
                i32(unit.pos.x) - 10,
                i32(unit.pos.y) - i32(size) - 6,
                20,
                3,
                rl.RED,
            )
            rl.DrawRectangle(
                i32(unit.pos.x) - 10,
                i32(unit.pos.y) - i32(size) - 6,
                i32(20 * health_pct),
                3,
                rl.GREEN,
            )
        }
    }
}

render_enemies :: proc(g: ^Game) {
    for &enemy in g.enemies {
        if !enemy.active do continue
        
        color := COLOR_ENEMY
        size: f32 = 8
        
        switch enemy.type {
            case .Basic:    size = 8
            case .Armored:  
                size = 10
                color = rl.Color{150, 50, 50, 255}
            case .Siege:    
                size = 14
                color = rl.Color{100, 50, 50, 255}
            case .Assassin: 
                size = 6
                color = rl.Color{200, 0, 200, 255}
            case .Flyer:    
                size = 8
                color = rl.Color{200, 150, 50, 255}
        }
        
        if enemy.is_flying {
            // Draw flying enemies as triangles
            rl.DrawTriangle(
                rl.Vector2{enemy.pos.x, enemy.pos.y - size},
                rl.Vector2{enemy.pos.x - size, enemy.pos.y + size},
                rl.Vector2{enemy.pos.x + size, enemy.pos.y + size},
                color,
            )
        } else {
            rl.DrawCircleV(enemy.pos, size, color)
        }
        
        // Health bar
        if enemy.health < enemy.max_health {
            health_pct := f32(enemy.health) / f32(enemy.max_health)
            rl.DrawRectangle(
                i32(enemy.pos.x) - 10,
                i32(enemy.pos.y) - i32(size) - 6,
                20,
                3,
                rl.Color{100, 0, 0, 255},
            )
            rl.DrawRectangle(
                i32(enemy.pos.x) - 10,
                i32(enemy.pos.y) - i32(size) - 6,
                i32(20 * health_pct),
                3,
                rl.Color{200, 50, 50, 255},
            )
        }
    }
}

render_heroes :: proc(g: ^Game) {
    for &hero in g.heroes {
        if !hero.active do continue
        
        if !hero.alive {
            // Show respawn timer at spawn location
            spawn_pos := tile_to_world(Vec2i{GRID_WIDTH - 4, GRID_HEIGHT / 2})
            text := fmt.ctprintf("%.0f", hero.respawn_timer)
            rl.DrawText(text, i32(spawn_pos.x) - 10, i32(spawn_pos.y), 16, rl.GRAY)
            continue
        }
        
        color: rl.Color
        switch hero.type {
            case .Tank:    color = COLOR_HERO_TANK
            case .DPS:     color = COLOR_HERO_DPS
            case .Support: color = COLOR_HERO_SUPPORT
        }
        
        // Draw hero as star shape
        size: f32 = 16
        rl.DrawCircleV(hero.pos, size, color)
        rl.DrawCircleV(hero.pos, size - 4, rl.Color{255, 255, 255, 100})
        
        // Level indicator
        level_text := fmt.ctprintf("Lv%d", hero.level)
        rl.DrawText(level_text, i32(hero.pos.x) - 12, i32(hero.pos.y) - 28, 12, rl.WHITE)
        
        // Health bar
        health_pct := f32(hero.health) / f32(hero.max_health)
        rl.DrawRectangle(
            i32(hero.pos.x) - 15,
            i32(hero.pos.y) - i32(size) - 8,
            30,
            4,
            rl.RED,
        )
        rl.DrawRectangle(
            i32(hero.pos.x) - 15,
            i32(hero.pos.y) - i32(size) - 8,
            i32(30 * health_pct),
            4,
            rl.GREEN,
        )
        
        // XP bar
        xp_pct := f32(hero.xp) / f32(hero.xp_to_next)
        rl.DrawRectangle(
            i32(hero.pos.x) - 15,
            i32(hero.pos.y) - i32(size) - 3,
            30,
            2,
            rl.DARKBLUE,
        )
        rl.DrawRectangle(
            i32(hero.pos.x) - 15,
            i32(hero.pos.y) - i32(size) - 3,
            i32(30 * xp_pct),
            2,
            rl.BLUE,
        )
    }
}

render_projectiles :: proc(g: ^Game) {
    for &proj in g.projectiles {
        if !proj.active do continue
        
        color := rl.YELLOW
        if proj.is_aoe {
            color = rl.ORANGE
        }
        
        rl.DrawCircleV(proj.pos, 4, color)
    }
}

render_town_core :: proc(g: ^Game) {
    pos := tile_to_world(g.town_core_pos)
    
    // Draw main hall texture if loaded
    if g_assets.building_main_hall.id != 0 {
        tex := g_assets.building_main_hall
        // Draw main hall spanning 4x4 tiles (twice as big) centered on core position
        source_rect := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
        dest_rect := rl.Rectangle{
            pos.x - TILE_SIZE * 2,
            pos.y - TILE_SIZE * 2,
            TILE_SIZE * 4,
            TILE_SIZE * 4,
        }
        rl.DrawTexturePro(tex, source_rect, dest_rect, rl.Vector2{0, 0}, 0, rl.WHITE)
    } else {
        // Fallback to circles
        rl.DrawCircle(i32(pos.x), i32(pos.y), TILE_SIZE * 2, rl.Color{50, 150, 200, 200})
        rl.DrawCircle(i32(pos.x), i32(pos.y), TILE_SIZE * 2 - 10, rl.Color{100, 200, 255, 200})
    }
    
    // Health bar
    health_pct := f32(g.town_core_health) / f32(g.town_core_max_health)
    bar_width: i32 = 120
    rl.DrawRectangle(
        i32(pos.x) - bar_width / 2,
        i32(pos.y) - TILE_SIZE * 2 - 15,
        bar_width,
        8,
        rl.RED,
    )
    rl.DrawRectangle(
        i32(pos.x) - bar_width / 2,
        i32(pos.y) - TILE_SIZE * 2 - 15,
        i32(f32(bar_width) * health_pct),
        8,
        rl.GREEN,
    )
    
    rl.DrawText("CORE", i32(pos.x) - 20, i32(pos.y) - 8, 16, rl.WHITE)
}

// ============================================================================
// UI RENDERING
// ============================================================================

render_ui :: proc(g: ^Game) {
    ui_x: i32 = GRID_WIDTH * TILE_SIZE + 10
    
    // Background panel
    rl.DrawRectangle(GRID_WIDTH * TILE_SIZE, 0, 300, SCREEN_HEIGHT, rl.Color{40, 40, 40, 255})
    
    // Title
    rl.DrawText("RIGHTWARD HOLD", ui_x, 10, 20, rl.WHITE)
    
    // Game state
    state_text: cstring
    state_color: rl.Color
    switch g.state {
        case .Build_Phase:
            state_text = "BUILD PHASE"
            state_color = rl.GREEN
        case .Wave_Phase:
            state_text = fmt.ctprintf("WAVE %d", g.current_wave.number)
            state_color = rl.RED
        case .Paused:
            state_text = "PAUSED"
            state_color = rl.YELLOW
        case .Game_Over:
            state_text = "GAME OVER"
            state_color = rl.RED
        case .Victory:
            state_text = "VICTORY!"
            state_color = rl.GOLD
    }
    rl.DrawText(state_text, ui_x, 35, 18, state_color)
    
    // Wave countdown
    if g.state == .Build_Phase {
        countdown_text := fmt.ctprintf("Next wave: %.0fs", g.wave_countdown)
        rl.DrawText(countdown_text, ui_x, 55, 14, rl.YELLOW)
    } else if g.state == .Wave_Phase {
        enemies_text := fmt.ctprintf("Enemies: %d", g.enemies_alive)
        rl.DrawText(enemies_text, ui_x, 55, 14, rl.RED)
    }
    
    // Resources
    rl.DrawText("--- RESOURCES ---", ui_x, 85, 14, rl.LIGHTGRAY)
    
    gold_text := fmt.ctprintf("Gold: %d", g.resources.gold)
    rl.DrawText(gold_text, ui_x, 105, 16, rl.GOLD)
    
    wood_text := fmt.ctprintf("Wood: %d", g.resources.wood)
    rl.DrawText(wood_text, ui_x, 125, 16, rl.Color{139, 90, 43, 255})
    
    food_text := fmt.ctprintf("Food: %d", g.resources.food)
    rl.DrawText(food_text, ui_x, 145, 16, rl.GREEN)
    
    supply_text := fmt.ctprintf("Supply: %d / %d", g.resources.supply, g.resources.max_supply)
    rl.DrawText(supply_text, ui_x, 165, 16, rl.SKYBLUE)
    
    // Stats
    rl.DrawText("--- STATS ---", ui_x, 195, 14, rl.LIGHTGRAY)
    
    waves_text := fmt.ctprintf("Waves Survived: %d", g.total_waves_survived)
    rl.DrawText(waves_text, ui_x, 215, 14, rl.WHITE)
    
    kills_text := fmt.ctprintf("Enemies Killed: %d", g.total_enemies_killed)
    rl.DrawText(kills_text, ui_x, 235, 14, rl.WHITE)
    
    core_text := fmt.ctprintf("Core Health: %d/%d", g.town_core_health, g.town_core_max_health)
    rl.DrawText(core_text, ui_x, 255, 14, rl.SKYBLUE)
    
    // Heroes info
    rl.DrawText("--- HEROES ---", ui_x, 285, 14, rl.LIGHTGRAY)
    hero_y: i32 = 305
    for &hero in g.heroes {
        if !hero.active do continue
        
        hero_name: cstring
        switch hero.type {
            case .Tank:    hero_name = "Tank"
            case .DPS:     hero_name = "DPS"
            case .Support: hero_name = "Support"
        }
        
        status: cstring = "ALIVE" if hero.alive else fmt.ctprintf("DEAD (%.0fs)", hero.respawn_timer)
        hero_text := fmt.ctprintf("%s Lv%d - %s", hero_name, hero.level, status)
        rl.DrawText(hero_text, ui_x, hero_y, 12, rl.WHITE)
        hero_y += 20
    }
    
    // Controls
    rl.DrawText("--- CONTROLS ---", ui_x, 400, 14, rl.LIGHTGRAY)
    rl.DrawText("[B] Build Menu", ui_x, 420, 12, rl.WHITE)
    rl.DrawText("[1-4] Train Units", ui_x, 435, 12, rl.WHITE)
    rl.DrawText("[H] Hire Hero", ui_x, 450, 12, rl.WHITE)
    rl.DrawText("[SPACE] Start Wave", ui_x, 465, 12, rl.WHITE)
    rl.DrawText("[ESC] Cancel/Pause", ui_x, 480, 12, rl.WHITE)
    rl.DrawText("[R] Rally Units", ui_x, 495, 12, rl.WHITE)
    
    // Selected building preview
    if g.selected_building != .None {
        rl.DrawText("--- BUILDING ---", ui_x, 530, 14, rl.LIGHTGRAY)
        
        building_name: cstring
        switch g.selected_building {
            case .None:          building_name = ""
            case .House:         building_name = "House (+10 Supply)"
            case .Gold_Mine:     building_name = "Gold Mine"
            case .Lumber_Mill:   building_name = "Lumber Mill"
            case .Farm:          building_name = "Farm"
            case .Barracks:      building_name = "Barracks"
            case .Archery_Range: building_name = "Archery Range"
            case .Stable:        building_name = "Stable"
            case .Basic_Tower:   building_name = "Basic Tower"
            case .Advanced_Tower: building_name = "Advanced Tower"
            case .Wall:          building_name = "Wall"
            case .Research_Hall: building_name = "Research Hall"
        }
        rl.DrawText(building_name, ui_x, 550, 14, rl.YELLOW)
        
        data := BUILDING_DATA[g.selected_building]
        cost_text := fmt.ctprintf("Cost: %dG %dW", data.gold_cost, data.wood_cost)
        rl.DrawText(cost_text, ui_x, 570, 12, rl.WHITE)
        
        rl.DrawText("Click to place", ui_x, 590, 12, rl.GRAY)
    }
    
    // Bottom status bar
    rl.DrawRectangle(0, GRID_HEIGHT * TILE_SIZE, GRID_WIDTH * TILE_SIZE, 100, rl.Color{40, 40, 40, 255})
    
    // Unit training info
    rl.DrawText("TRAIN: [1]Infantry(50g,2s) [2]Archer(75g,3s) [3]Cavalry(150g,5s) [4]Siege(300g,8s)", 
                10, GRID_HEIGHT * TILE_SIZE + 10, 12, rl.WHITE)
    
    // Hero info
    rl.DrawText("HEROES: [H]Tank(500g) [J]DPS(600g) [K]Support(550g) - No supply cost!", 
                10, GRID_HEIGHT * TILE_SIZE + 30, 12, rl.WHITE)
}

render_build_menu :: proc(g: ^Game) {
    if !g.show_build_menu do return
    
    menu_x: i32 = 200
    menu_y: i32 = 150
    menu_width: i32 = 350
    menu_height: i32 = 400
    
    // Background
    rl.DrawRectangle(menu_x - 5, menu_y - 5, menu_width + 10, menu_height + 10, rl.BLACK)
    rl.DrawRectangle(menu_x, menu_y, menu_width, menu_height, rl.Color{50, 50, 50, 255})
    
    rl.DrawText("BUILD MENU", menu_x + 120, menu_y + 10, 20, rl.WHITE)
    rl.DrawText("Press number to select, ESC to close", menu_x + 40, menu_y + 35, 12, rl.GRAY)
    
    items := []struct{key: cstring, building: Building_Type, name: cstring}{
        {"[1]", .House, "House (+10 Supply)"},
        {"[2]", .Gold_Mine, "Gold Mine (needs ore)"},
        {"[3]", .Lumber_Mill, "Lumber Mill"},
        {"[4]", .Farm, "Farm"},
        {"[5]", .Barracks, "Barracks (train Infantry)"},
        {"[6]", .Archery_Range, "Archery Range (train Archers)"},
        {"[7]", .Stable, "Stable (train Cavalry)"},
        {"[8]", .Basic_Tower, "Basic Tower"},
        {"[9]", .Advanced_Tower, "Advanced Tower (AoE)"},
        {"[0]", .Wall, "Wall"},
        {"[-]", .Research_Hall, "Research Hall"},
    }
    
    y := menu_y + 60
    for item in items {
        data := BUILDING_DATA[item.building]
        
        // Check if can afford
        can_afford := g.resources.gold >= data.gold_cost && g.resources.wood >= data.wood_cost
        text_color := rl.WHITE if can_afford else rl.DARKGRAY
        
        text := fmt.ctprintf("%s %s - %dG %dW", item.key, item.name, data.gold_cost, data.wood_cost)
        rl.DrawText(text, menu_x + 10, y, 14, text_color)
        y += 28
    }
}

// ============================================================================
// INPUT HANDLING
// ============================================================================

handle_input :: proc(g: ^Game) {
    // Update mouse tile position
    mouse_pos := rl.GetMousePosition()
    g.mouse_tile = world_to_tile(mouse_pos)
    
    // ESC - Cancel selection or toggle pause
    if rl.IsKeyPressed(.ESCAPE) {
        if g.show_build_menu {
            g.show_build_menu = false
        } else if g.selected_building != .None {
            g.selected_building = .None
        } else if g.state == .Wave_Phase {
            g.state = .Paused
        } else if g.state == .Paused {
            g.state = .Wave_Phase
        }
    }
    
    // B - Toggle build menu
    if rl.IsKeyPressed(.B) {
        g.show_build_menu = !g.show_build_menu
    }
    
    // Build menu selections
    if g.show_build_menu {
        if rl.IsKeyPressed(.ONE)   { g.selected_building = .House; g.show_build_menu = false }
        if rl.IsKeyPressed(.TWO)   { g.selected_building = .Gold_Mine; g.show_build_menu = false }
        if rl.IsKeyPressed(.THREE) { g.selected_building = .Lumber_Mill; g.show_build_menu = false }
        if rl.IsKeyPressed(.FOUR)  { g.selected_building = .Farm; g.show_build_menu = false }
        if rl.IsKeyPressed(.FIVE)  { g.selected_building = .Barracks; g.show_build_menu = false }
        if rl.IsKeyPressed(.SIX)   { g.selected_building = .Archery_Range; g.show_build_menu = false }
        if rl.IsKeyPressed(.SEVEN) { g.selected_building = .Stable; g.show_build_menu = false }
        if rl.IsKeyPressed(.EIGHT) { g.selected_building = .Basic_Tower; g.show_build_menu = false }
        if rl.IsKeyPressed(.NINE)  { g.selected_building = .Advanced_Tower; g.show_build_menu = false }
        if rl.IsKeyPressed(.ZERO)  { g.selected_building = .Wall; g.show_build_menu = false }
        if rl.IsKeyPressed(.MINUS) { g.selected_building = .Research_Hall; g.show_build_menu = false }
    } else {
        // Unit training (when not in build menu)
        if rl.IsKeyPressed(.ONE) {
            // Find barracks and spawn infantry near it
            spawn_unit_from_building(g, .Barracks, .Infantry)
        }
        if rl.IsKeyPressed(.TWO) {
            spawn_unit_from_building(g, .Archery_Range, .Archer)
        }
        if rl.IsKeyPressed(.THREE) {
            spawn_unit_from_building(g, .Stable, .Cavalry)
        }
        if rl.IsKeyPressed(.FOUR) {
            spawn_unit_from_building(g, .Barracks, .Siege)
        }
    }
    
    // Hero training
    if rl.IsKeyPressed(.H) {
        spawn_hero(g, .Tank)
    }
    if rl.IsKeyPressed(.J) {
        spawn_hero(g, .DPS)
    }
    if rl.IsKeyPressed(.K) {
        spawn_hero(g, .Support)
    }
    
    // SPACE - Start wave
    if rl.IsKeyPressed(.SPACE) && g.state == .Build_Phase {
        start_wave(g)
    }
    
    // R - Rally units to mouse position
    if rl.IsKeyPressed(.R) && is_valid_tile(g.mouse_tile.x, g.mouse_tile.y) {
        rally_pos := tile_to_world(g.mouse_tile)
        for &unit in g.units {
            if unit.active {
                unit.target_pos = rally_pos
            }
        }
        for &hero in g.heroes {
            if hero.active && hero.alive {
                hero.target_pos = rally_pos
            }
        }
    }
    
    // Mouse click - Place building
    if rl.IsMouseButtonPressed(.LEFT) {
        if g.selected_building != .None {
            if is_valid_tile(g.mouse_tile.x, g.mouse_tile.y) {
                if place_building(g, g.mouse_tile.x, g.mouse_tile.y, g.selected_building) {
                    // Keep selected for multiple placement (shift behavior)
                    if !rl.IsKeyDown(.LEFT_SHIFT) {
                        g.selected_building = .None
                    }
                }
            }
        }
    }
    
    // Right click - Cancel selection
    if rl.IsMouseButtonPressed(.RIGHT) {
        g.selected_building = .None
    }
}

spawn_unit_from_building :: proc(g: ^Game, building_type: Building_Type, unit_type: Unit_Type) {
    // Find a building of the required type
    for x in 0..<GRID_WIDTH {
        for y in 0..<GRID_HEIGHT {
            if g.buildings[x][y].type == building_type {
                spawn_pos := tile_to_world(Vec2i{i32(x), i32(y)})
                spawn_pos.x += TILE_SIZE  // Spawn to the right of building
                spawn_unit(g, unit_type, spawn_pos)
                return
            }
        }
    }
}
