package game

import rl "vendor:raylib"

// ============================================================================
// CONSTANTS
// ============================================================================

GRID_WIDTH :: 24
GRID_HEIGHT :: 14
TILE_SIZE :: 48
SCREEN_WIDTH :: GRID_WIDTH * TILE_SIZE + 300  // Extra space for UI
SCREEN_HEIGHT :: GRID_HEIGHT * TILE_SIZE + 100

MAX_UNITS :: 200
MAX_ENEMIES :: 300
MAX_HEROES :: 3
MAX_PROJECTILES :: 500
MAX_WORKERS :: 50

// ============================================================================
// ENUMS
// ============================================================================

Tile_Type :: enum {
    Empty,
    Blocked,      // Mountain, water, ruins
    Road,
    Town_Core,
    Spawn_Point,
}

Building_Type :: enum {
    None,
    // Housing
    House,
    // Economy
    Gold_Mine,
    Lumber_Mill,
    Farm,
    // Military Production
    Barracks,
    Archery_Range,
    Stable,
    // Defense
    Basic_Tower,
    Advanced_Tower,
    Wall,
    // Research
    Research_Hall,
}

Unit_Type :: enum {
    Infantry,
    Archer,
    Cavalry,
    Siege,
}

Enemy_Type :: enum {
    Basic,
    Armored,
    Siege,
    Assassin,
    Flyer,
}

Hero_Type :: enum {
    Tank,
    DPS,
    Support,
}

Research_Type :: enum {
    Stronger_Units,
    Better_Towers,
    Hero_Abilities,
    Advanced_Economy,
}

Game_State :: enum {
    Build_Phase,
    Wave_Phase,
    Paused,
    Game_Over,
    Victory,
}

// ============================================================================
// DATA STRUCTURES
// ============================================================================

Vec2i :: struct {
    x, y: i32,
}

Resources :: struct {
    gold:   i32,
    wood:   i32,
    food:   i32,
    supply: i32,
    max_supply: i32,
}

Building :: struct {
    type:       Building_Type,
    health:     i32,
    max_health: i32,
    pos:        Vec2i,
    // Production
    production_timer:    f32,
    production_progress: f32,
    // Tower specific
    attack_range:   f32,
    attack_damage:  i32,
    attack_cooldown: f32,
    last_attack:    f32,
}

Unit :: struct {
    type:       Unit_Type,
    active:     bool,
    health:     i32,
    max_health: i32,
    pos:        rl.Vector2,
    target_pos: rl.Vector2,
    speed:      f32,
    damage:     i32,
    attack_range: f32,
    attack_cooldown: f32,
    last_attack: f32,
    supply_cost: i32,
}

Enemy :: struct {
    type:       Enemy_Type,
    active:     bool,
    health:     i32,
    max_health: i32,
    pos:        rl.Vector2,
    target_pos: rl.Vector2,
    speed:      f32,
    damage:     i32,
    attack_range: f32,
    attack_cooldown: f32,
    last_attack: f32,
    armor:      i32,
    is_flying:  bool,
}

Hero :: struct {
    type:       Hero_Type,
    active:     bool,
    alive:      bool,
    health:     i32,
    max_health: i32,
    pos:        rl.Vector2,
    target_pos: rl.Vector2,
    speed:      f32,
    damage:     i32,
    attack_range: f32,
    attack_cooldown: f32,
    last_attack: f32,
    level:      i32,
    xp:         i32,
    xp_to_next: i32,
    ability_cooldown: f32,
    respawn_timer: f32,
}

Projectile :: struct {
    active:  bool,
    pos:     rl.Vector2,
    target:  rl.Vector2,
    speed:   f32,
    damage:  i32,
    is_aoe:  bool,
    aoe_radius: f32,
}

Worker_Type :: enum {
    Gold,
    Lumber,
}

Worker :: struct {
    active:        bool,
    pos:           rl.Vector2,
    target_pos:    rl.Vector2,
    speed:         f32,
    going_to_work: bool,       // true = going to work site, false = returning to town hall
    work_pos:      Vec2i,      // Which building this worker belongs to
    worker_type:   Worker_Type,
    carrying:      bool,       // Whether carrying resource (visual indicator)
    wait_timer:    f32,        // Time to wait at destination
}

Wave :: struct {
    number:      i32,
    enemies_to_spawn: i32,
    enemies_spawned:  i32,
    spawn_timer: f32,
    spawn_delay: f32,
    enemy_types: [5]Enemy_Type,  // Types that can spawn this wave
    num_types:   i32,
}

Training_Queue_Item :: struct {
    unit_type: Unit_Type,
    progress:  f32,
    time_required: f32,
}

// ============================================================================
// BUILDING DATA
// ============================================================================

Building_Data :: struct {
    gold_cost:  i32,
    wood_cost:  i32,
    health:     i32,
    supply_add: i32,  // For houses
    // Production
    produces_gold: i32,
    produces_wood: i32,
    produces_food: i32,
    production_time: f32,
    // Combat
    attack_range:   f32,
    attack_damage:  i32,
    attack_cooldown: f32,
}

