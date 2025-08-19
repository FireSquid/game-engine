const std = @import("std");

pub const StringList = struct {
    strings: *std.ArrayList([]const u8),
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) !StringList {
        const strings = try alloc.create(std.ArrayList([]const u8));
        strings.* = std.ArrayList([]const u8).init(alloc);

        return StringList{
            .strings = strings,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: StringList) void {
        for (self.strings.*.items) |str| {
            self.alloc.free(str);
        }
        self.strings.deinit();
        self.alloc.destroy(self.strings);
    }

    pub fn addString(self: StringList, str: []const u8) void {
        const new_str = self.alloc.alloc(u8, str.len) catch @panic("Out of Memory!");
        @memcpy(new_str, str);
        self.strings.append(new_str) catch @panic("Allocator Error!");
    }
};

test {
    @import("std").testing.refAllDecls(@This());
}
