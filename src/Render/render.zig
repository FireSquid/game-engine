const std = @import("std");
const log = std.log.scoped(.render);

const c = @import("../c.zig");

const GameContext = @import("../game_context.zig").GameContext;

const _render_test = @import("../Render/test.zig");

const _component = @import("../Component/component.zig");
const _texture = @import("../Component/texture.zig");
const _text_field = @import("../Component/text_field.zig");
const _ui_frame = @import("../Component/ui_frame.zig");
const _position = @import("../Component/position.zig");
const _bounds = @import("../Component/bounds.zig");

const _entity = @import("../Entity/entity.zig");

pub const Layers = struct {
    pub const Background: i32 = 100;
    pub const Foreground: i32 = 0;
    pub const UI: i32 = -1_000;
    pub const UI_BG: i32 = -1_100;
};

const run_startup_tests = true;

const texture_list = [_][]const u8{
    "resc/planet_back.png",
    "resc/planet_fore_1.png",
};

pub const Render = struct {
    alloc: std.mem.Allocator,
    context: *GameContext,

    draw_count: usize,

    state: enum {
        Starting,
        Running,
        Stopping,
        Stopped,
    },

    pub fn init(alloc: std.mem.Allocator, context: *GameContext) Render {
        _texture.context = context;
        return Render{
            .alloc = alloc,
            .context = context,

            .draw_count = 0,

            .state = .Starting,
        };
    }

    pub fn deinit(self: *Render) void {
        self.state = .Stopped;
    }

    pub fn createWindow(self: Render, x_size: u16, y_size: u16, title: [*c]const u8, target_framerate: usize) void {
        _ = self;
        c.InitWindow(x_size, y_size, title);
        c.SetTargetFPS(@intCast(target_framerate));
    }

    pub fn updateLoop(self: *Render) void {
        const dt = c.GetFrameTime();

        self.handleInput();
        drawFrame(self, dt);
    }

    fn drawFrame(self: *Render, delta_time: f32) void {
        _ = delta_time;

        c.BeginDrawing();
        defer c.EndDrawing();

        c.ClearBackground(c.BLACK);

        {
            const DrawIt = _component.MultiIterator(.{ _texture.TextureObject, _text_field.TextField, _ui_frame.UiFrame });
            const IdUnionTags = @typeInfo(DrawIt.IdUnion).@"union".tag_type.?;
            const tag_texture_object = @field(IdUnionTags, DrawIt.fieldName(_texture.TextureObject));
            const tag_text_field = @field(IdUnionTags, DrawIt.fieldName(_text_field.TextField));
            const tag_ui_frame = @field(IdUnionTags, DrawIt.fieldName(_ui_frame.UiFrame));

            const getDepth = struct {
                fn _getDepth(comp: DrawIt.SortUnion) i32 {
                    switch (comp) {
                        inline else => |_comp| {
                            return _comp.depth;
                        }
                    }
                }
            }._getDepth;

            var draw_it = DrawIt.init(self.alloc, .{ .ascending = false, .sortValFn = getDepth });
            defer draw_it.deinit();

            while (draw_it.next()) |id_union| {
                switch (id_union) {
                    tag_texture_object => |to_id| {
                        _texture.TextureObject.draw(to_id);
                    },
                    tag_text_field => |tf_id| {
                        _text_field.TextField.draw(tf_id);
                    },
                    tag_ui_frame => |uf_id| {
                        _ui_frame.UiFrame.draw(uf_id);
                    },
                }
            }
        }

        c.DrawFPS(10, 10);

        self.draw_count +|= 1;

        var frame_str_buffer: [31]u8 = undefined;
        const frame_str = std.fmt.bufPrintZ(&frame_str_buffer, "Frame: {d}", .{self.draw_count}) catch unreachable;
        c.DrawText(frame_str, 10, 28, 10, c.GREEN);
    }

    fn handleInput(self: Render) void {
        const mouse_vec = c.GetMousePosition();

        if (c.IsMouseButtonPressed(c.MOUSE_BUTTON_LEFT)) {
            const LeftClickIt = _component.MultiIterator(.{_bounds.Bounds});
            const IdUnionTags = @typeInfo(LeftClickIt.IdUnion).@"union".tag_type.?;
            const tag_bounds = @field(IdUnionTags, LeftClickIt.fieldName(_bounds.Bounds));

            var left_click_it = LeftClickIt.init(self.alloc, null);
            defer left_click_it.deinit();

            while (left_click_it.next()) |id_union| {
                switch (id_union) {
                    tag_bounds => |b_id| {
                        var bounds_ref = b_id.read() orelse continue;
                        defer bounds_ref.close();

                        bounds_ref.comp.handleClick(mouse_vec);
                    },
                }
            }
        }
    }
};

pub fn renderThread(alloc: std.mem.Allocator, context: *GameContext) void {
    log.info("Starting render thread", .{});

    const render = alloc.create(Render) catch unreachable;
    defer alloc.destroy(render);
    render.* = Render.init(alloc, context);

    log.debug("Initialized Render", .{});
    context.render = render;
    log.debug("Linked Render context", .{});
    defer {
        log.debug("Render deinit and cleanup", .{});
        if (context.render == render) {
            context.render = null;
        }
        render.deinit();
    }
    render.createWindow(1600, 900, "Game Window", 60);
    log.debug("Created game window", .{});
    _texture.loadTextures();
    render.state = .Running;
    log.debug("Loaded textures", .{});
    if (run_startup_tests) {
        log.info("Running startup tests", .{});
        _render_test.runFullStartupTest(alloc);
        log.debug("Finished startup tests", .{});
    }
    while (!c.WindowShouldClose() and render.state != .Stopping) {
        render.updateLoop();
    }
}
