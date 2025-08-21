const std = @import("std");
const log = std.log.scoped(.ui_frame);

const c = @import("../c.zig");

const _component = @import("../Component/component.zig");
const ID = _component.ComponentId(UiFrame);

const _position = @import("../Component/position.zig");
const _entity = @import("../Entity/entity.zig");

const _ui = @import("../ui.zig");
pub const Mode = _ui.Mode;

comptime {
    @import("component.zig").registerComponent(UiFrame);
}
pub const UiFrame = struct {
    entity: _entity.EntityId,
    depth: i32,
    dim: c.Vector2,
    fill_color: ?c.Color,
    line_color: ?c.Color,
    line_thick: f32,
    mode: Mode,

    pub const thread_safe = true;

    pub fn init(entity: _entity.EntityId, depth: i32, dim: c.Vector2, fill: ?c.Color, line: ?c.Color, thickness: f32, mode: Mode) UiFrame {
        std.debug.assert(fill != null or line != null);
        return UiFrame{
            .entity = entity,
            .depth = depth,
            .dim = dim,
            .fill_color = fill,
            .line_color = line,
            .line_thick = thickness,
            .mode = mode,
        };
    }

    pub fn draw(id: ID) void {
        var ui_frame_ref = id.read() orelse {
            log.warn("Missing UI frame (id: {d}) - Skipping Draw Step", .{id.id});
            return;
        };
        defer ui_frame_ref.close();

        const self = &ui_frame_ref.comp;

        log.debug("Draw Call", .{});

        var self_entity_ref = self.entity.read() orelse null;
        defer if (self_entity_ref) |*se_ref| se_ref.close();

        const pos = if (self_entity_ref) |se_ref| se_ref.comp.globalPosition() else _position.origin;
        const alignPos = _ui.getAlignPosition(self.mode, pos, self.dim.x, self.dim.y);

        if (self.fill_color) |fill| {
            c.DrawRectangleV(alignPos.vec, self.dim, fill);
        }
        if (self.line_color) |line| {
            const rect = c.Rectangle{
                .x = alignPos.vec.x,
                .y = alignPos.vec.y,
                .width = self.dim.x,
                .height = self.dim.y,
            };
            c.DrawRectangleLinesEx(rect, self.line_thick, line);
        }
    }
};
