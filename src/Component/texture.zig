const std = @import("std");
const log = std.log.scoped(.texture);

const c = @import("../c.zig");

const _component = @import("component.zig");

const _render = @import("../Render/render.zig");
const Layers = _render.Layers;

const _entity = @import("../Entity/entity.zig");
const _position = @import("position.zig");

const _ui = @import("../ui.zig");

pub var context: ?*@import("../game_context.zig").GameContext = null;
pub var draw_wire_debug: bool = true;

pub const max_texture_name = 32;

const texture_path = "resc/";
const texture_ext = ".png";
const texture_list = [_][]const u8{
    "planet_back",
    "planet_fore_1",
};

var textures: ?[texture_list.len]Texture = null;

pub fn textureId(comptime texture_name: []const u8) ?u32 {
    inline for (texture_list, 0..) |tl_item, i| {
        if (std.mem.eql(u8, texture_name, tl_item)) {
            return i;
        }
    }
    return null;
}

pub fn texture(comptime texture_name: []const u8) ?Texture {
    return textures[textureId(texture_name) orelse return null];
}

pub fn loadTextures() void {
    textures = [_]Texture{std.mem.zeroes(Texture)} ** texture_list.len;
    inline for (texture_list, 0..) |tex_name, i| {
        textures.?[i] = Texture.init(texture_path ++ tex_name ++ texture_ext);
        std.debug.assert(textureId(tex_name).? == i);
    }
}

pub const Texture = struct {
    texture: c.Texture2D,

    pub fn init(file_name: []const u8) Texture {
        var file_name_c: [max_texture_name]u8 = undefined;
        std.debug.assert(file_name.len < max_texture_name);
        std.mem.copyForwards(u8, &file_name_c, file_name);
        file_name_c[file_name.len] = 0;
        const new_tex = Texture{
            .texture = c.LoadTexture(&file_name_c),
        };

        log.info("Loaded Texture: {s}", .{file_name});
        log.debug("Texture size: ({d}, {d})", .{ new_tex.texture.width, new_tex.texture.height });

        return new_tex;
    }

    pub fn deinit(self: *Texture) void {
        c.UnloadTexture(self.texture);
    }
};

fn idToCTexture(tex_id: u32) c.Texture2D {
    return textures.?[tex_id].texture;
}

pub fn textureSize(tex_id: u32) c.Vector2 {
    const tex_ptr = &textures.?[tex_id].texture;
    return c.Vector2{ .x = @floatFromInt(tex_ptr.width), .y = @floatFromInt(tex_ptr.height) };
}

const ID = _component.ComponentId(TextureObject);
comptime {
    @import("component.zig").registerComponent(TextureObject);
}
pub const TextureObject = struct {
    entity: _entity.EntityId,
    texture: u32,
    mode: _ui.Mode,
    rot: f32,
    scale: f32,
    color: c.Color,
    depth: i32,

    pub const thread_safe = true;

    pub const TextureObjectArgs = struct {
        texture_id: u32,
        mode: _ui.Mode = .LEFT_TOP,
        rot: f32 = 0.0,
        scale: f32 = 1.0,
        color: c.Color = c.WHITE,
        depth: i32 = Layers.Foreground,
    };
    pub fn init(entity_id: _entity.EntityId, args: TextureObjectArgs) TextureObject {
        log.info("Init Texture Object with texture id <{d}>", .{args.texture_id});
        return TextureObject{
            .entity = entity_id,
            .texture = args.texture_id,
            .mode = args.mode,
            .rot = args.rot,
            .scale = args.scale,
            .color = args.color,
            .depth = args.depth,
        };
    }

    pub fn draw(id: ID) void {
        var tex_obj_ref = id.read() orelse {
            log.warn("Missing object (id: {d}) - Skipping Draw Step", .{id.id});
            return;
        };
        defer tex_obj_ref.close();

        const self = &tex_obj_ref.comp;

        log.debug("Draw Call", .{});
        const _texture = idToCTexture(self.texture);

        var self_entity_ref = self.entity.read() orelse null;
        defer if (self_entity_ref) |*se_ref| se_ref.close();

        const width = @as(f32, @floatFromInt(_texture.width)) * self.scale;
        const height = @as(f32, @floatFromInt(_texture.height)) * self.scale;

        const pos = if (self_entity_ref) |se_ref| se_ref.comp.globalPosition() else _position.origin;
        const align_pos = _ui.getAlignPosition(self.mode, pos, width, height);

        c.DrawTextureEx(_texture, align_pos.vec, self.rot, self.scale, self.color);

        if (draw_wire_debug) {
            std.debug.assert(_texture.width < 9999 and _texture.height < 9999);

            const rect = c.Rectangle{ .x = align_pos.vec.x, .y = align_pos.vec.y, .width = width, .height = height };
            c.DrawRectangleLinesEx(rect, 1, c.WHITE);

            c.DrawCircleV(pos.vec, 5, c.BLACK);
            c.DrawCircleLinesV(pos.vec, 5, c.WHITE);
        }
    }

    pub fn componentOrder(lhs: TextureObject, rhs: TextureObject) bool {
        return lhs.depth > rhs.depth;
    }
};
