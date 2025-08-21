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
    rect: c.Rectangle,
    click_callback: ?_callback.Callback,

    pub fn init(entity: _entity.TaggedEntityId, pos: c.Vector2, dim: c.Vector2, rect_mode: _ui.Mode, callbacks: CallbackArgs) Bounds {
        const bounds_pos = _ui.getAlignPosition(rect_mode, _position.fromVec(pos), dim.x, dim.y).vec;
        const bounds_rect = c.Rectangle{ .x = bounds_pos.x, .y = bounds_pos.y, .width = dim.x, .height = dim.y };
        return Bounds{
            .entity = entity,
            .rect = bounds_rect,
            .click_callback = callbacks.click,
        };
    }

    pub fn within(self: Bounds, point: c.Vector2) bool {
        const in_x = point.x >= self.rect.x and point.x <= (self.rect.x + self.rect.width);
        const in_y = point.y >= self.rect.y and point.y <= (self.rect.y + self.rect.height);

        return in_x and in_y;
    }

    pub fn handleClick(self: Bounds, mouse_vec: c.Vector2) void {
        if (self.click_callback) |callback| {
            if (self.within(mouse_vec)) {
                callback.call(self.entity);
            }
        }
    }
};
