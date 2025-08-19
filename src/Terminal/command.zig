const std = @import("std");

const log = std.log.scoped(.command);

pub const _terminal = @import("terminal.zig");
const Terminal = _terminal.Terminal;

pub const _game = @import("../Game/game.zig");
const Game = _game.Game;

pub const _player = @import("../Player/player.zig");

pub const _menu = @import("menu.zig");

pub const _permissions = @import("../Player/permissions.zig");

const buffer_size = 256;

pub const CommandError = error{
    MissingCommand,
    InvalidCommand,
    NotEnoughArguments,
    WrongArgumentType,
    CommandFailed,
    InvalidArgument,
};

const ParameterType = enum {
    int,
    number,
    string,
};

const ParameterValue = union(ParameterType) {
    int: i32,
    number: f32,
    string: []const u8,
};

const ParameterValues = std.StringHashMap(ParameterValue);

const CommandResult = struct {
    exit: bool,
};

pub const CommandParameter = struct { name: []const u8, datatype: ParameterType, required: bool };

const CommandCallback = *const fn (Terminal, ?ParameterValues) CommandError!CommandResult;

pub const Command = struct {
    base: []const u8,
    callback: CommandCallback,
    parameters: ?[]const CommandParameter,

    pub fn init(base: []const u8, callback: CommandCallback, parameters: ?[]const CommandParameter) Command {
        return Command{
            .base = base,
            .callback = callback,
            .parameters = parameters,
        };
    }

    pub fn matchBase(self: Command, base_str: []const u8) bool {
        return std.mem.eql(u8, self.base, base_str);
    }

    pub fn fetchParameters(self: Command, parameter_itr: *std.mem.TokenIterator(u8, .scalar), result_map: *ParameterValues) CommandError!void {
        for (self.parameters.?) |parameter| {
            if (parameter_itr.peek() == null) {
                if (parameter.required) {
                    log.warn("Missing a required argument for command. (cmd: '{s}', arg: '{s}')", .{ self.base, parameter.name });
                    return CommandError.NotEnoughArguments;
                } else {
                    return;
                }
            }

            const parameter_value = parseParameter(parameter, parameter_itr.next().?) catch |err| {
                if (err == CommandError.WrongArgumentType) {
                    log.warn("Wrong argument type for command. (cmd: '{s}', arg: '{s}', type: '{s}')", .{ self.base, parameter.name, @tagName(parameter.datatype) });
                }
                return err;
            };
            result_map.put(parameter.name, parameter_value) catch unreachable;
        }
    }

    fn parseParameter(parameter: CommandParameter, input_string: []const u8) CommandError!ParameterValue {
        if (input_string.len == 0) {
            return CommandError.MissingCommand;
        }

        switch (parameter.datatype) {
            .int => {
                return ParameterValue{ .int = std.fmt.parseInt(i32, input_string, 10) catch return CommandError.WrongArgumentType };
            },
            .number => {
                return ParameterValue{ .number = std.fmt.parseFloat(f32, input_string) catch return CommandError.WrongArgumentType };
            },
            .string => {
                return ParameterValue{ .string = input_string };
            },
        }
    }
};

pub fn processCmd(cmd: []const u8, term: Terminal) CommandError!CommandResult {
    var command_tokens = std.mem.tokenizeScalar(u8, cmd, ' ');

    const command_name = command_tokens.next() orelse return CommandError.MissingCommand;

    for (_menu.activeCommandMenu) |command| {
        if (command.matchBase(command_name)) {
            if (command.parameters == null) {
                return command.callback(term, null);
            } else {
                var parameter_values = ParameterValues.init(term.alloc);
                defer parameter_values.deinit();
                try command.fetchParameters(&command_tokens, &parameter_values);
                const result = command.callback(term, parameter_values);
                return result;
            }
        }
    }

    return CommandError.InvalidCommand;
}

pub fn printCommands(term: Terminal) !void {
    for (_menu.activeCommandMenu) |command| {
        var display_strings = std.ArrayList(u8).init(term.alloc);
        defer display_strings.deinit();

        var format_buffer: [buffer_size]u8 = undefined;
        try display_strings.appendSlice(try std.fmt.bufPrint(&format_buffer, "{s}", .{command.base}));

        if (command.parameters) |parameters| {
            for (parameters) |parameter| {
                var parameter_str: []u8 = undefined;
                switch (parameter.required) {
                    true => {
                        parameter_str = try std.fmt.bufPrint(&format_buffer, " <{s}>", .{parameter.name});
                    },
                    false => {
                        parameter_str = try std.fmt.bufPrint(&format_buffer, " [{s}]", .{parameter.name});
                    },
                }
                try display_strings.appendSlice(parameter_str);
            }
        }

        try term.outputLine(display_strings.items);
    }
}

