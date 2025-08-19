const std = @import("std");
const log = std.log.scoped(.texture);

const c = @import("../c.zig");

const _component = @import("component.zig");

const _render = @import("../Render/render.zig");

const _entity = @import("../Entity/entity.zig");
const _position = @import("position.zig");

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

const ID = _component.ComponentId(TextureObject);
comptime {
    @import("component.zig").registerComponent(TextureObject);
}
pub const TextureObject = struct {
    entity: _entity.EntityId,
    texture: u32,
    rot: f32,
    scale: f32,
    color: c.Color,
    depth: i32,

    pub const thread_safe = true;

    pub fn init(entity_id: _entity.EntityId, texture_id: u32, rot: f32, scale: f32, color: c.Color, depth: i32) TextureObject {
        log.info("Init Texture Object with texture id <{d}>", .{texture_id});
        return TextureObject{
            .entity = entity_id,
            .texture = texture_id,
            .rot = rot,
            .scale = scale,
            .depth = depth,
            .color = color,
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

        const pos = if (self_entity_ref) |se_ref| se_ref.comp.globalPosition() else _position.origin;
        c.DrawTextureEx(_texture, pos.vec, self.rot, self.scale, self.color);

        if (draw_wire_debug) {
            std.debug.assert(_texture.width < 9999 and _texture.height < 9999);
            const width = @as(f32, @floatFromInt(_texture.width)) * self.scale;
            const height = @as(f32, @floatFromInt(_texture.height)) * self.scale;

            const rect = c.Rectangle{ .x = pos.vec.x, .y = pos.vec.y, .width = width, .height = height };
            c.DrawRectangleLinesEx(rect, 1, c.WHITE);
        }
    }

    pub fn componentOrder(lhs: TextureObject, rhs: TextureObject) bool {
        return lhs.depth > rhs.depth;
    }
};

fn idToCTexture(tex_id: u32) c.Texture2D {
    return textures.?[tex_id].texture;
}
