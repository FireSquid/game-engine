const std = @import("std");

pub const _terminal = @import("./Terminal/terminal.zig");
const Terminal = _terminal.Terminal;

pub const _logger = @import("Debugging/logging.zig");
const Logger = _logger.Logger;

pub const _component = @import("Component/component.zig");

pub const panic = std.debug.FullPanic(outputPanicLog);

const GameContext = @import("game_context.zig").GameContext;

const c = @import("c.zig");
const t_render = @import("Render/render.zig");

pub const std_options = std.Options{
    .logFn = fileAndIgLog,
    .log_level = .debug,

    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .component, .level = .info },
        .{ .scope = .entity, .level = .info },
        .{ .scope = .text_field, .level = .info },
        .{ .scope = .texture, .level = .info },
    },
};
var logger: ?Logger = null;

const ig_log_level: std.log.Level = .debug;
const log_thread_id: bool = true;
const log_timestamp: bool = true;

var log_file: std.fs.File = undefined;

pub fn main() !void {
    createLogFile() catch |err| {
        std.debug.print("ERROR: Failed to open log file. Exiting with error - {}\n", .{err});
        return err;
    };
    defer log_file.close();

    var dba = std.heap.DebugAllocator(.{}){};
    defer {
        const deinit_check = dba.deinit();
        if (deinit_check == .leak) @panic("Memory Leaked");
    }
    var tsa = std.heap.ThreadSafeAllocator{ .child_allocator = dba.allocator() };
    const alloc = tsa.allocator();

    std.log.info("Main Thread", .{});

    _component.InitStore(alloc);
    defer _component.DeinitStore();

    var context = GameContext{
        .game = null,
        .render = null,
        .terminal = null,
    };

    const term = Terminal.initWithStdIO(alloc, 32, 120, &context);
    defer term.deinit();

    logger = term.logger;

    var render_thread = try std.Thread.spawn(.{ .allocator = alloc }, t_render.renderThread, .{ alloc, &logger.?, &context });
    render_thread.detach();

    while (true) {
        if (context.render) |render| {
            if (render.state != .Starting) {
                break;
            }
        }
    }

    {
        var input_buf: [256]u8 = undefined;
        _ = try term.inputBar("Press ENTER to start...", &input_buf);
    }

    std.log.info("=== Starting Game Loop ===", .{});

    while (true) {
        const cmd_result = term.promptCommand() catch |err| error_blk: {
            std.debug.print("Command execution FAILED with error '{s}'\n", .{@errorName(err)});
            break :error_blk false;
        };
        if (cmd_result) {
            break;
        }
    }

    std.log.info("=== Ending Game Loop ===", .{});

    if (context.render) |render| {
        if (render.state == .Running) {
            std.log.info("Stopping Renderer", .{});
            render.state = .Stopping;
        }
        std.log.info("Waiting for Renderer to stop...", .{});
        while (render.state != .Stopped) {}
    }
    std.log.info("Terminating Main Thread", .{});
}

pub fn fileAndIgLog(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const in_game_log = switch (ig_log_level) {
        .debug => true,
        .info => (message_level != .debug),
        .warn => (message_level == .warn or message_level == .err),
        .err => (message_level == .err),
    };
    const level_text = comptime message_level.asText();
    const scope_prefix = comptime if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";

    if (in_game_log) {
        if (logger) |ig_log| {
            ig_log.logMsg(level_text ++ scope_prefix ++ format, args);
        }
    }

    var buffered_writer = std.io.bufferedWriter(log_file.writer());
    const _writer = buffered_writer.writer();
    _writer.writeAll(level_text) catch unreachable;
    if (log_timestamp) {
        _writer.print("[{d}]", .{std.time.microTimestamp()}) catch unreachable;
    }
    if (log_thread_id) {
        _writer.print("<{d}>", .{std.Thread.getCurrentId()}) catch unreachable;
    }
    _writer.writeAll(scope_prefix) catch unreachable;
    _writer.print(format ++ "\n", args) catch unreachable;
    buffered_writer.flush() catch |err| {
        std.debug.print("WARN: Failed to flush log file buffer - err: {}", .{err});
    };
}

fn createLogFile() !void {
    var log_dir = std.fs.cwd().openDir("logs", .{}) catch |err| mkdir: {
        switch (err) {
            error.FileNotFound => {
                try std.fs.cwd().makeDir("logs");
                break :mkdir try std.fs.cwd().openDir("logs", .{});
            },
            else => {
                return err;
            },
        }
    };
    defer log_dir.close();

    inline for (0..4) |index| {
        moveOldLogFiles('4' - index, &log_dir);
    }

    log_file = try log_dir.createFile("log_1.txt", .{});
}

fn moveOldLogFiles(comptime index: u8, log_dir: *std.fs.Dir) void {
    log_dir.rename("log_" ++ [_]u8{index} ++ ".txt", "log_" ++ [_]u8{index + 1} ++ ".txt") catch {
        std.debug.print("log_{s} not renamed\n", .{[_]u8{index}});
        return;
    };
    std.debug.print("Moved log_{s} to log_{s}\n", .{ [_]u8{index}, [_]u8{index + 1} });
}

fn outputPanicLog(msg: []const u8, first_trace_addr: ?usize) noreturn {
    std.debug.print("\n\nPANIC {d}: {s}\n\n", .{ std.Thread.getCurrentId(), msg });
    std.debug.print("Final Log Page:\n---------------\n", .{});
    if (logger) |__logger| {
        const final_logs = __logger.getPage(0, 20);

        if (final_logs) |final_log_page| {
            for (final_log_page) |log_page| {
                std.debug.print("-:{s}\n", .{log_page});
            }
        } else |_| {
            std.debug.print("Failed to obtain logs!\n", .{});
        }
    }

    std.debug.defaultPanic(msg, first_trace_addr);
}

test {
    @import("std").testing.refAllDecls(@This());
}
