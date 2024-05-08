package main
import "core:container/small_array"
import "core:fmt"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"

Position :: struct {
    x: i32,
    y: i32,
}

Direction :: enum {
    North = 0,
    South = 1,
    East  = 2,
    West  = 3,
}

Position_Offsets := [Direction]Position {
    .North = {0, -1},
    .South = {0, 1},
    .East  = {1, 0},
    .West  = {-1, 0},
}

position_add :: proc(a, b: Position) -> Position {
    return Position{a.x + b.x, a.y + b.y}
}

maze_get_index_from_direction :: proc(m: ^Maze, pos: Position, dir: Direction) -> int {
    offset := Position_Offsets[dir]
    result := position_add(pos, offset)
    idx := get_index(result, m.width)
    return idx
}

get_index :: proc(pos: Position, width: int) -> int {
    x := int(pos.x)
    y := int(pos.y)
    return x + width * y
}


maze_compute_neighbours :: proc(m: ^Maze, pos: Position) -> small_array.Small_Array(4, Direction) {
    x := int(pos.x)
    y := int(pos.y)

    assert(x >= 0 && y >= 0, message = "negative position")
    assert(x < m.width && y < m.height, message = "out of bounds")

    not_visited: small_array.Small_Array(4, Direction)

    if x != 0 {
        idx := maze_get_index_from_direction(m, pos, Direction.West)
        if Cell_States.Visited not_in m.cells[idx] do small_array.push_back(&not_visited, Direction.West)
    }

    if y != 0 {
        idx := maze_get_index_from_direction(m, pos, Direction.North)
        if Cell_States.Visited not_in m.cells[idx] do small_array.push_back(&not_visited, Direction.North)
    }

    if x + 1 < m.width {
        idx := maze_get_index_from_direction(m, pos, Direction.East)
        if Cell_States.Visited not_in m.cells[idx] do small_array.push_back(&not_visited, Direction.East)
    }

    if y + 1 < m.height {
        idx := maze_get_index_from_direction(m, pos, .South)
        if Cell_States.Visited not_in m.cells[idx] do small_array.push_back(&not_visited, Direction.South)
    }

    return not_visited
}

Cell_States :: enum {
    EastPath,
    WestPath,
    NorthPath,
    SouthPath,
    Visited,
}

Cell :: bit_set[Cell_States]

Maze :: struct {
    cells:  []Cell,
    height: int,
    width:  int,
}

maze_make :: proc(rows, cols: int, allocator := context.allocator) -> Maze {
    assert(rows > 1)
    assert(cols > 1)
    cells := make([]Cell, rows * cols)
    return Maze{cells = cells, height = rows, width = cols}
}

Generator :: struct {
    stack:   [dynamic]Position,
    visited: int,
}

generator_init :: proc(g: ^Generator, m: ^Maze, allocator := context.allocator) {
    assert(len(m.cells) > 0)
    stack := make([dynamic]Position, allocator = allocator)
    append(&stack, Position{})
    m.cells[0] |= {.Visited}
    g^ = Generator {
        stack   = stack,
        visited = 1,
    }
}

generate_next :: proc(g: ^Generator, prev: Maze) -> (Maze, bool) {
    prev := prev
    g := g
    if g.visited < len(prev.cells) {

        top := slice.last(g.stack[:])
        neighbours := maze_compute_neighbours(&prev, top)
        ns := small_array.slice(&neighbours)
        if len(ns) != 0 {
            next := rand.choice(ns)
            idx := get_index(top, prev.width)
            switch next {
            case Direction.North:
                prev.cells[idx] |= {Cell_States.NorthPath}
                north_idx := maze_get_index_from_direction(&prev, top, .North)
                prev.cells[north_idx] |= {Cell_States.SouthPath, .Visited}
                top = position_add(top, Position_Offsets[.North])
            case Direction.South:
                prev.cells[idx] |= {Cell_States.SouthPath}
                south_idx := maze_get_index_from_direction(&prev, top, .South)
                prev.cells[south_idx] |= {Cell_States.NorthPath, .Visited}
                top = position_add(top, Position_Offsets[.South])
            case Direction.East:
                prev.cells[idx] |= {Cell_States.EastPath}
                east_idx := maze_get_index_from_direction(&prev, top, .East)
                prev.cells[east_idx] = prev.cells[east_idx] | {Cell_States.WestPath, .Visited}
                top = position_add(top, Position_Offsets[.East])
            case Direction.West:
                prev.cells[idx] |= {Cell_States.WestPath}
                west_idx := maze_get_index_from_direction(&prev, top, .West)
                prev.cells[west_idx] |= {Cell_States.EastPath, .Visited}
                top = position_add(top, Position_Offsets[.West])
            }
            append(&g.stack, top)
            g.visited += 1
        } else {
            pop(&g.stack)
        }
        return prev, true
    }
    return prev, false
}

