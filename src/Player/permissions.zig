const std = @import("std");
const _test = std.testing;

pub const Permissions = usize;

pub const debug_permissions = Permission.createPermissions(&[_]Permission{ .debug, .host, .lobby });
pub const host_permissions = Permission.createPermissions(&[_]Permission{ .host, .lobby });
pub const min_permissions = 0;

pub const Permission = enum(Permissions) {
    none = 0,
    debug = 1 << 0, // debug options
    host = 1 << 1, // start,stop,pause,save,load
    lobby = 1 << 2, // kick,invite,password

    pub fn has(permissions: Permissions, permission: Permission) bool {
        if (permission == .none) return true;
        return (permissions & @intFromEnum(permission) != 0);
    }

    pub fn createPermissions(permissions: []const Permission) Permissions {
        var pms: Permissions = 0;

        for (permissions) |p| {
            pms |= @intFromEnum(p);
        }

        return pms;
    }
};

test "Permission Validation" {
    const none = 0;
    const all = Permission.createPermissions(&[_]Permission{ .debug, .host, .lobby });
    const admin = Permission.createPermissions(&[_]Permission{ .host, .lobby });

    try _test.expect(Permission.has(all, .debug));
    try _test.expect(!Permission.has(admin, .debug));
    try _test.expect(!Permission.has(none, .debug));

    try _test.expect(Permission.has(all, .host));
    try _test.expect(Permission.has(admin, .host));
    try _test.expect(!Permission.has(none, .host));

    try _test.expect(Permission.has(all, .lobby));
    try _test.expect(Permission.has(admin, .lobby));
    try _test.expect(!Permission.has(none, .lobby));
}

test {
    @import("std").testing.refAllDecls(@This());
}
