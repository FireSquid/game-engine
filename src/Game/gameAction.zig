const std = @import("std");

const _permissions = @import("../Player/permissions.zig");
const _player = @import("../Player/player.zig");
const _game = @import("game.zig");

pub const ActionError = error{
    PermissionDenied,
};

pub fn GameAction(
    comptime permission_level: _permissions.Permission,
    comptime ActionFn: type,
    comptime action: ActionFn,
) type {
    const ReturnType = @typeInfo(ActionFn).@"fn".return_type orelse void;
    return struct {
        pub fn execute(context: ActionContext, args: anytype) ActionError!ReturnType {
            if (context.player.hasPermission(permission_level)) {
                if (@TypeOf(args[0]) != *_game.Game) {
                    @compileError(std.fmt.comptimePrint("GameAction:{s} - the first arg must be '*Game'", .{@typeName(ActionFn)}));
                }
                args[0].action_context = context;
                return @call(.auto, action, args);
            } else {
                return ActionError.PermissionDenied;
            }
        }
    };
}

pub const ActionContext = struct {
    player: *_player.Player,
};
