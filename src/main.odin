package game

import rl "vendor:raylib"

// ============================================================================
// MAIN ENTRY POINT
// ============================================================================

main :: proc() {
    // Initialize window
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Castle Defense")

    rl.SetTargetFPS(60)
    
    // Load assets
    load_assets()
    
    // Initialize game
    game := init_game()
    
    // Main game loop
    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        
        // Handle input
        handle_input(&game)
        
        // Update game based on state
        switch game.state {
            case .Build_Phase:
                // Countdown to next wave
                game.wave_countdown -= dt
                if game.wave_countdown <= 0 {
                    start_wave(&game)
                }
                // Still update production buildings
                update_buildings(&game, dt)
                update_workers(&game, dt)  // Workers always animate
                
            case .Wave_Phase:
                // Update all systems
                update_buildings(&game, dt)
                update_units(&game, dt)
                update_enemies(&game, dt)
                update_heroes(&game, dt)
                update_projectiles(&game, dt)
                update_wave(&game, dt)
                update_food_upkeep(&game, dt)
                update_workers(&game, dt)  // Workers always animate
                
            case .Paused:
                // Do nothing
                
            case .Game_Over, .Victory:
                // Wait for restart
                if rl.IsKeyPressed(.R) {
                    game = init_game()
                }
        }
        
        // Render
        render_game(&game)
    }
    
    // Cleanup
    unload_assets()
    rl.CloseWindow()
}
