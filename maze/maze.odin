package main
import "core:container/small_array"
import "core:math/rand"
import "core:mem/virtual"
import "core:slice"
import rl "vendor:raylib"

Position :: distinct [2]i32

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

cell_state_from_dir :: proc(dir: Direction) -> Cell_Data {
    state: Cell_Data
    switch dir {
    case .North:
        state = .NorthPath
    case .South:
        state = .SouthPath
    case .East:
        state = .EastPath
    case .West:
        state = .WestPath
    }
    return state
}

direction_get_opposite :: proc(dir: Direction) -> Direction {
    d: Direction
    switch dir {
    case .North:
        d = .South
    case .South:
        d = .North
    case .East:
        d = .West
    case .West:
        d = .East
    }
    return d
}

maze_get_index_from_direction :: proc(m: ^Maze, pos: Position, dir: Direction) -> int {
    offset := Position_Offsets[dir]
    result := pos + offset
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
        if Cell_Data.Visited not_in m.cells[idx] do small_array.push_back(&not_visited, Direction.West)
    }

    if y != 0 {
        idx := maze_get_index_from_direction(m, pos, Direction.North)
        if Cell_Data.Visited not_in m.cells[idx] do small_array.push_back(&not_visited, Direction.North)
    }

    if x + 1 < m.width {
        idx := maze_get_index_from_direction(m, pos, Direction.East)
        if Cell_Data.Visited not_in m.cells[idx] do small_array.push_back(&not_visited, Direction.East)
    }

    if y + 1 < m.height {
        idx := maze_get_index_from_direction(m, pos, .South)
        if Cell_Data.Visited not_in m.cells[idx] do small_array.push_back(&not_visited, Direction.South)
    }

    return not_visited
}

Cell_Data :: enum {
    EastPath,
    WestPath,
    NorthPath,
    SouthPath,
    Visited,
}

Cell :: bit_set[Cell_Data]

Maze :: struct {
    cells:  []Cell,
    height: int,
    width:  int,
}

maze_make :: proc(rows, cols: int, allocator := context.allocator) -> Maze {
    assert(rows > 1)
    assert(cols > 1)
    cells := make([]Cell, rows * cols, allocator)
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
    if g.visited >= len(prev.cells) {
        return prev, false
    }
    top := slice.last(g.stack[:])
    neighbours := maze_compute_neighbours(&prev, top)
    ns := small_array.slice(&neighbours)
    if len(ns) != 0 {
        next := rand.choice(ns)
        idx := get_index(top, prev.width)
        prev.cells[idx] |= {cell_state_from_dir(next)}
        next_idx := maze_get_index_from_direction(&prev, top, next)
        opposite_dir := direction_get_opposite(next)
        prev.cells[next_idx] |= {cell_state_from_dir(opposite_dir), .Visited}
        top = top + Position_Offsets[next]
        append(&g.stack, top)
        g.visited += 1
    } else {
        pop(&g.stack)
    }
    return prev, true

}

maze_draw :: proc(m: ^Maze) {
    for x in 0 ..< m.width {
        for y in 0 ..< m.height {
            idx := y * m.width + x
            color := rl.WHITE if .Visited in m.cells[idx] else rl.BLUE
            for py in 0 ..< PATH_WIDTH {
                for px in 0 ..< PATH_WIDTH {
                    rl.DrawRectangle(
                        i32(x * (PATH_WIDTH + 1) + px),
                        i32(y * (PATH_WIDTH + 1) + py),
                        1,
                        1,
                        color,
                    )
                }
            }
            for p in 0 ..< PATH_WIDTH {
                cell := m.cells[get_index({i32(x), i32(y)}, MAZE_WIDTH)]
                if .SouthPath in cell {
                    rl.DrawRectangle(
                        i32(x * (PATH_WIDTH + 1) + p),
                        i32(y * (PATH_WIDTH + 1) + PATH_WIDTH),
                        1,
                        1,
                        rl.WHITE,
                    )
                }

                if .EastPath in cell {
                    rl.DrawRectangle(
                        i32(x * (PATH_WIDTH + 1) + PATH_WIDTH),
                        i32(y * (PATH_WIDTH + 1) + p),
                        1,
                        1,
                        rl.WHITE,
                    )
                }
            }
        }
    }
}

maze_draw_cursor :: proc(stack: []Position) {
    top := slice.last(stack)
    for py in 0 ..< PATH_WIDTH {
        for px in 0 ..< PATH_WIDTH {
            rl.DrawRectangle(
                i32(top.x * (PATH_WIDTH + 1) + i32(px)),
                i32(top.y * (PATH_WIDTH + 1) + i32(py)),
                1,
                1,
                rl.GREEN,
            )
        }
    }
}

maze_make_texture :: proc(m: ^Maze, stack: []Position, target: rl.RenderTexture2D) {
    rl.BeginTextureMode(target)
    defer rl.EndTextureMode()

    rl.ClearBackground(rl.BLACK)
    maze_draw(m)
    maze_draw_cursor(stack)
}

MAZE_WIDTH :: 40
MAZE_HEIGHT :: 25
PATH_WIDTH :: 2

main :: proc() {
    maze_arena: virtual.Arena
    stack_arena: virtual.Arena
    maze_arena_size := uint(MAZE_WIDTH * MAZE_HEIGHT * size_of(Cell))
    /* err := virtual.arena_init_static( */
    /*     &maze_arena, */
    /*     reserved = maze_arena_size, */
    /*     commit_size = maze_arena_size, */
    /* ) */
    /* if err != nil { */
    /*     return */
    /* }
 */
    maze := maze_make(MAZE_HEIGHT, MAZE_WIDTH)

    gen: Generator
    generator_init(&gen, &maze)

    rl.InitWindow(640, 480, "maze generator")
    defer rl.CloseWindow()

    target := rl.LoadRenderTexture(MAZE_WIDTH * (PATH_WIDTH + 1), MAZE_HEIGHT * (PATH_WIDTH + 1))
    defer rl.UnloadRenderTexture(target)

    rl.SetTargetFPS(100)
    paused := true
    for !rl.WindowShouldClose() {
        if rl.GetKeyPressed() == rl.KeyboardKey.SPACE {
            paused = !paused
        }
        maze_make_texture(&maze, gen.stack[:], target)

        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.BLACK)
        source := rl.Rectangle{0.0, 0.0, f32(target.texture.width), f32(-target.texture.height)}
        dst := rl.Rectangle{0.0, 0.0, 640.0, 480.0}
        rl.DrawTexturePro(target.texture, source, dst, rl.Vector2{0.0, 0.0}, 0.0, rl.WHITE)
        if !paused {
            maze, ok := generate_next(&gen, maze)
            if !ok {
                return
            }
        }
    }

}
