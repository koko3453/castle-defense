package game

import rl "vendor:raylib"
import "core:math"
import "core:math/rand"

// ============================================================================
// GAME STATE
// ============================================================================

Game :: struct {
    state:      Game_State,
    
    // Grid
    tiles:      [GRID_WIDTH][GRID_HEIGHT]Tile_Type,
    buildings:  [GRID_WIDTH][GRID_HEIGHT]Building,
    
    // Resources
    resources:  Resources,
    
    // Entities
    units:      [MAX_UNITS]Unit,
    enemies:    [MAX_ENEMIES]Enemy,
    heroes:     [MAX_HEROES]Hero,
    projectiles: [MAX_PROJECTILES]Projectile,
    workers:    [MAX_WORKERS]Worker,
    
    // Wave system
    current_wave: Wave,
    wave_countdown: f32,
    enemies_alive: i32,
    
    // Research
    researched: [Research_Type]bool,
    
    // UI State
    selected_building: Building_Type,
    selected_tile: Vec2i,
    mouse_tile: Vec2i,
    show_build_menu: bool,
    
    // Town core
    town_core_health: i32,
    town_core_max_health: i32,
    town_core_pos: Vec2i,
    
    // Game stats
    total_waves_survived: i32,
    total_enemies_killed: i32,
    
    // Food upkeep
    food_timer: f32,
    
    // Camera/scroll
    camera_offset: rl.Vector2,
}

// ============================================================================
// INITIALIZATION
// ============================================================================

init_game :: proc() -> Game {
    g: Game
    
    // Initialize game state
    g.state = .Build_Phase
    
    // Starting resources
    g.resources = Resources {
        gold = 300,
        wood = 200,
        food = 50,
        supply = 0,
        max_supply = 0,
    }
    
    // Initialize grid
    init_grid(&g)
    
    // Town core
    g.town_core_pos = Vec2i{GRID_WIDTH - 2, GRID_HEIGHT / 2}
    g.town_core_health = 1000
    g.town_core_max_health = 1000
    
    // First wave setup
    g.wave_countdown = 60.0  // 60 seconds to prepare
    g.current_wave.number = 0
    
    // UI
    g.selected_building = .None
    g.selected_tile = Vec2i{-1, -1}
    g.show_build_menu = false
    
    return g
}

init_grid :: proc(g: ^Game) {
    // Clear all tiles
    for x in 0..<GRID_WIDTH {
        for y in 0..<GRID_HEIGHT {
            g.tiles[x][y] = .Empty
            g.buildings[x][y] = Building{}
        }
    }
    
    // Set spawn points on left edge
    for y in 2..<GRID_HEIGHT-2 {
        g.tiles[0][y] = .Spawn_Point
    }
    
    // Set town core area on right edge
    core_y := GRID_HEIGHT / 2
    g.tiles[GRID_WIDTH-2][core_y] = .Town_Core
    g.tiles[GRID_WIDTH-2][core_y-1] = .Town_Core
    g.tiles[GRID_WIDTH-2][core_y+1] = .Town_Core
    g.tiles[GRID_WIDTH-1][core_y] = .Town_Core
    g.tiles[GRID_WIDTH-1][core_y-1] = .Town_Core
    g.tiles[GRID_WIDTH-1][core_y+1] = .Town_Core
    
    // Add some blocked tiles (mountains, water)
    blocked_positions := []Vec2i {
        {5, 2}, {5, 3}, {6, 2},
        {10, 10}, {10, 11}, {11, 11},
        {15, 5}, {15, 6}, {16, 5},
        {8, 7}, {9, 7},
        {18, 9}, {18, 10},
    }
    
    for pos in blocked_positions {
        if pos.x >= 0 && pos.x < GRID_WIDTH && pos.y >= 0 && pos.y < GRID_HEIGHT {
            g.tiles[pos.x][pos.y] = .Blocked
        }
    }
}

// ============================================================================
// GRID / TILE HELPERS
// ============================================================================

tile_to_world :: proc(tile: Vec2i) -> rl.Vector2 {
    return rl.Vector2 {
        f32(tile.x) * TILE_SIZE + TILE_SIZE / 2,
        f32(tile.y) * TILE_SIZE + TILE_SIZE / 2,
    }
}

