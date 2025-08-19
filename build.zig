const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "FireSquidGameEngine",
        .root_module = exe_mod,
    });

    _ = try generateTypeRegisry(b, "src", "generated/component_types.zig", "registerComponent");
    //exe.root_module.addImport("components_gentypes", componentGeneration);

    const raylib = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(raylib.artifact("raylib"));

    b.installArtifact(exe);
}

fn generateTypeRegisry(
    b: *std.Build,
    comptime scan_root_path: []const u8,
    comptime output_rel_path: []const u8,
    comptime reg_name: []const u8,
) !*std.Build.Module {
    const alloc = b.allocator;

    var src_root = try std.fs.cwd().openDir(scan_root_path, .{ .iterate = true });
    defer src_root.close();

    var generated = std.StringArrayHashMap(void).init(alloc);
    defer generated.deinit();

    var walker = try src_root.walk(alloc);
    defer walker.deinit();

    while (try walker.next()) |file| {
        if (!std.mem.endsWith(u8, file.path, ".zig")) continue;

        const _file = try src_root.openFile(file.path, .{});
        defer _file.close();

        const source = try _file.readToEndAlloc(alloc, 1_000_000);

        var itr = std.mem.tokenizeAny(u8, source, ".;\n");
        while (itr.next()) |line| {
            if (std.mem.startsWith(u8, std.mem.trimLeft(u8, line, " "), reg_name ++ "(")) {
                const args_start = std.mem.indexOf(u8, line, "(").? + 1;
                const args_end = std.mem.lastIndexOf(u8, line, ")").?;
                const typename = std.mem.trim(u8, line[args_start..args_end], " ");
                const import_subpath = b.dupe(file.path);
                std.mem.replaceScalar(u8, import_subpath, '\\', '/');
                const path_prefix = "../" ** std.mem.count(u8, output_rel_path, "/");
                if (std.mem.startsWith(u8, typename, "comptime")) continue;
                _ = try generated.put(try std.fmt.allocPrint(alloc, "@import(\"{s}{s}\").{s}", .{ path_prefix, import_subpath, typename }), {});
            }
        }
    }

    const out = try src_root.createFile(output_rel_path, .{ .truncate = true });
    defer out.close();
    const writer = out.writer();

    try writer.writeAll("pub const GenTypes: []const type = &[_]type{\n");

    var it = generated.iterator();
    while (it.next()) |entry| {
        try writer.print("    {s},\n", .{entry.key_ptr.*});
    }

    try writer.writeAll("};\n");

    return b.addModule("generate_types", .{ .root_source_file = .{ .cwd_relative = scan_root_path ++ "/" ++ output_rel_path } });
}
// @import("../../src/Entity/planet.zig").Planet
// [@import("../../] ++ <scan_root_path> ++ <sub_path> ++ [").] ++ <typename>