pub fn createLobby(term: Terminal, params: ?ParameterValues) CommandError!CommandResult {
    if (_game.activeGame != null) {
        log.warn("Game has already been created", .{});
        term.setColor(.red);
        term.outputLine("Game already created") catch unreachable;
        return .{ .exit = false };
    }

    _game.activeGame = Game.init(term.alloc, true, term.logger, term.context);
    term.context.game = &_game.activeGame.?;
    _menu.activeCommandMenu = &_menu.lobbyMenu;

    _ = try gameState(term, params);

    return .{ .exit = false };
}

pub fn gameState(term: Terminal, params: ?ParameterValues) CommandError!CommandResult {
    _ = params;

    if (_game.activeGame) |game| {
        game.displayState(term) catch unreachable;
    } else {
        log.warn("Game has not been created", .{});
        term.setColor(.red);
        term.outputLine("Game not started") catch unreachable;
        term.outputLine("") catch unreachable;
    }

    return .{ .exit = false };
}

pub fn planetState(term: Terminal, params: ?ParameterValues) CommandError!CommandResult {
    const _params = params.?;

    if (_game.activeGame) |game| {
        const planet_name_arg = _params.get("planet_name") orelse {
            term.setColor(.red);
            term.outputLine("planet_name is required") catch unreachable;
            term.outputLine("") catch unreachable;
            return CommandError.InvalidArgument;
        };
        const planet_name = switch (planet_name_arg) {
            .string => planet_name_arg.string,
            else => return CommandError.InvalidArgument,
        };
        _ = game;
        _ = planet_name;
        std.debug.panic("Not Implemented./n", .{});
        //const planet_id = game.getPlanetIdFromName(planet_name) orelse return CommandError.CommandFailed;
        //game.displayPlanetState(term, planet_id) catch return CommandError.CommandFailed;
    } else {
        log.warn("Game has not been created", .{});
        term.setColor(.red);
        term.outputLine("Game not started") catch unreachable;
        term.outputLine("") catch unreachable;
    }

    return .{ .exit = false };
}

pub fn addPlayer(term: Terminal, params: ?ParameterValues) CommandError!CommandResult {
    const _params = params.?;

    if (_game.activeGame) |*game| {
        const player_name_arg = _params.get("player_name") orelse {
            term.setColor(.red);
            term.outputLine("player_name is required") catch unreachable;
            term.outputLine("") catch unreachable;
            return CommandError.InvalidArgument;
        };
        const player_name = switch (player_name_arg) {
            .string => player_name_arg.string,
            else => return CommandError.InvalidArgument,
        };

        _ = game.addNewPlayer(player_name, _permissions.debug_permissions);

        _ = try gameState(term, params);
    } else {
        log.warn("Game has not been created", .{});
        term.setColor(.red);
        term.outputLine("Game not started") catch unreachable;
        term.outputLine("") catch unreachable;
    }
    return .{ .exit = false };
}

pub fn readyAsPlayer(term: Terminal, params: ?ParameterValues) CommandError!CommandResult {
    const _params = params.?;

    if (_game.activeGame) |*game| {
        const player_name_arg = _params.get("player_name") orelse {
            term.setColor(.red);
            term.outputLine("player_name is required") catch unreachable;
            term.outputLine("") catch unreachable;
            return CommandError.InvalidArgument;
        };
        const player_name = switch (player_name_arg) {
            .string => player_name_arg.string,
            else => return CommandError.InvalidArgument,
        };

        const player: ?*_player.Player = for (game.players.items) |*player| {
            if (std.mem.eql(u8, player.name, player_name)) {
                break player;
            }
        } else null;

        if (player) |p| {
            const action_result = Game.actionSetPlayerReadyState.execute(.{ .player = p }, .{ game, true }) catch {
                term.setColor(.red);
                term.outputLine("Somehow we can't ready up\n") catch unreachable;
                return CommandError.CommandFailed;
            };

            if (action_result) {
                term.setColor(.green);
                term.outputLine("Player is now ready\n") catch unreachable;
            } else {
                term.setColor(.red);
                term.outputLine("Could not set player as ready\n") catch unreachable;
            }
        } else {
            term.setColor(.red);
            term.outputLine("Player not found\n") catch unreachable;
        }
    } else {
        log.warn("Game has not been created", .{});
        term.setColor(.red);
        term.outputLine("Game not started\n") catch unreachable;
    }

    _ = try gameState(term, params);

    return .{ .exit = false };
}

