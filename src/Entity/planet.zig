const std = @import("std");
const log = std.log.scoped(.planet);

const c = @import("../c.zig");

const _entity = @import("entity.zig");
const _label = @import("label.zig");

const _component = @import("../Component/component.zig");
const _texture = @import("../Component/texture.zig");
const _position = @import("../Component/position.zig");
const _text_field = @import("../Component/text_field.zig");

const Layers = @import("../Render/render.zig").Layers;

pub const Planet = _entity.DefineEntity("Planet", .{_label.Label}, .{ _texture.TextureObject, _texture.TextureObject, _position.Position });

pub fn createPlanet(alloc: std.mem.Allocator, name: []const u8, pos: c.Vector2, fg_color: c.Color, bg_color: c.Color) _entity.TaggedEntityId {
    var bg_ref = _component.createComponent(_texture.TextureObject);
    defer bg_ref.save();

    var fg_ref = _component.createComponent(_texture.TextureObject);
    defer fg_ref.save();

    var position_ref = _component.createComponent(_position.Position);
    defer position_ref.save();

    const name_label = _label.createLabel(alloc, name, -10, 16, c.Vector2{ .x = 0.0, .y = 150.0 });

    var children = [_]_entity.TaggedEntityId{name_label};
    var components = [_]_entity.AnyComponentId{ bg_ref.id.any(), fg_ref.id.any(), position_ref.id.any() };
    const planet = Planet.construct(alloc, &children, &components);

    log.debug("Creating Textures", .{});

    const bg_texture = _texture.textureId("planet_back").?;
    bg_ref.comp = _texture.TextureObject.init(planet.id, bg_texture, 0.0, 3.0, bg_color, Layers.Background);

    log.debug("Created BG Texture", .{});

    const fg_texture = _texture.textureId("planet_fore_1").?;
    fg_ref.comp = _texture.TextureObject.init(planet.id, fg_texture, 0.0, 3.0, fg_color, Layers.Foreground);

    log.debug("Created FG texture", .{});

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
