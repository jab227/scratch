package main

import "core:container/bit_array"
import "core:fmt"
import "core:log"
import "core:math"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 800
GRID_WIDTH :: 20
CELL_SIZE :: 16
CANVAS_SIZE :: GRID_WIDTH * CELL_SIZE
TICK_RATE :: 0.13
MAX_SNAKE_LENGHT :: GRID_WIDTH * GRID_WIDTH

Snake :: struct {
    body:   [MAX_SNAKE_LENGHT][2]int,
    length: int,
}

BACKGROUND_COLOR :: [4]u8{0x9c, 0xca, 0x08, 0xFF}

snake_init :: proc(snake: ^Snake, allocator := context.allocator) {
    start_head_pos := [2]int{GRID_WIDTH / 2.0, GRID_WIDTH / 2.0}
    snake.body[0] = start_head_pos
    snake.body[1] = start_head_pos - {0, 1}
    snake.body[2] = start_head_pos - {0, 2}
    snake.length = 3
}


place_food :: proc(s: ^Game_State) {
    snake_positions := s.snake.body
    occupied: [GRID_WIDTH][GRID_WIDTH]bool
    for i in 0 ..< s.snake.length {
        occupied[snake_positions[i].x][snake_positions[i].y] = true
    }

    free_cells := make([dynamic][2]int, allocator = context.temp_allocator)

    for x in 0 ..< GRID_WIDTH {
        for y in 0 ..< GRID_WIDTH {
            if !occupied[x][y] do append(&free_cells, [2]int{x, y})
        }
    }

    if len(free_cells) > 0 do s.food_pos = rand.choice(free_cells[:])
}

Game_State :: struct {
    move_direction: [2]int,
    food_pos:       [2]int,
    snake:          ^Snake,
    game_over:      bool,
}

restart :: proc(state: ^Game_State) {
    state.game_over = false
    state.move_direction = [2]int{0, 1}
    snake_init(state.snake)
    place_food(state)
}

process_input :: proc(state: ^Game_State) {
    if rl.IsKeyDown(.W) && state.move_direction != {0, 1} {
        state.move_direction = {0, -1}
    }
    if rl.IsKeyDown(.S) && state.move_direction != {0, -1} {
        state.move_direction = {0, 1}
    }
    if rl.IsKeyDown(.A) && state.move_direction != {1, 0} {
        state.move_direction = {-1, 0}
    }
    if rl.IsKeyDown(.D) && state.move_direction != {-1, 0} {
        state.move_direction = {1, 0}
    }

    if state.game_over && rl.IsKeyPressed(.R) {
        restart(state)
    }
}

// Scroll shooter
main :: proc() {
    context.logger = log.create_console_logger()
    defer log.destroy_console_logger(context.logger)

    snake := Snake{}
    snake_init(&snake)

    state := Game_State {
        snake          = &snake,
        game_over      = false,
        move_direction = [2]int{0, 1},
    }
    place_food(&state)
    rl.SetConfigFlags({.VSYNC_HINT})
    rl.SetTraceLogLevel(.ERROR)
    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "snake")
    defer rl.CloseWindow()

    food_sprite := rl.LoadTexture("food.png")
    head_sprite := rl.LoadTexture("head.png")
    body_sprite := rl.LoadTexture("body.png")
    tail_sprite := rl.LoadTexture("tail.png")
    defer {
        rl.UnloadTexture(food_sprite)
        rl.UnloadTexture(head_sprite)
        rl.UnloadTexture(body_sprite)
        rl.UnloadTexture(tail_sprite)
    }


    eat_sound := rl.LoadSound("eat.wav")
    crash_sound := rl.LoadSound("crash.wav")
    tick_timer := TICK_RATE
    for !rl.WindowShouldClose() {
        process_input(&state)
        if !state.game_over {
            tick_timer -= f64(rl.GetFrameTime())
        }

        if tick_timer <= 0 {
            next_pos := snake.body[0]
            snake.body[0] += state.move_direction
            head_pos := snake.body[0]
            state.game_over =
                head_pos.x < 0 ||
                head_pos.x >= GRID_WIDTH ||
                head_pos.y < 0 ||
                head_pos.y >= GRID_WIDTH

            if state.game_over {
                rl.PlaySound(crash_sound)
            }
            for i in 1 ..< snake.length {
                curr := snake.body[i]
                if curr == head_pos {
                    state.game_over = true
                    rl.PlaySound(crash_sound)
                    break
                }
                snake.body[i] = next_pos
                next_pos = curr
            }

            if head_pos == state.food_pos {
                snake.length += 1
                snake.body[snake.length - 1] = next_pos
                place_food(&state)
                rl.PlaySound(eat_sound)
            }
            tick_timer += TICK_RATE
        }

        rl.BeginDrawing()
        defer rl.EndDrawing()

        // #9CCA08				
        rl.ClearBackground(rl.Color(BACKGROUND_COLOR))


        camera := rl.Camera2D {
            zoom = f32(WINDOW_HEIGHT + WINDOW_WIDTH) / (2 * CANVAS_SIZE),
        }
        rl.BeginMode2D(camera)
        defer rl.EndMode2D()


        if state.game_over {
            rl.DrawText("GAME OVER!", 4, 4, 25, rl.BLACK)
            rl.DrawText("Press enter to restart", 4, 30, 15, rl.BLACK)
            continue
        }

        score := state.snake.length - 3
        score_str := fmt.ctprintf("Score: %d", score)
        rl.DrawText(score_str, 4, CANVAS_SIZE - 14, 10, rl.BLACK)
        pos := rl.Vector2{f32(state.food_pos.x), f32(state.food_pos.y)} * CELL_SIZE
        rl.DrawTextureEx(food_sprite, pos, 0.0, 0.1, rl.BLACK)
        for i in 0 ..< snake.length {
            part := body_sprite
            dir: [2]int
            if i == 0 {
                part = head_sprite
                dir = snake.body[i] - snake.body[i + 1]
            } else if i == snake.length - 1 {
                part = tail_sprite
                dir = snake.body[i - 1] - snake.body[i]
            } else {
                dir = snake.body[i - 1] - snake.body[i]
            }
            rotation := math.to_degrees(math.atan2(f32(dir.y), f32(dir.x)))
            part_pos :=
                rl.Vector2{f32(snake.body[i].x) + 0.5, f32(snake.body[i].y) + 0.5} * CELL_SIZE
            src := rl.Rectangle{0, 0, f32(part.width), f32(part.height)}
            dst := rl.Rectangle{part_pos.x, part_pos.y, CELL_SIZE, CELL_SIZE}
            origin := [2]f32{CELL_SIZE, CELL_SIZE} * 0.5
            rl.DrawTexturePro(part, src, dst, origin, rotation, rl.WHITE)
        }
        free_all(context.temp_allocator)
    }
}
