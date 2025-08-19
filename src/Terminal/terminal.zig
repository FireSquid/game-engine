const std = @import("std");
const log = std.log.scoped(.terminal);

const GameContext = @import("../game_context.zig").GameContext;

pub const _game = @import("../Game/game.zig");
pub const Game = _game.Game;

const _logging = @import("../Debugging/logging.zig");
const Logger = _logging.Logger;

pub const _command = @import("command.zig");
const CommandError = _command.CommandError;

const buffer_size = 256;

const log_page_size = 20;

pub const SGRColor = enum(u8) {
    black = 30,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    white = 37,

    pub fn val(self: SGRColor) u8 {
        return @intFromEnum(self);
    }
};

pub const EscCmd = enum(u8) {
    cursor_up = 'A',
    cursor_down = 'B',
    cursor_forward = 'C',
    cursor_back = 'D',
    cursor_next_line = 'E',
    cursor_prev_line = 'F',
    cursor_horz_abs = 'G',
    cursor_to_pos = 'H',
    cursor_erase_disp = 'J',
    cursor_erase_line = 'K',
    scroll_up = 'S',
    scroll_down = 'T',
    cursor_save = 's',
    cursor_load = 'u',
    sgr_mode = 'm',

    pub fn val(self: EscCmd) u8 {
        return @intFromEnum(self);
    }
};

pub const Terminal = struct {
    context: *GameContext,

    in: std.fs.File,
    out: std.fs.File,

    alloc: std.mem.Allocator,

    height: u32,
    width: u32,

    logger: Logger,

    pub fn initWithStdIO(alloc: std.mem.Allocator, height: u32, width: u32, context: *GameContext) Terminal {
        return Terminal{
            .context = context,

            .in = std.io.getStdIn(),
            .out = std.io.getStdOut(),

            .alloc = alloc,

            .height = height,
            .width = width,

            .logger = Logger.init(alloc),
        };
    }

    pub fn deinit(self: Terminal) void {
        self.logger.deinit();
    }

    pub fn clearScreen(self: Terminal) void {
        self.resetSGR();
        self.escape(.cursor_erase_disp, "2");
    }

    pub fn promptCommand(self: Terminal) !bool {
        try self.addSection("Actions", null, true);
        try _command.printCommands(self);
        try self.outputLine("");

        var cmd_buf: [buffer_size]u8 = undefined;

        const usr_cmd = try self.inputBar("Enter Command: ", &cmd_buf);
        log.info("Received User Cmd <{s}>", .{usr_cmd});

        const cmd_result = _command.processCmd(usr_cmd, self) catch |err| switch (err) {
            CommandError.InvalidCommand => {
                log.warn("'{s}' is not a valid command or is inactive", .{usr_cmd});

                self.resetSGR();
                self.setColor(.red);
                try self.output(usr_cmd);
                try self.outputLine(" is not a valid command!");
                try self.outputLine("");

                return false;
            },
            CommandError.NotEnoughArguments => {
                log.warn("Missing a required argument", .{});

                self.resetSGR();
                self.setColor(.red);
                try self.outputLine("ERROR: Missing a required argument!");
                try self.outputLine("");

                return false;
            },
            else => {
                return err;
            },
        };

        return cmd_result.exit;
    }

    pub fn inputBar(self: Terminal, prompt: []const u8, buf: []u8) ![]u8 {
        self.escape(.cursor_horz_abs, "0");

        self.resetSGR();
        self.setBgColor(.blue);
        self.setColor(.white);

        try self.output(prompt);

        self.escape(EscCmd.cursor_erase_line, "0");

        defer self.clearScreen();
        return try self.input(buf);
    }

    pub fn addSection(self: Terminal, name: []const u8, color: ?SGRColor, extra_space: bool) !void {
        const s_color = color orelse .blue;

        self.resetSGR();

        self.setColor(s_color);
        self.escape(.sgr_mode, "4");

        try self.output(name);

        for (name.len..self.width) |_| {
            try self.output("_");
        }

        self.resetSGR();
        if (extra_space) {
            try self.outputLine("\n");
        } else {
            try self.outputLine("");
        }
    }

    pub fn displayLogPage(self: Terminal, page_num: usize) !void {
        self.resetSGR();
        const log_page = self.logger.getPage(page_num, log_page_size) catch {
            var buf: [buffer_size]u8 = undefined;
            const err_msg = std.fmt.bufPrint(&buf, "--- Log page {d}/{d} is not available ---\n", .{ page_num + 1, self.logger.totalPageCount(log_page_size) }) catch unreachable;

            self.setColor(.red);
            try self.outputLine(err_msg);

            return;
        };

        self.setColor(.cyan);
        var buf: [buffer_size]u8 = undefined;

        const fmt_head = std.fmt.bufPrint(&buf, " -- Log Page {d}/{d} --", .{ page_num + 1, self.logger.totalPageCount(log_page_size) }) catch unreachable;
        try self.outputLine(fmt_head);
        try self.outputLine("");

        for (log_page) |log_line| {
            const fmt_log = std.fmt.bufPrint(&buf, "-:{s}", .{log_line}) catch unreachable;
            try self.outputLine(fmt_log);
        }

        try self.outputLine("");
    }

    pub fn output(self: Terminal, bytes: []const u8) !void {
        try self.out.writer().writeAll(bytes);
    }

    pub fn outputLine(self: Terminal, bytes: []const u8) !void {
        try self.out.writer().print("{s}\n", .{bytes});
    }

    pub fn input(self: Terminal, buf: []u8) ![]u8 {
        const result = try self.in.reader().readUntilDelimiter(buf, '\n');
        return result[0..(result.len - 1)];
    }

    pub fn setColor(self: Terminal, color: SGRColor) void {
        const args = std.fmt.allocPrint(self.alloc, "{d}", .{color.val()}) catch unreachable;
        defer self.alloc.free(args);
        self.escape(.sgr_mode, args);
    }

    pub fn setBgColor(self: Terminal, color: SGRColor) void {
        const args = std.fmt.allocPrint(self.alloc, "{d}", .{color.val() + 10}) catch unreachable;
        defer self.alloc.free(args);
        self.escape(.sgr_mode, args);
    }

    pub fn resetSGR(self: Terminal) void {
        self.escape(.sgr_mode, "0");
    }

    pub fn escape(self: Terminal, comptime cmd: EscCmd, args: []const u8) void {
        self.out.writer().print("{c}[{s}{c}", .{ 27, args, cmd.val() }) catch unreachable;
    }
};

test {
    @import("std").testing.refAllDecls(@This());
}
