const std = @import("std");
const log = std.log.scoped(.bounds);

const c = @import("../c.zig");

const _callback = @import("../Component/callback.zig");
const _position = @import("../Component/position.zig");

const _ui = @import("../ui.zig");

const _entity = @import("../Entity/entity.zig");

const CallbackArgs = struct {
    click: ?_callback.Callback,
};

comptime {
    @import("../Component/component.zig").registerComponent(Bounds);
}
pub const Bounds = struct {
    entity: _entity.TaggedEntityId,
    mode: _ui.Mode,
    dim: c.Vector2,
    click_callback: ?_callback.Callback,

    pub fn init(entity: _entity.TaggedEntityId, dim: c.Vector2, mode: _ui.Mode, callbacks: CallbackArgs) Bounds {
        return Bounds{
            .entity = entity,
            .mode = mode,
            .dim = dim,
            .click_callback = callbacks.click,
        };
    }

    pub fn within(self: Bounds, point: c.Vector2) bool {
        var self_entity_ref = self.entity.read() orelse null;
        defer if (self_entity_ref) |*se_ref| se_ref.close();
        const pos = if (self_entity_ref) |se_ref| se_ref.comp.globalPosition() else _position.origin;
        const align_pos = _ui.getAlignPosition(self.mode, pos, self.dim.x, self.dim.y).vec;

        const in_x = point.x >= align_pos.x and point.x <= (align_pos.x + self.dim.x);
        const in_y = point.y >= align_pos.y and point.y <= (align_pos.y + self.dim.y);

        return in_x and in_y;
    }

    pub fn handleClick(self: Bounds, mouse_vec: c.Vector2) void {
        if (self.click_callback) |callback| {
            if (self.within(mouse_vec)) {
                log.debug("Handling click callback [{}]", .{callback});
                log.debug("Callback Entity [{}]", .{self.entity});
                callback.call(self.entity);
            }
        }
    }
};