world_to_tile :: proc(pos: rl.Vector2) -> Vec2i {
    return Vec2i {
        i32(pos.x / TILE_SIZE),
        i32(pos.y / TILE_SIZE),
    }
}

is_valid_tile :: proc(x, y: i32) -> bool {
    return x >= 0 && x < GRID_WIDTH && y >= 0 && y < GRID_HEIGHT
}

can_build_at :: proc(g: ^Game, x, y: i32, building_type: Building_Type) -> bool {
    if !is_valid_tile(x, y) do return false
    
    tile := g.tiles[x][y]
    
    // Can only build on empty tiles
    if tile != .Empty do return false
    
    // Check if already has building
    if g.buildings[x][y].type != .None do return false
    
    // Gold mines need to be near blocked tiles (representing ore deposits)
    if building_type == .Gold_Mine {
        has_adjacent_blocked := false
        for dx in -1..=1 {
            for dy in -1..=1 {
                nx, ny := x + i32(dx), y + i32(dy)
                if is_valid_tile(nx, ny) && g.tiles[nx][ny] == .Blocked {
                    has_adjacent_blocked = true
                    break
                }
            }
        }
        if !has_adjacent_blocked do return false
    }
    
    return true
}

// ============================================================================
// BUILDING SYSTEM
// ============================================================================

place_building :: proc(g: ^Game, x, y: i32, building_type: Building_Type) -> bool {
    if !can_build_at(g, x, y, building_type) do return false
    
    data := BUILDING_DATA[building_type]
    
    // Check resources
    if g.resources.gold < data.gold_cost do return false
    if g.resources.wood < data.wood_cost do return false
    
    // Deduct resources
    g.resources.gold -= data.gold_cost
    g.resources.wood -= data.wood_cost
    
    // Create building
    g.buildings[x][y] = Building {
        type = building_type,
        health = data.health,
        max_health = data.health,
        pos = Vec2i{x, y},
        attack_range = data.attack_range,
        attack_damage = data.attack_damage,
        attack_cooldown = data.attack_cooldown,
    }
    
    // Update supply if house
    if building_type == .House {
        g.resources.max_supply += data.supply_add
    }
    
    // Spawn workers for resource buildings
    if building_type == .Gold_Mine {
        spawn_workers_for_building(g, Vec2i{x, y}, .Gold)
    } else if building_type == .Lumber_Mill {
        spawn_workers_for_building(g, Vec2i{x, y}, .Lumber)
    }
    
    return true
}

destroy_building :: proc(g: ^Game, x, y: i32) {
    building := &g.buildings[x][y]
    
    if building.type == .House {
        g.resources.max_supply -= BUILDING_DATA[.House].supply_add
    }
    
    // Remove workers if resource building is destroyed
    if building.type == .Gold_Mine || building.type == .Lumber_Mill {
        remove_workers_for_building(g, Vec2i{x, y})
    }
    
    building^ = Building{}
}

// ============================================================================
// WORKER SYSTEM (Visual resource gatherers)
// ============================================================================

spawn_workers_for_building :: proc(g: ^Game, building_pos: Vec2i, worker_type: Worker_Type) {
    // Spawn 3 workers per resource building
    workers_to_spawn := 3
    building_world_pos := tile_to_world(building_pos)
    town_pos := tile_to_world(g.town_core_pos)
    
    for &worker in g.workers {
        if workers_to_spawn <= 0 do break
        if !worker.active {
            // Stagger their starting positions along the path
            t := f32(workers_to_spawn) / 3.0
            start_pos := rl.Vector2 {
                building_world_pos.x + (town_pos.x - building_world_pos.x) * t,
                building_world_pos.y + (town_pos.y - building_world_pos.y) * t,
            }
            
            worker = Worker {
                active = true,
                pos = start_pos,
                target_pos = building_world_pos,
                speed = 40.0,  // Slower than combat units
                going_to_work = true,
                work_pos = building_pos,
                worker_type = worker_type,
                carrying = false,
                wait_timer = 0,
            }
            workers_to_spawn -= 1
        }
    }
}

