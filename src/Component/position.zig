const std = @import("std");
const log = std.log.scoped(.position);
const c = @import("../c.zig");

const _entity = @import("../Entity/entity.zig");

comptime {
    @import("component.zig").registerComponent(Position);
}
pub const Position = struct {
    vec: c.Vector2,

    pub const thread_safe = true;

    pub fn add(self: Position, other: anytype) Position {
        if (@TypeOf(other) == Position) {
            return Position{ .vec = c.Vector2{ .x = self.vec.x + other.vec.x, .y = self.vec.y + other.vec.y } };
        }
        return Position{ .vec = c.Vector2{ .x = self.vec.x + other.x, .y = self.vec.y + other.y } };
    }

    pub fn toInt(self: Position, comptime IntType: type) struct { IntType, IntType } {
        return .{ @as(IntType, @intFromFloat(self.vec.x)), @as(IntType, @intFromFloat(self.vec.y)) };
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        _ = try writer.print("VEC[{d}, {d}]", .{ self.vec.x, self.vec.y });
    }
};

pub const origin = Position{ .vec = c.Vector2{ .x = 0.0, .y = 0.0 } };
pub fn fromVec(vec: c.Vector2) Position {
    return Position{ .vec = vec };
}
pub fn new(x: f32, y: f32) Position {
    return Position{ .vec = c.Vector2{ .x = x, .y = y } };
}
