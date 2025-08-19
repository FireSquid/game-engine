const std = @import("std");
const log = std.log.scoped(.render);

const c = @import("../c.zig");

const GameContext = @import("../game_context.zig").GameContext;

const _logging = @import("../Debugging/logging.zig");

const _component = @import("../Component/component.zig");
const _texture = @import("../Component/texture.zig");
const _text_field = @import("../Component/text_field.zig");
const _position = @import("../Component/position.zig");

const _entity = @import("../Entity/entity.zig");

pub const Layers = struct {
    pub const Background: i32 = 10000;
    pub const Foreground: i32 = 0;
    pub const UI: i32 = -10000;
};

const texture_list = [_][]const u8{
    "resc/planet_back.png",
    "resc/planet_fore_1.png",
};

pub const Render = struct {
    alloc: std.mem.Allocator,
    context: *GameContext,
    logger: ?*_logging.Logger,

    draw_count: usize,

    state: enum {
        Starting,
        Running,
        Stopping,
        Stopped,
    },

    pub fn init(alloc: std.mem.Allocator, logger: ?*_logging.Logger, context: *GameContext) Render {
        _texture.context = context;
        return Render{
            .alloc = alloc,
            .context = context,
            .logger = logger,

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

        drawFrame(self, dt);
    }

    fn drawFrame(self: *Render, delta_time: f32) void {
        _ = delta_time;

        c.BeginDrawing();
        defer c.EndDrawing();

        c.ClearBackground(c.BLACK);

        {
            const DrawIt = _component.MultiIterator(.{ _texture.TextureObject, _text_field.TextField });
            const IdUnionTags = @typeInfo(DrawIt.IdUnion).@"union".tag_type.?;
            const tag_texture_object = @field(IdUnionTags, DrawIt.fieldName(_texture.TextureObject));
            const tag_text_field = @field(IdUnionTags, DrawIt.fieldName(_text_field.TextField));

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
                }
            }
        }

        c.DrawFPS(10, 10);

        self.draw_count +|= 1;

        var frame_str_buffer: [31]u8 = undefined;
        const frame_str = std.fmt.bufPrintZ(&frame_str_buffer, "Frame: {d}", .{self.draw_count}) catch unreachable;
        c.DrawText(frame_str, 10, 28, 10, c.GREEN);
    }
};

pub fn renderThread(alloc: std.mem.Allocator, logger: *_logging.Logger, context: *GameContext) void {
    log.info("Starting render thread", .{});
    var render = Render.init(alloc, logger, context);
    log.debug("Initialized Render", .{});
    context.render = &render;
    log.debug("Linked Render context", .{});
    defer {
        log.debug("Render deinit and cleanup", .{});
        if (context.render == &render) {
            context.render = null;
        }
        render.deinit();
    }
    render.createWindow(1600, 900, "Game Window", 60);
    log.debug("Created game window", .{});
    _texture.loadTextures();
    render.state = .Running;
    log.debug("Loaded textures", .{});
    while (!c.WindowShouldClose() and render.state != .Stopping) {
        render.updateLoop();
    }
}
