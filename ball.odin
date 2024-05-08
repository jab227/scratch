package main
import "core:math"
import "vendor:raylib"
SCREEN_WIDTH :: 640
SCREEN_HEIGHT :: 480

scale_screen :: proc(width, height: int, min_width: f32) -> f32 {
    m := math.min(height, width)
    return f32(m) / min_width
}


from_simulation_to_screen_x :: proc(x, scale: f32) -> f32 {
    return x * scale
}

from_simulation_to_screen_y :: proc(y, scale: f32, screen_height: int) -> f32 {
    return f32(screen_height) - y * scale
}

Position :: distinct raylib.Vector2
Velocity :: distinct raylib.Vector2
Gravity :: distinct raylib.Vector2

Ball :: struct {
    pos:    Position,
    v:      Velocity,
    radius: f32,
}

Sim_Dimensions :: struct {
    width, height: f32,
}

Sim_Context :: struct {
    g:        Gravity,
    dt:       f32,
    dims:     Sim_Dimensions,
    substeps: int,
}

ball_update :: proc(ctx: Sim_Context, ball: Ball) -> Ball {
    substeps := 1 if ctx.substeps == 0 else ctx.substeps
    sdt := ctx.dt / f32(substeps)

    velocity := ball.v
    pos := ball.pos

    for i in 0 ..< substeps {
        velocity += Velocity(ctx.g) * sdt
        pos += Position(velocity) * sdt
    }

    if pos.x < 0.0 {
        pos.x = 0.0
        velocity.x = -velocity.x
    }

    if pos.x > ctx.dims.width {
        pos.x = ctx.dims.width
        velocity.x = -velocity.x
    }

    if pos.y < 0.0 {
        pos.y = 0.0
        velocity.y = -velocity.y
    }

    if pos.y > ctx.dims.height {
        pos.y = ctx.dims.height
        velocity.y = -velocity.y
    }

    return Ball{pos = pos, v = velocity, radius = ball.radius}
}

main :: proc() {
    scale := scale_screen(SCREEN_WIDTH, SCREEN_HEIGHT, 20.0)
    dims := Sim_Dimensions {
        width  = f32(SCREEN_WIDTH) / scale,
        height = f32(SCREEN_HEIGHT) / scale,
    }
    g := Gravity{0.0, -9.8}
    ball := Ball {
        pos    = {0.5, 0.2},
        v      = {10.0, 15.0},
        radius = 0.5,
    }
    dt: f32 = 1.0 / 60.0
    raylib.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Test")
    defer raylib.CloseWindow()

    raylib.SetTargetFPS(60)
    ctx := Sim_Context {
        g        = g,
        dims     = dims,
        dt       = dt,
        substeps = 10,
    }
    for !raylib.WindowShouldClose() {
        raylib.BeginDrawing()
        defer raylib.EndDrawing()

        raylib.ClearBackground(raylib.RAYWHITE)
        ball = ball_update(ctx, ball)
        ball_screen_position := raylib.Vector2 {
            from_simulation_to_screen_x(ball.pos.x, scale),
            from_simulation_to_screen_y(ball.pos.y, scale, SCREEN_HEIGHT),
        }
        sim_radius := ball.radius * scale

        raylib.DrawCircleV(ball_screen_position, sim_radius, raylib.MAROON)
    }
}