BUILDING_DATA := [Building_Type]Building_Data {
    .None = {},
    .House = {
        gold_cost = 0,
        wood_cost = 50,
        health = 100,
        supply_add = 10,
    },
    .Gold_Mine = {
        gold_cost = 100,
        wood_cost = 50,
        health = 150,
        produces_gold = 10,
        production_time = 5.0,
    },
    .Lumber_Mill = {
        gold_cost = 50,
        wood_cost = 25,
        health = 150,
        produces_wood = 8,
        production_time = 5.0,
    },
    .Farm = {
        gold_cost = 50,
        wood_cost = 30,
        health = 100,
        produces_food = 5,
        production_time = 5.0,
    },
    .Barracks = {
        gold_cost = 150,
        wood_cost = 100,
        health = 300,
    },
    .Archery_Range = {
        gold_cost = 175,
        wood_cost = 125,
        health = 250,
    },
    .Stable = {
        gold_cost = 250,
        wood_cost = 150,
        health = 350,
    },
    .Basic_Tower = {
        gold_cost = 100,
        wood_cost = 75,
        health = 200,
        attack_range = 4.0,
        attack_damage = 15,
        attack_cooldown = 1.0,
    },
    .Advanced_Tower = {
        gold_cost = 250,
        wood_cost = 150,
        health = 300,
        attack_range = 5.0,
        attack_damage = 25,
        attack_cooldown = 1.5,
    },
    .Wall = {
        gold_cost = 0,
        wood_cost = 40,
        health = 500,
    },
    .Research_Hall = {
        gold_cost = 300,
        wood_cost = 200,
        health = 250,
    },
}

// ============================================================================
// UNIT DATA
// ============================================================================

Unit_Data :: struct {
    gold_cost:   i32,
    supply_cost: i32,
    health:      i32,
    damage:      i32,
    speed:       f32,
    attack_range: f32,
    attack_cooldown: f32,
    train_time:  f32,
}

UNIT_DATA := [Unit_Type]Unit_Data {
    .Infantry = {
        gold_cost = 50,
        supply_cost = 2,
        health = 100,
        damage = 10,
        speed = 60.0,
        attack_range = 1.2,
        attack_cooldown = 1.0,
        train_time = 5.0,
    },
    .Archer = {
        gold_cost = 75,
        supply_cost = 3,
        health = 60,
        damage = 15,
        speed = 55.0,
        attack_range = 5.0,
        attack_cooldown = 1.5,
        train_time = 6.0,
    },
    .Cavalry = {
        gold_cost = 150,
        supply_cost = 5,
        health = 150,
        damage = 25,
        speed = 100.0,
        attack_range = 1.5,
        attack_cooldown = 1.2,
        train_time = 10.0,
    },
    .Siege = {
        gold_cost = 300,
        supply_cost = 8,
        health = 200,
        damage = 50,
        speed = 30.0,
        attack_range = 6.0,
        attack_cooldown = 3.0,
        train_time = 15.0,
    },
}

// ============================================================================
// ENEMY DATA
// ============================================================================

Enemy_Data :: struct {
    health:      i32,
    damage:      i32,
    speed:       f32,
    attack_range: f32,
    attack_cooldown: f32,
    armor:       i32,
    is_flying:   bool,
}

ENEMY_DATA := [Enemy_Type]Enemy_Data {
    .Basic = {
        health = 50,
        damage = 8,
        speed = 40.0,
        attack_range = 1.2,
        attack_cooldown = 1.0,
        armor = 0,
    },
    .Armored = {
        health = 100,
        damage = 12,
        speed = 30.0,
        attack_range = 1.2,
        attack_cooldown = 1.2,
        armor = 5,
    },
    .Siege = {
        health = 150,
        damage = 40,
        speed = 20.0,
        attack_range = 2.0,
        attack_cooldown = 2.5,
        armor = 3,
    },
    .Assassin = {
        health = 40,
        damage = 20,
        speed = 80.0,
        attack_range = 1.0,
        attack_cooldown = 0.8,
        armor = 0,
    },
    .Flyer = {
        health = 60,
        damage = 10,
        speed = 50.0,
        attack_range = 1.5,
        attack_cooldown = 1.0,
        armor = 0,
        is_flying = true,
    },
}

// ============================================================================
// HERO DATA
// ============================================================================

Hero_Data :: struct {
    gold_cost:   i32,
    health:      i32,
    damage:      i32,
    speed:       f32,
    attack_range: f32,
    attack_cooldown: f32,
    train_time:  f32,
}

HERO_DATA := [Hero_Type]Hero_Data {
    .Tank = {
        gold_cost = 500,
        health = 500,
        damage = 20,
        speed = 45.0,
        attack_range = 1.5,
        attack_cooldown = 1.0,
        train_time = 30.0,
    },
    .DPS = {
        gold_cost = 600,
        health = 250,
        damage = 50,
        speed = 60.0,
        attack_range = 3.0,
        attack_cooldown = 0.8,
        train_time = 30.0,
    },
    .Support = {
        gold_cost = 550,
        health = 300,
        damage = 15,
        speed = 55.0,
        attack_range = 4.0,
        attack_cooldown = 1.5,
        train_time = 30.0,
    },
}
