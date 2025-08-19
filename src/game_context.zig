const std = @import("std");

const c = @import("../c.zig");

const _game = @import("Game/game.zig");
const _render = @import("Render/render.zig");
const _terminal = @import("Terminal/terminal.zig");

pub const GameContext = struct {
    game: ?*_game.Game,
    render: ?*_render.Render,
    terminal: ?*_terminal.Terminal,
};
