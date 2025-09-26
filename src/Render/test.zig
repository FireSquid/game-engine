const std = @import("std");
const log = std.log.scoped(.render_test);

const c = @import("../c.zig");

const _entity = @import("../Entity/entity.zig");

const _callback = @import("../Component/callback.zig");

/// Utility function to test the rendering of different objects on program starup
pub fn runFullStartupTest(alloc: std.mem.Allocator) void {
    const _button = @import("../Entity/button.zig");

    const ctx_1 = _callback.Callback{
        .func = testButtonFn,
        .ctx = &TestButtonCtx{ .text = "'BTN1'" },
    };
    _ = _button.createTextButton(alloc, "Test Button 1", .{
        .text_size = 24,
        .pos = c.Vector2{ .x = 400, .y = 80 },
        //.dim = c.Vector2{ .x = 300, .y = 30 },
        .fill = c.DARKGRAY,
        .line = c.YELLOW,
        .line_thick = 3,
        .click = ctx_1,
    });

    const ctx_2 = _callback.Callback{
        .func = testButtonFn,
        .ctx = &TestButtonCtx{ .text = "'BTN2'" },
    };
    _ = _button.createTextButton(alloc, "Test Button 2", .{
        .text_size = 24,
        .pos = c.Vector2{ .x = 400, .y = 160 },
        //.dim = c.Vector2{ .x = 300, .y = 30 },
        .fill = c.DARKGRAY,
        .line = c.YELLOW,
        .line_thick = 3,
        .click = ctx_2,
    });
}

const TestButtonCtx = struct {
    text: []const u8,
};
fn testButtonFn(src_id: _entity.TaggedEntityId, ctx: *const anyopaque) void {
    const ctx_ptr: *const TestButtonCtx = @ptrCast(@alignCast(ctx));

    log.info("Test button pressed: (id: {d}, text: {s})", .{ src_id.id.id, ctx_ptr.text });
}
