package game

import rl "vendor:raylib"
import "core:fmt"

// ============================================================================
// TEXTURE MANAGEMENT
// ============================================================================

Assets :: struct {
    ground_texture: rl.Texture2D,
    ground_loaded: bool,
    
    // Building textures
    building_goldmine: rl.Texture2D,
    building_lumbermill: rl.Texture2D,
    building_knight_house: rl.Texture2D,  // Barracks
    building_archer_house: rl.Texture2D,  // Archery Range
    building_main_hall: rl.Texture2D,     // House
    buildings_loaded: bool,
}

// Global assets
g_assets: Assets

load_assets :: proc() {
    // Load the single ground texture to stretch across the entire grid
    g_assets.ground_texture = rl.LoadTexture("src/assets/ground/single_image.png")
    
    if g_assets.ground_texture.id != 0 {
        g_assets.ground_loaded = true
        fmt.printf("Ground texture loaded: %dx%d\n", g_assets.ground_texture.width, g_assets.ground_texture.height)
    } else {
        g_assets.ground_loaded = false
        fmt.println("Warning: Failed to load single_image.png")
    }
    
    // Load building textures
    g_assets.building_goldmine = rl.LoadTexture("src/assets/buildings/goldmine.png")
    g_assets.building_lumbermill = rl.LoadTexture("src/assets/buildings/lumbermill.png")
    g_assets.building_knight_house = rl.LoadTexture("src/assets/buildings/knight_house.png")
    g_assets.building_archer_house = rl.LoadTexture("src/assets/buildings/archer_house.png")
    g_assets.building_main_hall = rl.LoadTexture("src/assets/buildings/main_hall.png")
    
    g_assets.buildings_loaded = true
    if g_assets.building_goldmine.id == 0 { g_assets.buildings_loaded = false; fmt.println("Warning: Failed to load goldmine.png") }
    if g_assets.building_lumbermill.id == 0 { g_assets.buildings_loaded = false; fmt.println("Warning: Failed to load lumbermill.png") }
    if g_assets.building_knight_house.id == 0 { g_assets.buildings_loaded = false; fmt.println("Warning: Failed to load knight_house.png") }
    if g_assets.building_archer_house.id == 0 { g_assets.buildings_loaded = false; fmt.println("Warning: Failed to load archer_house.png") }
    if g_assets.building_main_hall.id == 0 { g_assets.buildings_loaded = false; fmt.println("Warning: Failed to load main_hall.png") }
    
    if g_assets.buildings_loaded {
        fmt.println("All building textures loaded successfully!")
    }
}

unload_assets :: proc() {
    if g_assets.ground_texture.id != 0 {
        rl.UnloadTexture(g_assets.ground_texture)
    }
    if g_assets.building_goldmine.id != 0 {
        rl.UnloadTexture(g_assets.building_goldmine)
    }
    if g_assets.building_lumbermill.id != 0 {
        rl.UnloadTexture(g_assets.building_lumbermill)
    }
    if g_assets.building_knight_house.id != 0 {
        rl.UnloadTexture(g_assets.building_knight_house)
    }
    if g_assets.building_archer_house.id != 0 {
        rl.UnloadTexture(g_assets.building_archer_house)
    }
    if g_assets.building_main_hall.id != 0 {
        rl.UnloadTexture(g_assets.building_main_hall)
    }
}
