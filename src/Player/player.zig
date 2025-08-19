const std = @import("std");

pub const _permissions = @import("permissions.zig");
const Permissions = _permissions.Permissions;
const Permission = _permissions.Permission;

pub const _game = @import("../Game/game.zig");

pub const _ship = @import("../Entity/ship.zig");
const Ship = _ship.Ship;

pub const _planet = @import("../Entity/planet.zig");

pub const Player = struct {
    alloc: std.mem.Allocator,

    id: PlayerId,
    name: []const u8,
    permissions: Permissions,

    t_ship: ?*Ship,

    ready: bool,

    pub fn hasPermission(self: Player, permission: Permission) bool {
        return Permission.has(self.permissions, permission);
    }

    pub fn initWithPermissions(alloc: std.mem.Allocator, id: PlayerId, name: []const u8, permissions: Permissions) Player {
        const _name = alloc.alloc(u8, name.len) catch unreachable;
        errdefer alloc.free(_name);
        @memcpy(_name, name);

        return Player{
            .alloc = alloc,

            .id = id,
            .name = _name,
            .permissions = permissions,

            .t_ship = null,

            .ready = false,
        };
    }

    pub fn deinit(self: Player) void {
        self.alloc.free(self.name);
    }

    pub fn createShip(self: *Player, location: _game.PlanetId) !void {
        self.t_ship = try Ship.create(location);
    }
};

pub const PlayerId = usize;

test {
    @import("std").testing.refAllDecls(@This());
}
