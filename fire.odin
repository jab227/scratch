package main

import "core:fmt"
import "core:math/rand"
import "core:mem/virtual"
import "core:slice"
import "core:time"
import "vendor:raylib"

FIRE_WIDTH :: 214
FIRE_HEIGHT :: 160

PIXEL_WIDTH :: 3
PIXEL_HEIGHT :: 3

SCREEN_WIDTH :: FIRE_WIDTH * PIXEL_WIDTH
SCREEN_HEIGHT :: FIRE_HEIGHT * PIXEL_HEIGHT

PALETTE_SIZE :: 37

PALETTE :: [PALETTE_SIZE]raylib.Color {
	{0x07, 0x07, 0x07, 0xFF},
	{0x1F, 0x07, 0x07, 0xFF},
	{0x2F, 0x0F, 0x07, 0xFF},
	{0x47, 0x0F, 0x07, 0xFF},
	{0x57, 0x17, 0x07, 0xFF},
	{0x67, 0x1F, 0x07, 0xFF},
	{0x77, 0x1F, 0x07, 0xFF},
	{0x8F, 0x27, 0x07, 0xFF},
	{0x9F, 0x2F, 0x07, 0xFF},
	{0xAF, 0x3F, 0x07, 0xFF},
	{0xBF, 0x47, 0x07, 0xFF},
	{0xC7, 0x47, 0x07, 0xFF},
	{0xDF, 0x4F, 0x07, 0xFF},
	{0xDF, 0x57, 0x07, 0xFF},
	{0xDF, 0x57, 0x07, 0xFF},
	{0xD7, 0x5F, 0x07, 0xFF},
	{0xD7, 0x5F, 0x07, 0xFF},
	{0xD7, 0x67, 0x0F, 0xFF},
	{0xCF, 0x6F, 0x0F, 0xFF},
	{0xCF, 0x77, 0x0F, 0xFF},
	{0xCF, 0x7F, 0x0F, 0xFF},
	{0xCF, 0x87, 0x17, 0xFF},
	{0xC7, 0x87, 0x17, 0xFF},
	{0xC7, 0x8F, 0x17, 0xFF},
	{0xC7, 0x97, 0x1F, 0xFF},
	{0xBF, 0x9F, 0x1F, 0xFF},
	{0xBF, 0x9F, 0x1F, 0xFF},
	{0xBF, 0xA7, 0x27, 0xFF},
	{0xBF, 0xA7, 0x27, 0xFF},
	{0xBF, 0xAF, 0x2F, 0xFF},
	{0xB7, 0xAF, 0x2F, 0xFF},
	{0xB7, 0xB7, 0x2F, 0xFF},
	{0xB7, 0xB7, 0x37, 0xFF},
	{0xCF, 0xCF, 0x6F, 0xFF},
	{0xDF, 0xDF, 0x9F, 0xFF},
	{0xEF, 0xEF, 0xC7, 0xFF},
	{0xFF, 0xFF, 0xFF, 0xFF},
}

spread_fire :: proc(fire_pixels: []int, src: int) {
	pixel := fire_pixels[src]
	if pixel == 0 {
		fire_pixels[src - FIRE_WIDTH] = 0
	} else {
		@(static)
		init := false
		@(static)
		r := rand.Rand{}
		if !init {
			now := time.time_to_unix(time.now())
			rand.init(&r, u64(now))
			init = true
		}
		rand_y := rand.int_max(3)
		rand_x := rand.int_max(3)
		dst := src - rand_x + 1
		fire_pixels[dst - FIRE_WIDTH if dst - FIRE_WIDTH > 0 else 0] = pixel - (rand_y & 1)
	}
}

update_fire :: proc(fire_pixels: []int) {
	for y in 1 ..< FIRE_HEIGHT {
		for x in 0 ..< FIRE_WIDTH {
			spread_fire(fire_pixels, y * FIRE_WIDTH + x)
		}
	}
}

render_fire :: proc(fire_pixels: []int) {
	palette := PALETTE
	for y in 0 ..< FIRE_HEIGHT {
		for x in 0 ..< FIRE_WIDTH {
			index := fire_pixels[y * FIRE_WIDTH + x]
			pixel_color := palette[index]
			raylib.DrawRectangle(
				i32(x * PIXEL_WIDTH),
				i32(y * PIXEL_HEIGHT),
				PIXEL_WIDTH,
				PIXEL_HEIGHT,
				pixel_color,
			)
		}
	}
}

init_fire :: proc(fire_pixels: []int) {
	fmt.println(len(fire_pixels))
	for i in 0 ..< FIRE_WIDTH {
		fire_pixels[(FIRE_HEIGHT - 1) * FIRE_WIDTH + i] = PALETTE_SIZE - 1
	}
}

reset_fire :: proc(fire_pixels: []int) {
	slice.fill(fire_pixels, 0)
	init_fire(fire_pixels)
}

main :: proc() {
	raylib.InitWindow(FIRE_WIDTH * PIXEL_WIDTH, FIRE_HEIGHT * PIXEL_HEIGHT, "Doom Fire")
	defer raylib.CloseWindow()

	raylib.SetTargetFPS(60)
	arena: virtual.Arena
	if err := virtual.arena_init_static(
		&arena,
		reserved = FIRE_WIDTH * FIRE_HEIGHT * size_of(int),
		commit_size = FIRE_WIDTH * FIRE_HEIGHT * size_of(int),
	); err != nil {
		fmt.panicf("couldn't make arena: %v", err)
	}
	defer virtual.arena_destroy(&arena)
	//	fire_pixels: [FIRE_WIDTH * FIRE_HEIGHT]int
	arena_allocator := virtual.arena_allocator(&arena)
	fire_pixels := make([]int, FIRE_WIDTH * FIRE_HEIGHT, allocator = arena_allocator)
	init_fire(fire_pixels)
	draw_fps := true
	for !raylib.WindowShouldClose() {
		raylib.ClearBackground(raylib.Color{0, 0, 0, 0})

		raylib.BeginDrawing()
		defer raylib.EndDrawing()

		render_fire(fire_pixels[:])
		if draw_fps {
			raylib.DrawFPS(10, 10)
		}
		raylib.DrawText("Doom Fire Demo", SCREEN_WIDTH - 250, 10, 30, raylib.RAYWHITE)

		update_fire(fire_pixels[:])
		if raylib.IsKeyPressed(raylib.KeyboardKey.R) {
			reset_fire(fire_pixels[:])
		}

		if raylib.IsKeyPressed(raylib.KeyboardKey.F) {
			draw_fps = !draw_fps
		}
	}
}
