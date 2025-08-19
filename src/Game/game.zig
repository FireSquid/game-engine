const std = @import("std");
const log = std.log.scoped(.game);

const c = @import("../c.zig");

const PRNG = std.Random.DefaultPrng;

const _string = @import("../string_util.zig");

const GameContext = @import("../game_context.zig").GameContext;

pub const _gamestate = @import("gameState.zig");
const GameState = _gamestate.GameState;

pub const _gameAction = @import("gameAction.zig");
pub const CreateGameAction = _gameAction.GameAction;

pub const _player = @import("../Player/player.zig");
const Player = _player.Player;
const PlayerId = _player.PlayerId;

pub const _entity = @import("../Entity/entity.zig");
const _component = @import("../Component/component.zig");

pub const _planet = @import("../Entity/planet.zig");
const Planet = _planet.Planet;

pub const _ship = @import("../Entity/ship.zig");
const Ship = _ship.Ship;

pub const _permissions = @import("../Player/permissions.zig");
const Permissions = _permissions.Permissions;

pub const _logging = @import("../Debugging/logging.zig");
const Logger = _logging.Logger;

pub const _terminal = @import("../Terminal/terminal.zig");
const Terminal = _terminal.Terminal;

pub const _texture = @import("../Component/texture.zig");
const _position = @import("../Component/position.zig");
const _text_field = @import("../Component/text_field.zig");

const t_planetCount = 5;
const t_planetLinkCount = 7;
const t_planetLinkDist = .{ .min = 1, .max = 4 };

pub var activeGame: ?Game = undefined;

