package main

import "core:math"
import la "core:math/linalg"
import "core:math/rand"
import "core:time"
import rl "vendor:raylib"

SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 720
Vector2 :: rl.Vector2

Boid :: struct {
    pos: Vector2,
    vel: Vector2,
}

boid_distance :: proc(c1, c2: Vector2) -> f32 {
    return la.length(c2 - c1)
}

boid_init :: proc(boid: ^Boid) {
    x, y := rand.float32() * SCREEN_WIDTH, rand.float32() * SCREEN_HEIGHT
    boid.pos = {x, y}
    boid.vel = {1.0, -1.0}
}

boids_reset :: proc(boids: []Boid) {
    for &boid in boids {
        boid_init(&boid)
    }
}

boids_create :: proc(size: int, allocator := context.allocator) -> []Boid {
    boids := make([]Boid, size)
    boids_reset(boids)
    return boids
}

Simulation_State :: struct {
    boids:            []Boid,
    protected_range:  f32,
    visible_range:    f32,
    matching_factor:  f32,
    avoid_factor:     f32,
    centering_factor: f32,
    turnfactor:       f32,
    maxspeed:         f32,
    minspeed:         f32,
}

simulation_init :: proc(state: ^Simulation_State, count := 100, allocator := context.allocator) {
    state.boids = boids_create(count, allocator)
    state.protected_range = f32(2.0)
    state.visible_range = f32(20.0)
    state.matching_factor = f32(0.05)
    state.avoid_factor = f32(0.05)
    state.centering_factor = f32(0.0005)
    state.turnfactor = f32(2.0)
    state.maxspeed = f32(3.0)
    state.minspeed = f32(2.0)
}

simulation_destroy :: proc(state: ^Simulation_State, allocator := context.allocator) {
    delete(state.boids, allocator)
}

simulation_update :: proc(state: ^Simulation_State) {
    // Separation
    for i in 0 ..< len(state.boids) {
        close_dxdy, avg_vel, avg_pos: Vector2
        neighbourin_boids: int
        for j in 0 ..< len(state.boids) {
            if i == j do continue
            distance := boid_distance(state.boids[i].pos, state.boids[j].pos)
            if distance < state.protected_range {
                close_dxdy += (state.boids[i].pos - state.boids[j].pos)
            }

            if distance < state.visible_range {
                avg_vel += state.boids[j].vel
                avg_pos += state.boids[j].pos
                neighbourin_boids += 1
            }
        }
        state.boids[i].vel += (close_dxdy * state.avoid_factor)
        if neighbourin_boids > 0 {
            avg_vel /= f32(neighbourin_boids)
            avg_pos /= f32(neighbourin_boids)
            state.boids[i].vel += (avg_vel - state.boids[i].vel) * state.matching_factor
            state.boids[i].vel += (avg_pos - state.boids[i].pos) * state.centering_factor
        }
        if state.boids[i].pos.x < SCREEN_WIDTH / 4 {
            state.boids[i].vel.x += state.turnfactor
        }
        if state.boids[i].pos.x > 3 * SCREEN_WIDTH / 4 {
            state.boids[i].vel.x -= state.turnfactor
        }

        if state.boids[i].pos.y < SCREEN_HEIGHT / 4 {
            state.boids[i].vel.y += state.turnfactor
        }
        if state.boids[i].pos.y > 3 * SCREEN_HEIGHT / 4 {
            state.boids[i].vel.y -= state.turnfactor
        }

        speed := la.length(state.boids[i].vel)
        if speed < state.minspeed {
            state.boids[i].vel.x = (state.boids[i].vel.x / speed) * state.minspeed
            state.boids[i].vel.y = (state.boids[i].vel.y / speed) * state.maxspeed
        }
        if speed > state.maxspeed {
            state.boids[i].vel.x = (state.boids[i].vel.x / speed) * state.maxspeed
            state.boids[i].vel.y = (state.boids[i].vel.y / speed) * state.minspeed
        }
        state.boids[i].pos += state.boids[i].vel
    }
    // Alignment
    // Cohesion
    // update pos
}


boids_draw :: proc(boids: []Boid) {
    for &boid in boids {
        //			rl.DrawCircle(i32(boid.pos.x), i32(boid.pos.y), 3.5, rl.WHITE)


        a := boid.pos
        b := (boid.pos + {-5, 15})
        c := (boid.pos + {5, 15})
        center := (a + b + c) / 3
        ac := a - center
        bc := b - center
        cc := c - center
        angle := la.angle_between(ac, boid.vel)
        rotation := la.matrix2_rotate(angle)
        acr := rotation * ac
        bcr := rotation * bc
        ccr := rotation * cc
        a = acr + center
        b = bcr + center
        c = ccr + center
        rl.DrawTriangle(a, b, c, rl.WHITE)
    }
}

process_input :: proc(boids: []Boid) {
    if rl.IsKeyDown(.R) {
        boids_reset(boids)
    }

}

main :: proc() {
    rl.SetTraceLogLevel(.ERROR)

    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "boids simulation")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)

    state: Simulation_State
    simulation_init(&state, 12)
    defer simulation_destroy(&state)

    for !rl.WindowShouldClose() {
        process_input(state.boids)
        simulation_update(&state)

        rl.BeginDrawing()
        {
            rl.ClearBackground(rl.BLUE)
            boids_draw(state.boids)
        }
        rl.EndDrawing()
    }
}
