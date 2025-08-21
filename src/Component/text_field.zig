const std = @import("std");
const log = std.log.scoped(.text_field);

const c = @import("../c.zig");

const _component = @import("../Component/component.zig");
const ID = _component.ComponentId(TextField);

const _entity = @import("../Entity/entity.zig");
const _position = @import("../Component/position.zig");

const _ui = @import("../ui.zig");
pub const Mode = _ui.Mode;

pub var draw_wire_debug: bool = false;

comptime {
    @import("component.zig").registerComponent(TextField);
}
pub const TextField = struct {
    entity: _entity.EntityId,
    alloc: std.mem.Allocator,
    depth: i32,
    cursor: ?u32,
    size: u32,
    text: std.ArrayList(u8),
    mode: Mode,

    pub const thread_safe = true;

    pub fn init(alloc: std.mem.Allocator, entity: _entity.EntityId, depth: i32, size: u32, mode: Mode) TextField {
        std.debug.assert(size < 99);
        return TextField{
            .entity = entity,
            .alloc = alloc,
            .depth = depth,
            .cursor = null,
            .size = size,
            .text = std.ArrayList(u8).init(alloc),
            .mode = mode,
        };
    }

    pub fn deinit(self: TextField) void {
        self.text.deinit();
    }

    pub fn copy(self: TextField) TextField {
        return TextField{
            .entity = self.entity,
            .alloc = self.alloc,
            .depth = self.depth,
            .cursor = self.cursor,
            .size = self.size,
            .text = self.text.clone() catch unreachable,
            .mode = self.mode,
        };
    }

    pub fn componentOrder(lhs: TextField, rhs: TextField) bool {
        return (lhs.depth > rhs.depth);
    }

    pub fn draw(id: ID) void {
        var text_field_ref = id.read() orelse {
            log.warn("Missing text field (id: {d}) - Skipping Draw Step", .{id.id});
            return;
        };
        defer text_field_ref.close();

        const self = &text_field_ref.comp;

        log.debug("Draw Call", .{});
        // TODO: Replace the allocator for the text with an arena that lasts for a frame and is freed at the end of the frame
        const c_text = std.fmt.allocPrintZ(self.alloc, "{s}", .{self.text.items}) catch unreachable;
        defer self.alloc.free(c_text);

        var self_entity_ref = self.entity.read() orelse null;
        defer if (self_entity_ref) |*se_ref| se_ref.close();

        const pos = if (self_entity_ref) |se_ref| se_ref.comp.globalPosition() else _position.origin;
        const _size: c_int = @intCast(self.size);
        const _width = c.MeasureText(c_text, _size);

        const alignPos = _ui.getAlignPosition(self.mode, pos, @floatFromInt(_width), @floatFromInt(_size));

        const _x, const _y = alignPos.toInt(c_int);
        c.DrawText(c_text, _x, _y, _size, c.WHITE);

        if (draw_wire_debug) {
            const margin = 3;
            c.DrawRectangleLines(_x - margin, _y - margin, _width + margin * 2, _size + margin * 2, c.WHITE);
        }
    }
};