remove_workers_for_building :: proc(g: ^Game, building_pos: Vec2i) {
    for &worker in g.workers {
        if worker.active && worker.work_pos.x == building_pos.x && worker.work_pos.y == building_pos.y {
            worker.active = false
        }
    }
}

update_workers :: proc(g: ^Game, dt: f32) {
    town_pos := tile_to_world(g.town_core_pos)
    
    for &worker in g.workers {
        if !worker.active do continue
        
        // Check if the building still exists
        work_building := g.buildings[worker.work_pos.x][worker.work_pos.y]
        expected_type: Building_Type = .Gold_Mine if worker.worker_type == .Gold else .Lumber_Mill
        if work_building.type != expected_type {
            worker.active = false
            continue
        }
        
        // Wait at destination
        if worker.wait_timer > 0 {
            worker.wait_timer -= dt
            continue
        }
        
        // Move towards target
        dir := worker.target_pos - worker.pos
        dist := rl.Vector2Length(dir)
        
        if dist > 5 {  // Not at destination yet
            dir = rl.Vector2Normalize(dir)
            worker.pos += dir * worker.speed * dt
        } else {
            // Reached destination - switch direction
            if worker.going_to_work {
                // At the work site - pick up resource
                worker.carrying = true
                worker.going_to_work = false
                worker.target_pos = town_pos
                worker.wait_timer = 0.5  // Short pause at work site
            } else {
                // At town hall - drop off resource
                worker.carrying = false
                worker.going_to_work = true
                worker.target_pos = tile_to_world(worker.work_pos)
                worker.wait_timer = 0.5  // Short pause at town
            }
        }
    }
}

update_buildings :: proc(g: ^Game, dt: f32) {
    for x in 0..<GRID_WIDTH {
        for y in 0..<GRID_HEIGHT {
            building := &g.buildings[x][y]
            if building.type == .None do continue
            
            data := BUILDING_DATA[building.type]
            
            // Production buildings
            if data.produces_gold > 0 || data.produces_wood > 0 || data.produces_food > 0 {
                building.production_progress += dt
                if building.production_progress >= data.production_time {
                    building.production_progress = 0
                    g.resources.gold += data.produces_gold
                    g.resources.wood += data.produces_wood
                    g.resources.food += data.produces_food
                }
            }
            
            // Tower combat
            if building.type == .Basic_Tower || building.type == .Advanced_Tower {
                building.last_attack += dt
                
                if building.last_attack >= building.attack_cooldown {
                    // Find closest enemy in range
                    tower_pos := tile_to_world(Vec2i{i32(x), i32(y)})
                    range_pixels := building.attack_range * TILE_SIZE
                    
                    closest_enemy: ^Enemy = nil
                    closest_dist: f32 = range_pixels + 1
                    
                    for &enemy in g.enemies {
                        if !enemy.active do continue
                        
                        dist := rl.Vector2Length(enemy.pos - tower_pos)
                        if dist < range_pixels && dist < closest_dist {
                            closest_dist = dist
                            closest_enemy = &enemy
                        }
                    }
                    
                    if closest_enemy != nil {
                        // Spawn projectile
                        spawn_projectile(g, tower_pos, closest_enemy.pos, building.attack_damage, 
                                        building.type == .Advanced_Tower)
                        building.last_attack = 0
                    }
                }
            }
        }
    }
}

// ============================================================================
// UNIT SYSTEM
// ============================================================================

spawn_unit :: proc(g: ^Game, unit_type: Unit_Type, pos: rl.Vector2) -> bool {
    data := UNIT_DATA[unit_type]
    
    // Check supply
    if g.resources.supply + data.supply_cost > g.resources.max_supply do return false
    
    // Check gold
    if g.resources.gold < data.gold_cost do return false
    
    // Find free slot
    for &unit in g.units {
        if !unit.active {
            unit = Unit {
                type = unit_type,
                active = true,
                health = data.health,
                max_health = data.health,
                pos = pos,
                target_pos = pos,
                speed = data.speed,
                damage = data.damage,
                attack_range = data.attack_range * TILE_SIZE,
                attack_cooldown = data.attack_cooldown,
                supply_cost = data.supply_cost,
            }
            
            g.resources.gold -= data.gold_cost
            g.resources.supply += data.supply_cost
            return true
        }
    }
    
    return false
}