pub const Game = struct {
    alloc: std.mem.Allocator,
    context: *GameContext,

    active_state: GameState,
    previous_state: GameState, // For verifying network sync on state transitions

    players: std.ArrayList(Player),
    next_player_id: PlayerId,

    planets: std.ArrayList(_entity.TaggedEntityId),

    turn: usize,

    debug_mode: bool,
    logger: ?Logger,

    rng: PRNG,

    action_context: ?_gameAction.ActionContext,
    t_debug_player: ?Player,

    pub fn init(alloc: std.mem.Allocator, debug_enabled: bool, logger: ?Logger, context: *GameContext) Game {
        return Game{
            .alloc = alloc,
            .context = context,

            .active_state = GameState.lobby,
            .previous_state = GameState.none,

            .players = std.ArrayList(Player).init(alloc),
            .next_player_id = 1,

            .planets = std.ArrayList(_entity.TaggedEntityId).init(alloc),

            .turn = 1,

            .debug_mode = debug_enabled,
            .logger = logger,

            .rng = PRNG.init(@as(u64, @bitCast(std.time.milliTimestamp()))),

            .action_context = null,
            .t_debug_player = if (debug_enabled) Player.initWithPermissions(alloc, 999999, "DEBUG_PLAYER", _permissions.debug_permissions) else null,
        };
    }

    pub fn deinit(self: *Game) void {
        for (self.players.items) |player| {
            player.deinit();
        }

        self.players.deinit();
        self.planets.deinit();

        if (self.t_debug_player) |*debug_player| {
            debug_player.deinit();
        }
    }

    pub fn addNewPlayer(self: *Game, name: []const u8, permissions: Permissions) PlayerId {
        const id = self.next_player_id;
        self.next_player_id += 1;

        self.players.append(Player.initWithPermissions(self.alloc, id, name, permissions)) catch unreachable;

        log.info("New player added (name: {s}, id: {d}, total: {d})", .{ name, id, self.players.items.len });

        return id;
    }

    pub fn displayState(self: Game, term: Terminal) !void {
        try term.addSection("Game State", .cyan, true);
        term.setColor(.cyan);
        var state_buffer: [128]u8 = undefined;

        const state_string = std.fmt.bufPrint(&state_buffer, "state: {s}", .{@tagName(self.active_state)}) catch unreachable;
        try term.outputLine(state_string);

        const player_count_string = std.fmt.bufPrint(&state_buffer, "player count: : {d}", .{self.players.items.len}) catch unreachable;
        try term.outputLine(player_count_string);

        try term.outputLine("");

        switch (self.active_state) {
            .lobby => {
                try term.outputLine("Players:");
                for (self.players.items) |player| {
                    var player_buffer: [128]u8 = undefined;
                    switch (player.ready) {
                        true => term.setColor(.green),
                        false => term.setColor(.red),
                    }
                    const player_string = std.fmt.bufPrint(&player_buffer, "] {s}", .{player.name}) catch unreachable;
                    try term.outputLine(player_string);
                }
                try term.outputLine("");
            },
            else => {
                try term.outputLine("Planets:");
                var planet_buffer: [128]u8 = undefined;
                for (self.planets.items) |planet_id| {
                    const planet_name = _planet.getPlanetName(self.alloc, planet_id);
                    defer if (planet_name) |pn| self.alloc.free(pn);

                    const planet_string = std.fmt.bufPrint(&planet_buffer, "] {s}", .{planet_name orelse "MISSING-NAME"}) catch unreachable;
                    try term.outputLine(planet_string);
                }
                try term.outputLine("");
            },
        }
    }

    pub fn displayPlanetState(_: Game, _: Terminal, _: _entity.TaggedEntityId) !void {
        std.debug.panic("Not Implemented.", .{});
    }

    pub fn advanceState(self: *Game) bool {
        const current_state = self.active_state;
        switch (self.active_state) {
            .lobby => {
                self.lobbyStart();
            },
            .setup => {
                self.setupGame();
            },
            .wait_orders => {
                self.active_state = .turn_end;
            },
            .turn_end => {
                if (self.turn >= 5) {
                    self.active_state = .ending;
                } else {
                    self.active_state = .wait_orders;
                    self.turn += 1;
                }
            },
            else => {
                log.err("Missing a state transition for state '{s}'", .{@tagName(self.active_state)});
            },
        }

        if (current_state == self.active_state) {
            return false;
        } else {
            self.previous_state = current_state;
            log.info("Game: State transition from <{s}> to <{s}>", .{ @tagName(self.previous_state), @tagName(self.active_state) });
            return true;
        }
    }

    fn lobbyStart(self: *Game) void {
        if (self.players.items.len == 0) {
            log.warn("Cannot start a game with 0 players", .{});
            return;
        }

        for (self.players.items) |player| {
            if (!player.ready) {
                log.warn("Player '{s}' is not ready to start.", .{player.name});
                return;
            }
        }

        self.active_state = .setup;
    }

    fn setupGame(self: *Game) void {
        self.generatePlanets();

        self.active_state = .wait_orders;
    }

    fn generatePlanets(self: *Game) void {
        const comp_lock_types = .{ _entity.Entity, _texture.TextureObject, _text_field.TextField, _position.Position };
        _component.multiLock(comp_lock_types);
        defer _component.multiUnlock(comp_lock_types);

        for (0..t_planetCount) |i| {
            const name = _string.randomAlphaNum("AAANN");
            const pos = _position.new(@floatFromInt(300 + i * 300), 500);
            const fg_color = c.ColorFromHSV(self.rng.random().float(f32) * 360, self.rng.random().float(f32) * 0.2 + 0.8, self.rng.random().float(f32) * 0.2 + 0.8);
            const bg_color = c.ColorFromHSV(self.rng.random().float(f32) * 360, self.rng.random().float(f32) * 0.2 + 0.8, self.rng.random().float(f32) * 0.2 + 0.8);
            log.debug("Appending Planet: {d}", .{i});
            log.debug("Name: {s}", .{name});
            log.debug("Position: {}", .{pos});
            log.debug("FG Color: {}", .{fg_color});
            log.debug("BG Color: {}", .{bg_color});
            self.planets.append(_planet.createPlanet(self.alloc, &name, pos.vec, fg_color, bg_color)) catch unreachable;
            log.debug("Appended Planet: {d}", .{i});
        }
    }

    /// args:
    ///  - self: *Game
    ///  - set_ready: bool
    pub const actionSetPlayerReadyState = CreateGameAction(.none, @TypeOf(setPlayerReadyState), setPlayerReadyState);
    fn setPlayerReadyState(self: *Game, set_ready: bool) bool {
        if (self.active_state != .lobby) {
            log.warn("Can't set player ready state when not in the lobby.", .{});
            return false;
        }

        if (self.action_context) |context| {
            context.player.ready = set_ready;
            return true;
        }

        log.warn("Can't update the ready state for player because the action context is missing", .{});
        return false;
    }

    /// args:
    ///  - self: *Game
    ///  - player_id: PlayerId
    ///  - set_ready: bool
    pub const actionForcePlayerReadyState = CreateGameAction(.debug, @TypeOf(forcePlayerReadyState), forcePlayerReadyState);
    fn forcePlayerReadyState(self: *Game, player_id: PlayerId, set_ready: bool) bool {
        if (self.active_state != .lobby) {
            log.warn("Can't force player ready state {d} when not in the lobby.", .{player_id});
        }

        for (self.players.items) |*player| {
            if (player.id == player_id) {
                player.ready = set_ready;
                return true;
            }
        }

        log.warn("Can't force the ready state for player {d} - player with that id is missing.", .{player_id});
        return false;
    }
};

test {
    @import("std").testing.refAllDecls(@This());
}
