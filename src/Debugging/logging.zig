const std = @import("std");

pub const StringList = @import("../stringList.zig").StringList;

pub const LoggingError = error{
    MsgsNotAvailable,
};

const line_length = 80;

pub const Logger = struct {
    log: *StringList,
    alloc: std.mem.Allocator,
    lock: *std.Thread.Mutex,

    pub fn init(alloc: std.mem.Allocator) Logger {
        const log = alloc.create(StringList) catch @panic("Out of Memory!");
        log.* = StringList.init(alloc) catch @panic("Out of Memory!");
        const lock = alloc.create(std.Thread.Mutex) catch @panic("Out of Memory!");
        lock.* = std.Thread.Mutex{};
        return Logger{
            .log = log,
            .alloc = alloc,
            .lock = lock,
        };
    }

    pub fn deinit(self: Logger) void {
        self.log.deinit();
        self.alloc.destroy(self.log);
        self.alloc.destroy(self.lock);
    }

    pub fn logMsg(self: Logger, comptime fmt: []const u8, args: anytype) void {
        self.lock.lock();
        defer self.lock.unlock();

        const msg = std.fmt.allocPrint(self.alloc, fmt, args) catch unreachable;
        defer self.alloc.free(msg);

        self.addLines(msg);
    }

    fn addLines(self: Logger, msg: []const u8) void {
        if (msg.len <= line_length) {
            self.log.addString(msg);
        } else {
            var line_buffer: [line_length]u8 = undefined;
            std.mem.copyForwards(u8, &line_buffer, msg[0 .. line_length - 2]);
            std.mem.copyForwards(u8, line_buffer[line_length - 2 .. line_length], " /");
            self.log.addString(&line_buffer);
            self.addLines(msg[line_length - 2 ..]);
        }
    }

    pub fn getPage(self: Logger, page_num: usize, page_size: usize) LoggingError![][]const u8 {
        self.lock.lock();
        defer self.lock.unlock();

        const total = self.log.strings.items.len;
        const right_pad = page_num * page_size;

        if (right_pad >= total) {
            return LoggingError.MsgsNotAvailable;
        }

        const end: usize = total - right_pad;
        var start: usize = undefined;
        if (page_size >= end) {
            start = 0;
        } else {
            start = end - page_size;
        }

        return self.log.strings.*.items[start..end];
    }

    pub fn totalPageCount(self: Logger, page_size: usize) usize {
        self.lock.lock();
        defer self.lock.unlock();

        const page_count = @divTrunc(self.log.strings.items.len, page_size);
        if (@rem(self.log.strings.*.items.len, page_size) > 0) {
            return page_count + 1;
        }
        return page_count;
    }
};

test {
    @import("std").testing.refAllDecls(@This());
}