pub fn forceReady(term: Terminal, params: ?ParameterValues) CommandError!CommandResult {
    const _params = params.?;

    if (_game.activeGame) |*game| {
        const player_name_arg = _params.get("player_name") orelse {
            term.setColor(.red);
            term.outputLine("player_name is required") catch unreachable;
            term.outputLine("") catch unreachable;
            return CommandError.CommandFailed;
        };
        const player_name = switch (player_name_arg) {
            .string => player_name_arg.string,
            else => return CommandError.InvalidArgument,
        };

        const player: _player.PlayerId = for (game.players.items) |player| {
            if (std.mem.eql(u8, player.name, player_name)) {
                break player.id;
            }
        } else {
            term.setColor(.red);
            term.outputLine("Player not found\n") catch unreachable;
            return CommandError.InvalidArgument;
        };

        const action_result: bool = action: {
            if (game.t_debug_player) |*debug_player| {
                break :action Game.actionForcePlayerReadyState.execute(.{ .player = debug_player }, .{ game, player, true }) catch {
                    term.setColor(.red);
                    term.outputLine("Server can't force player ready state due to lack of debug permissions\n") catch unreachable;
                    return CommandError.CommandFailed;
                };
            } else {
                term.setColor(.red);
                term.outputLine("Server can't force player ready state while not in debug mode\n") catch unreachable;
                return CommandError.CommandFailed;
            }
        };

        if (action_result) {
            term.setColor(.green);
            term.outputLine("Player is now ready\n") catch unreachable;
        } else {
            term.setColor(.red);
            term.outputLine("Could not set player as ready\n") catch unreachable;
        }
    } else {
        log.warn("Game has not been created", .{});
        term.setColor(.red);
        term.outputLine("Game not started\n") catch unreachable;
    }

    _ = try gameState(term, params);

    return .{ .exit = false };
}

pub fn debugSetup(term: Terminal, params: ?ParameterValues) CommandError!CommandResult {
    const game = &_game.activeGame.?;

    const pA = game.addNewPlayer("Player_1", _permissions.debug_permissions);
    const pB = game.addNewPlayer("Player_2", _permissions.debug_permissions);

    std.debug.assert(pA > 0);
    std.debug.assert(pB > 0);

    _ = Game.actionForcePlayerReadyState.execute(.{ .player = &game.t_debug_player.? }, .{ game, pA, true }) catch {};
    _ = Game.actionForcePlayerReadyState.execute(.{ .player = &game.t_debug_player.? }, .{ game, pB, true }) catch {};

    _ = try gameState(term, params);

    return .{ .exit = false };
}

pub fn next(term: Terminal, params: ?ParameterValues) CommandError!CommandResult {
    if (_game.activeGame) |*game| {
        const advanced = game.advanceState();

        if (advanced) {
            _menu.activeCommandMenu = switch (game.active_state) {
                .lobby => &_menu.lobbyMenu,
                .setup => &_menu.setupMenu,
                .wait_orders => &_menu.ordersMenu,
                else => _menu.activeCommandMenu,
            };
        }

        _ = try gameState(term, params);
    } else {
        log.warn("Game has not been created", .{});
        term.setColor(.red);
        term.outputLine("Game not started") catch unreachable;
        term.outputLine("") catch unreachable;
    }
    return .{ .exit = false };
}

pub fn close(term: Terminal, params: ?ParameterValues) CommandError!CommandResult {
    _ = params;
    _ = term;

    if (_game.activeGame != null) {
        _game.activeGame.?.deinit();
        _game.activeGame = null;
    }

    _menu.activeCommandMenu = &_menu.baseMenu;

    return .{ .exit = false };
}

pub fn displayLogs(term: Terminal, params: ?ParameterValues) CommandError!CommandResult {
    const _params = params.?;

    const page_arg = _params.get("page") orelse ParameterValue{ .int = 1 };
    const page_num = switch (page_arg) {
        .int => page_arg.int - 1,
        else => return CommandError.InvalidArgument,
    };

    if (page_num < 0) {
        return CommandError.InvalidArgument;
    }

    term.displayLogPage(@intCast(page_num)) catch return CommandError.CommandFailed;

    return .{ .exit = false };
}

pub fn exit(term: Terminal, params: ?ParameterValues) CommandError!CommandResult {
    _ = term;
    _ = params;

    if (_game.activeGame != null) {
        _game.activeGame.?.deinit();
        _game.activeGame = null;
    }
    return .{ .exit = true };
}

test {
    @import("std").testing.refAllDecls(@This());
}