update_units :: proc(g: ^Game, dt: f32) {
    for &unit in g.units {
        if !unit.active do continue
        
        // Find closest enemy
        closest_enemy: ^Enemy = nil
        closest_dist: f32 = 9999999
        
        for &enemy in g.enemies {
            if !enemy.active do continue
            
            dist := rl.Vector2Length(enemy.pos - unit.pos)
            if dist < closest_dist {
                closest_dist = dist
                closest_enemy = &enemy
            }
        }
        
        if closest_enemy != nil {
            if closest_dist <= unit.attack_range {
                // Attack
                unit.last_attack += dt
                if unit.last_attack >= unit.attack_cooldown {
                    damage := max(1, unit.damage - closest_enemy.armor)
                    closest_enemy.health -= damage
                    unit.last_attack = 0
                    
                    if closest_enemy.health <= 0 {
                        closest_enemy.active = false
                        g.enemies_alive -= 1
                        g.total_enemies_killed += 1
                    }
                }
            } else {
                // Move toward enemy
                dir := rl.Vector2Normalize(closest_enemy.pos - unit.pos)
                unit.pos += dir * unit.speed * dt
            }
        }
        
        // Keep in bounds
        unit.pos.x = clamp(unit.pos.x, 0, f32(GRID_WIDTH * TILE_SIZE))
        unit.pos.y = clamp(unit.pos.y, 0, f32(GRID_HEIGHT * TILE_SIZE))
    }
}

kill_unit :: proc(g: ^Game, unit: ^Unit) {
    g.resources.supply -= unit.supply_cost
    unit.active = false
}

// ============================================================================
// ENEMY SYSTEM
// ============================================================================

spawn_enemy :: proc(g: ^Game, enemy_type: Enemy_Type) {
    data := ENEMY_DATA[enemy_type]
    
    // Find spawn point
    spawn_y := rand.int31_max(GRID_HEIGHT - 4) + 2
    spawn_pos := tile_to_world(Vec2i{0, spawn_y})
    
    for &enemy in g.enemies {
        if !enemy.active {
            enemy = Enemy {
                type = enemy_type,
                active = true,
                health = data.health,
                max_health = data.health,
                pos = spawn_pos,
                speed = data.speed,
                damage = data.damage,
                attack_range = data.attack_range * TILE_SIZE,
                attack_cooldown = data.attack_cooldown,
                armor = data.armor,
                is_flying = data.is_flying,
            }
            
            g.enemies_alive += 1
            return
        }
    }
}

