const std = @import("std");
var rng: ?std.Random.DefaultPrng = null;

pub fn randomAlphaNum(comptime format: []const u8) [format.len]u8 {
    const A = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const a = "abcdefghijklmnopqrstuvwxyz";
    const N = "0123456789";
    const C = A ++ N;
    const c = a ++ N;
    const L = A ++ a;
    const E = A ++ a ++ N;

    if (rng == null) {
        rng = std.Random.DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp())));
    }
    const random = rng.?.random();
    var str = [1]u8{0} ** format.len;

    for (format, 0..) |fmt, i| {
        const char_set = switch (fmt) {
            'A' => A,
            'a' => a,
            'N' => N,
            'C' => C,
            'c' => c,
            'L' => L,
            'E' => E,
            else => std.debug.panic("Invalid Format Symbol: '{c}'\n", .{fmt}),
        };

        str[i] = char_set[random.intRangeLessThan(usize, 0, char_set.len)];
    }

    return str;
}
