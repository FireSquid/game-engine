const std = @import("std");
const log = std.log.scoped(.planet);

const c = @import("../c.zig");

const _entity = @import("../Entity/entity.zig");
const _label = @import("../Entity/label.zig");
const _button = @import("../Entity/button.zig");

const _component = @import("../Component/component.zig");
const _texture = @import("../Component/texture.zig");
const _position = @import("../Component/position.zig");
const _text_field = @import("../Component/text_field.zig");
const _callback = @import("../Component/callback.zig");

const Layers = @import("../Render/render.zig").Layers;

pub const Planet = _entity.DefineEntity("Planet", .{ _button.TextureButton, _label.Label }, .{ _texture.TextureObject, _position.Position });

pub fn createPlanet(alloc: std.mem.Allocator, name: []const u8, pos: c.Vector2, fg_color: c.Color, bg_color: c.Color) _entity.TaggedEntityId {
    const bg_texture = _texture.textureId("planet_back").?;
    const fg_texture = _texture.textureId("planet_fore_1").?;

    var bg_ref = _component.createComponent(_texture.TextureObject);
    defer bg_ref.save();

    var position_ref = _component.createComponent(_position.Position);
    defer position_ref.save();

    const btn_cb = _callback.Callback{
        .func = planetBtnTest,
        .ctx = &struct {}{},
    };

    const fg_button = _button.createTextureButton(alloc, .{
        .texture_id = fg_texture,
        .mode = .CENTER_MID,
        .pos = _position.origin.vec,
        .scale = 3.0,
        .color = fg_color,
        .depth = Layers.Foreground,
        .click = btn_cb,
    });
    const name_label = _label.createLabel(alloc, name, Layers.UI, 16, c.Vector2{ .x = 0.0, .y = 70.0 }, .CENTER_TOP);

    var children = [_]_entity.TaggedEntityId{ fg_button, name_label };
    var components = [_]_entity.AnyComponentId{ bg_ref.id.any(), position_ref.id.any() };
    const planet = Planet.construct(alloc, &children, &components);

    bg_ref.comp = _texture.TextureObject.init(planet.id, .{ .texture_id = bg_texture, .mode = .CENTER_MID, .scale = 3.0, .color = bg_color, .depth = Layers.Background });

    position_ref.comp = _position.fromVec(pos);

    return planet;
}

pub fn getPlanetName(alloc: std.mem.Allocator, planet_id: _entity.TaggedEntityId) ?[]const u8 {
    var tf_id = Planet.component(planet_id, _text_field.TextField, &[_]type{_label.Label}) orelse return null;
    var tf_ref = tf_id.read() orelse return null;
    defer tf_ref.close();

    const name_len = tf_ref.comp.text.items.len;
    if (name_len == 0) {
        return null;
    }

    const out_str = alloc.alloc(u8, name_len) catch unreachable;
    std.mem.copyForwards(u8, out_str, tf_ref.comp.text.items);

    return out_str;
}

fn planetBtnTest(src_id: _entity.TaggedEntityId, ctx: *const anyopaque) void {
    _ = ctx;

    var btn_ref = src_id.read() orelse {
        log.err("Missing button id", .{});
        return;
    };
    defer btn_ref.close();

    var planet_ref = btn_ref.comp.readParent() orelse {
        log.err("Missing parent planet", .{});
        return;
    };
    defer planet_ref.close();

    const planet_id = planet_ref.comp.tagged();

    if (Planet.component(planet_id, _text_field.TextField, &[_]type{_label.Label})) |name_id| {
        var name_ref = _component.readComponent(_text_field.TextField, name_id) orelse {
            log.warn("Unable to get planet name reference", .{});
            return;
        };
        defer name_ref.close();

        log.info("Planet Name: {s}", .{name_ref.comp.text.items});
    } else {
        log.warn("Unable to get planet name field id", .{});
    }
}