update_enemies :: proc(g: ^Game, dt: f32) {
    town_core_world := tile_to_world(g.town_core_pos)
    
    for &enemy in g.enemies {
        if !enemy.active do continue
        
        // Assassins target economy buildings
        if enemy.type == .Assassin {
            // Find closest economy building
            closest_building: ^Building = nil
            closest_dist: f32 = 9999999
            
            for x in 0..<GRID_WIDTH {
                for y in 0..<GRID_HEIGHT {
                    b := &g.buildings[x][y]
                    if b.type == .Gold_Mine || b.type == .Lumber_Mill || b.type == .Farm {
                        pos := tile_to_world(Vec2i{i32(x), i32(y)})
                        dist := rl.Vector2Length(pos - enemy.pos)
                        if dist < closest_dist {
                            closest_dist = dist
                            closest_building = b
                        }
                    }
                }
            }
            
            if closest_building != nil && closest_dist > enemy.attack_range {
                target := tile_to_world(closest_building.pos)
                dir := rl.Vector2Normalize(target - enemy.pos)
                enemy.pos += dir * enemy.speed * dt
                continue
            } else if closest_building != nil {
                // Attack building
                enemy.last_attack += dt
                if enemy.last_attack >= enemy.attack_cooldown {
                    closest_building.health -= enemy.damage
                    enemy.last_attack = 0
                    
                    if closest_building.health <= 0 {
                        destroy_building(g, closest_building.pos.x, closest_building.pos.y)
                    }
                }
                continue
            }
        }
        
        // Siege enemies target walls/towers
        if enemy.type == .Siege {
            // Find closest wall or tower
            for x in 0..<GRID_WIDTH {
                for y in 0..<GRID_HEIGHT {
                    b := &g.buildings[x][y]
                    if b.type == .Wall || b.type == .Basic_Tower || b.type == .Advanced_Tower {
                        pos := tile_to_world(Vec2i{i32(x), i32(y)})
                        dist := rl.Vector2Length(pos - enemy.pos)
                        
                        if dist <= enemy.attack_range {
                            enemy.last_attack += dt
                            if enemy.last_attack >= enemy.attack_cooldown {
                                b.health -= enemy.damage
                                enemy.last_attack = 0
                                
                                if b.health <= 0 {
                                    destroy_building(g, i32(x), i32(y))
                                }
                            }
                            continue
                        }
                    }
                }
            }
        }
        
        // Check for collision with units (combat)
        for &unit in g.units {
            if !unit.active do continue
            
            dist := rl.Vector2Length(unit.pos - enemy.pos)
            if dist <= enemy.attack_range {
                enemy.last_attack += dt
                if enemy.last_attack >= enemy.attack_cooldown {
                    unit.health -= enemy.damage
                    enemy.last_attack = 0
                    
                    if unit.health <= 0 {
                        kill_unit(g, &unit)
                    }
                }
            }
        }
        
        // Check for collision with heroes
        for &hero in g.heroes {
            if !hero.active || !hero.alive do continue
            
            dist := rl.Vector2Length(hero.pos - enemy.pos)
            if dist <= enemy.attack_range {
                enemy.last_attack += dt
                if enemy.last_attack >= enemy.attack_cooldown {
                    hero.health -= enemy.damage
                    enemy.last_attack = 0
                    
                    if hero.health <= 0 {
                        hero.alive = false
                        hero.respawn_timer = 30.0  // 30 second respawn
                    }
                }
            }
        }
        
        // Move toward town core
        // Flyers can ignore walls
        if enemy.is_flying || !is_blocked_by_wall(g, enemy.pos, town_core_world) {
            dir := rl.Vector2Normalize(town_core_world - enemy.pos)
            enemy.pos += dir * enemy.speed * dt
        } else {
            // Pathfind around walls (simplified - just try to go around)
            // Try moving perpendicular
            dir := rl.Vector2Normalize(town_core_world - enemy.pos)
            perp := rl.Vector2{dir.y, -dir.x}
            enemy.pos += perp * enemy.speed * dt * 0.5
            enemy.pos += dir * enemy.speed * dt * 0.5
        }
        
        // Check if reached town core
        if rl.Vector2Length(town_core_world - enemy.pos) < TILE_SIZE {
            g.town_core_health -= enemy.damage
            enemy.active = false
            g.enemies_alive -= 1
            
            if g.town_core_health <= 0 {
                g.state = .Game_Over
            }
        }
    }
}

is_blocked_by_wall :: proc(g: ^Game, from, to: rl.Vector2) -> bool {
    // Simple line check for walls
    dir := to - from
    dist := rl.Vector2Length(dir)
    steps := int(dist / (TILE_SIZE / 2))
    
    for i in 0..=steps {
        t := f32(i) / f32(max(steps, 1))
        check_pos := from + dir * t
        tile := world_to_tile(check_pos)
        
        if is_valid_tile(tile.x, tile.y) {
            if g.buildings[tile.x][tile.y].type == .Wall {
                return true
            }
        }
    }
    
    return false
}

// ============================================================================
// HERO SYSTEM
// ============================================================================

spawn_hero :: proc(g: ^Game, hero_type: Hero_Type) -> bool {
    data := HERO_DATA[hero_type]
    
    // Check gold
    if g.resources.gold < data.gold_cost do return false
    
    // Find free slot
    for &hero in g.heroes {
        if !hero.active {
            spawn_pos := tile_to_world(Vec2i{GRID_WIDTH - 4, GRID_HEIGHT / 2})
            
            hero = Hero {
                type = hero_type,
                active = true,
                alive = true,
                health = data.health,
                max_health = data.health,
                pos = spawn_pos,
                target_pos = spawn_pos,
                speed = data.speed,
                damage = data.damage,
                attack_range = data.attack_range * TILE_SIZE,
                attack_cooldown = data.attack_cooldown,
                level = 1,
                xp = 0,
                xp_to_next = 100,
            }
            
            g.resources.gold -= data.gold_cost
            return true
        }
    }
    
    return false
}

