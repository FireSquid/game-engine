const std = @import("std");
const log = std.log.scoped(.ui);

const _position = @import("Component/position.zig");

pub const Mode = enum {
    LEFT_TOP,
    LEFT_MID,
    LEFT_BOT,
    CENTER_TOP,
    CENTER_MID,
    CENTER_BOT,
    RIGHT_TOP,
    RIGHT_MID,
    RIGHT_BOT,

    pub fn left(self: Mode) bool {
        return self == .LEFT_BOT or self == .LEFT_MID or self == .LEFT_TOP;
    }
    pub fn center(self: Mode) bool {
        return self == .CENTER_BOT or self == .CENTER_MID or self == .CENTER_TOP;
    }
    pub fn right(self: Mode) bool {
        return self == .RIGHT_BOT or self == .RIGHT_MID or self == .RIGHT_TOP;
    }

    pub fn top(self: Mode) bool {
        return self == .LEFT_TOP or self == .CENTER_TOP or self == .RIGHT_TOP;
    }
    pub fn mid(self: Mode) bool {
        return self == .LEFT_MID or self == .CENTER_MID or self == .RIGHT_MID;
    }
    pub fn bot(self: Mode) bool {
        return self == .LEFT_BOT or self == .CENTER_BOT or self == .RIGHT_BOT;
    }
};

pub fn getAlignPosition(mode: Mode, pos: _position.Position, width: f32, height: f32) _position.Position {
    var x: f32 = 0;
    if (mode.center()) {
        x = -(width / 2.0);
    } else if (mode.right()) {
        x = -width;
    }

    var y: f32 = 0;
    if (mode.mid()) {
        y = -(height / 2.0);
    } else if (mode.bot()) {
        y = -height;
    }

    return pos.add(_position.new(x, y));
}
