const std = @import("std");

const log = std.log.scoped(.ship_entity);

pub const _entity = @import("entity.zig");

pub const _planet = @import("planet.zig");

pub const _game = @import("../Game/game.zig");

pub const Ship = struct {};

test {
    @import("std").testing.refAllDecls(@This());
}