update_heroes :: proc(g: ^Game, dt: f32) {
    for &hero in g.heroes {
        if !hero.active do continue
        
        // Respawn timer
        if !hero.alive {
            hero.respawn_timer -= dt
            if hero.respawn_timer <= 0 {
                hero.alive = true
                hero.health = hero.max_health
                hero.pos = tile_to_world(Vec2i{GRID_WIDTH - 4, GRID_HEIGHT / 2})
            }
            continue
        }
        
        // Find closest enemy
        closest_enemy: ^Enemy = nil
        closest_dist: f32 = 9999999
        
        for &enemy in g.enemies {
            if !enemy.active do continue
            
            dist := rl.Vector2Length(enemy.pos - hero.pos)
            if dist < closest_dist {
                closest_dist = dist
                closest_enemy = &enemy
            }
        }
        
        if closest_enemy != nil {
            if closest_dist <= hero.attack_range {
                // Attack
                hero.last_attack += dt
                if hero.last_attack >= hero.attack_cooldown {
                    // Heroes do extra damage based on level
                    damage := hero.damage + (hero.level - 1) * 5
                    damage = max(1, damage - closest_enemy.armor)
                    closest_enemy.health -= damage
                    hero.last_attack = 0
                    
                    if closest_enemy.health <= 0 {
                        closest_enemy.active = false
                        g.enemies_alive -= 1
                        g.total_enemies_killed += 1
                        
                        // XP gain
                        hero.xp += 20
                        if hero.xp >= hero.xp_to_next {
                            hero.level += 1
                            hero.xp = 0
                            hero.xp_to_next = hero.level * 100
                            hero.max_health += 50
                            hero.health = hero.max_health
                            hero.damage += 10
                        }
                    }
                }
            } else {
                // Move toward enemy
                dir := rl.Vector2Normalize(closest_enemy.pos - hero.pos)
                hero.pos += dir * hero.speed * dt
            }
        }
        
        // Support hero special ability - heal nearby allies
        if hero.type == .Support {
            hero.ability_cooldown -= dt
            if hero.ability_cooldown <= 0 {
                // Heal all units in range
                for &unit in g.units {
                    if !unit.active do continue
                    dist := rl.Vector2Length(unit.pos - hero.pos)
                    if dist <= hero.attack_range * 2 {
                        unit.health = min(unit.health + 10, unit.max_health)
                    }
                }
                // Heal other heroes
                for &other_hero in g.heroes {
                    if !other_hero.active || !other_hero.alive do continue
                    dist := rl.Vector2Length(other_hero.pos - hero.pos)
                    if dist <= hero.attack_range * 2 {
                        other_hero.health = min(other_hero.health + 20, other_hero.max_health)
                    }
                }
                hero.ability_cooldown = 5.0
            }
        }
        
        // Tank hero special ability - taunt nearby enemies
        if hero.type == .Tank {
            // Tank has damage reduction
            // (handled in enemy attack calculations)
        }
        
        // Keep in bounds
        hero.pos.x = clamp(hero.pos.x, 0, f32(GRID_WIDTH * TILE_SIZE))
        hero.pos.y = clamp(hero.pos.y, 0, f32(GRID_HEIGHT * TILE_SIZE))
    }
}

// ============================================================================
// PROJECTILE SYSTEM
// ============================================================================

spawn_projectile :: proc(g: ^Game, from, to: rl.Vector2, damage: i32, is_aoe: bool) {
    for &proj in g.projectiles {
        if !proj.active {
            proj = Projectile {
                active = true,
                pos = from,
                target = to,
                speed = 300.0,
                damage = damage,
                is_aoe = is_aoe,
                aoe_radius = 2.0 * TILE_SIZE if is_aoe else 0,
            }
            return
        }
    }
}

