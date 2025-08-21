const std = @import("std");

const _entity = @import("../Entity/entity.zig");

pub const Callback = struct {
    func: *const fn (src_id: _entity.TaggedEntityId, ctx: *const anyopaque) void,
    ctx: *const anyopaque,

    pub fn call(self: @This(), src_id: _entity.TaggedEntityId) void {
        self.func(src_id, self.ctx);
    }
};
