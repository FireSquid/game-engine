const std = @import("std");

pub const _command = @import("command.zig");
const Command = _command.Command;
const CommandParameter = _command.CommandParameter;

pub var activeCommandMenu: []const Command = &baseMenu;

pub const baseMenu = [_]Command{
    cmdExit,
    cmdLogs,
    cmdLobby,
};

pub const lobbyMenu = [_]Command{
    cmdExit,
    cmdLogs,
    cmdState,
    cmdAddPlayer,
    cmdReadyAsPlayer,
    cmdForceReady,
    cmdDebugSetup,
    cmdNext,
    cmdClose,
};

pub const setupMenu = [_]Command{
    cmdExit,
    cmdLogs,
    cmdState,
    cmdNext,
};

pub const ordersMenu = [_]Command{
    cmdExit,
    cmdLogs,
    cmdState,
    cmdPlanetState,
    cmdNext,
};

const cmdExit = Command.init(
    "exit",
    _command.exit,
    null,
);
const cmdLogs = Command.init(
    "logs",
    _command.displayLogs,
    &.{
        CommandParameter{ .name = "page", .datatype = .int, .required = false },
    },
);
const cmdLobby = Command.init(
    "lobby",
    _command.createLobby,
    null,
);
const cmdState = Command.init(
    "state",
    _command.gameState,
    null,
);
const cmdPlanetState = Command.init(
    "showPlanet",
    _command.planetState,
    &.{
        CommandParameter{ .name = "planet_name", .datatype = .string, .required = true },
    },
);
const cmdAddPlayer = Command.init(
    "addPlayer",
    _command.addPlayer,
    &.{
        CommandParameter{ .name = "player_name", .datatype = .string, .required = true },
    },
);
const cmdReadyAsPlayer = Command.init(
    "readyPlayer",
    _command.readyAsPlayer,
    &.{
        CommandParameter{ .name = "player_name", .datatype = .string, .required = true },
    },
);
const cmdForceReady = Command.init(
    "forceReady",
    _command.forceReady,
    &.{
        CommandParameter{ .name = "player_name", .datatype = .string, .required = true },
    },
);
const cmdDebugSetup = Command.init(
    "debugSetup",
    _command.debugSetup,
    null,
);
const cmdNext = Command.init(
    "next",
    _command.next,
    null,
);
const cmdClose = Command.init(
    "close",
    _command.close,
    null,
);

test {
    @import("std").testing.refAllDecls(@This());
}