update_projectiles :: proc(g: ^Game, dt: f32) {
    for &proj in g.projectiles {
        if !proj.active do continue
        
        dir := rl.Vector2Normalize(proj.target - proj.pos)
        proj.pos += dir * proj.speed * dt
        
        // Check if reached target
        if rl.Vector2Length(proj.target - proj.pos) < 10 {
            // Deal damage
            if proj.is_aoe {
                for &enemy in g.enemies {
                    if !enemy.active do continue
                    dist := rl.Vector2Length(enemy.pos - proj.pos)
                    if dist <= proj.aoe_radius {
                        enemy.health -= proj.damage
                        if enemy.health <= 0 {
                            enemy.active = false
                            g.enemies_alive -= 1
                            g.total_enemies_killed += 1
                        }
                    }
                }
            } else {
                // Single target - find closest enemy to impact point
                for &enemy in g.enemies {
                    if !enemy.active do continue
                    dist := rl.Vector2Length(enemy.pos - proj.pos)
                    if dist <= TILE_SIZE {
                        enemy.health -= proj.damage
                        if enemy.health <= 0 {
                            enemy.active = false
                            g.enemies_alive -= 1
                            g.total_enemies_killed += 1
                        }
                        break
                    }
                }
            }
            
            proj.active = false
        }
    }
}

// ============================================================================
// WAVE SYSTEM
// ============================================================================

start_wave :: proc(g: ^Game) {
    g.current_wave.number += 1
    g.state = .Wave_Phase
    
    // Calculate enemies for this wave
    base_enemies := 10 + g.current_wave.number * 5
    g.current_wave.enemies_to_spawn = i32(base_enemies)
    g.current_wave.enemies_spawned = 0
    g.current_wave.spawn_timer = 0
    g.current_wave.spawn_delay = max(0.5, 2.0 - f32(g.current_wave.number) * 0.1)
    
    // Determine enemy types for this wave
    g.current_wave.num_types = 1
    g.current_wave.enemy_types[0] = .Basic
    
    if g.current_wave.number >= 3 {
        g.current_wave.num_types = 2
        g.current_wave.enemy_types[1] = .Armored
    }
    if g.current_wave.number >= 5 {
        g.current_wave.num_types = 3
        g.current_wave.enemy_types[2] = .Assassin
    }
    if g.current_wave.number >= 7 {
        g.current_wave.num_types = 4
        g.current_wave.enemy_types[3] = .Siege
    }
    if g.current_wave.number >= 10 {
        g.current_wave.num_types = 5
        g.current_wave.enemy_types[4] = .Flyer
    }
}

update_wave :: proc(g: ^Game, dt: f32) {
    if g.state != .Wave_Phase do return
    
    // Spawn enemies
    if g.current_wave.enemies_spawned < g.current_wave.enemies_to_spawn {
        g.current_wave.spawn_timer += dt
        
        if g.current_wave.spawn_timer >= g.current_wave.spawn_delay {
            g.current_wave.spawn_timer = 0
            
            // Pick random enemy type from available types
            type_index := rand.int31_max(g.current_wave.num_types)
            spawn_enemy(g, g.current_wave.enemy_types[type_index])
            g.current_wave.enemies_spawned += 1
        }
    }
    
    // Check if wave is complete
    if g.current_wave.enemies_spawned >= g.current_wave.enemies_to_spawn && g.enemies_alive <= 0 {
        g.state = .Build_Phase
        g.wave_countdown = 45.0  // Time until next wave
        g.total_waves_survived = g.current_wave.number
        
        // Victory condition: survive 20 waves
        if g.current_wave.number >= 20 {
            g.state = .Victory
        }
    }
}

// ============================================================================
// FOOD UPKEEP
// ============================================================================

update_food_upkeep :: proc(g: ^Game, dt: f32) {
    g.food_timer += dt
    
    if g.food_timer >= 10.0 {  // Every 10 seconds
        g.food_timer = 0
        
        // Calculate food upkeep based on army size
        food_needed := g.resources.supply / 5  // 1 food per 5 supply
        
        if g.resources.food >= food_needed {
            g.resources.food -= food_needed
        } else {
            // Starving! Units take damage
            for &unit in g.units {
                if !unit.active do continue
                unit.health -= 10
                if unit.health <= 0 {
                    kill_unit(g, &unit)
                }
            }
        }
    }
}