maze_render :: proc(m: ^Maze) {
    for x in 0 ..< m.width {
        for y in 0 ..< m.height {
            idx := y * m.width + x
            color := rl.WHITE if .Visited in m.cells[idx] else rl.BLUE
            for py in 0 ..< PATH_WIDTH {
                for px in 0 ..< PATH_WIDTH {
                    rl.DrawRectangle(
                        i32(x * (PATH_WIDTH + 1) + px) * PIXEL_WIDTH,
                        i32(y * (PATH_WIDTH + 1) + py) * PIXEL_HEIGHT,
                        PIXEL_WIDTH,
                        PIXEL_HEIGHT,
                        color,
                    )
                }
            }
            for p in 0 ..< PATH_WIDTH {
                cell := m.cells[get_index(Position{i32(x), i32(y)}, MAZE_WIDTH)]
                if .SouthPath in cell {
                    rl.DrawRectangle(
                        i32(x * (PATH_WIDTH + 1) + p) * PIXEL_WIDTH,
                        i32(y * (PATH_WIDTH + 1) + PATH_WIDTH) * PIXEL_HEIGHT,
                        PIXEL_WIDTH,
                        PIXEL_HEIGHT,
                        rl.WHITE,
                    )
                }

                if .EastPath in cell {
                    rl.DrawRectangle(
                        i32(x * (PATH_WIDTH + 1) + PATH_WIDTH) * PIXEL_WIDTH,
                        i32(y * (PATH_WIDTH + 1) + p) * PIXEL_HEIGHT,
                        PIXEL_WIDTH,
                        PIXEL_HEIGHT,
                        rl.WHITE,
                    )
                }
            }
        }
    }
}


MAZE_WIDTH :: 40
MAZE_HEIGHT :: 25
PIXEL_WIDTH :: 1
PIXEL_HEIGHT :: 1
PATH_WIDTH :: 2

main :: proc() {
    rl.InitWindow(640, 480, "maze generator")
    defer rl.CloseWindow()

    maze := maze_make(MAZE_HEIGHT, MAZE_WIDTH)
    defer delete(maze.cells)

    gen: Generator
    generator_init(&gen, &maze)
    defer delete(gen.stack)

    target := rl.LoadRenderTexture(MAZE_WIDTH * (PATH_WIDTH + 1), MAZE_HEIGHT * (PATH_WIDTH + 1))
    //		rl.SetTextureFilter(target.texture, rl.TextureFilter.BILINEAR)
    rl.SetTargetFPS(100)
    scale := min(
        640.0 / f32(MAZE_WIDTH * (PATH_WIDTH + 1)),
        480.0 / f32(MAZE_HEIGHT * (PATH_WIDTH + 1)),
    )
    for !rl.WindowShouldClose() {
        maze, ok := generate_next(&gen, maze)
        {
            rl.BeginTextureMode(target)
            defer rl.EndTextureMode()

            rl.ClearBackground(rl.BLACK)
            maze_render(&maze)

            top := slice.last(gen.stack[:])
            for py in 0 ..< PATH_WIDTH {
                for px in 0 ..< PATH_WIDTH {
                    rl.DrawRectangle(
                        i32(top.x * (PATH_WIDTH + 1) + i32(px)) * PIXEL_WIDTH,
                        i32(top.y * (PATH_WIDTH + 1) + i32(py)) * PIXEL_HEIGHT,
                        PIXEL_WIDTH,
                        PIXEL_HEIGHT,
                        rl.GREEN,
                    )
                }
            }
        }

        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.BLACK)
        source := rl.Rectangle{0.0, 0.0, f32(target.texture.width), f32(-target.texture.height)}
        dst := rl.Rectangle{0.0, 0.0, 640.0, 480.0}
        rl.DrawTexturePro(target.texture, source, dst, rl.Vector2{0.0, 0.0}, 0.0, rl.WHITE)

    }
    rl.UnloadRenderTexture(target)
}
