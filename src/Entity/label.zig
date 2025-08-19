const std = @import("std");

const c = @import("../c.zig");

const _entity = @import("entity.zig");

const _component = @import("../Component/component.zig");
const _text_field = @import("../Component/text_field.zig");
const _position = @import("../Component/position.zig");

const Layers = @import("../Render/render.zig").Layers;

pub const Label = _entity.DefineEntity("Label", .{}, .{ _text_field.TextField, _position.Position });

pub fn createLabel(alloc: std.mem.Allocator, text: ?[]const u8, depth: i32, size: u32, pos: c.Vector2) _entity.TaggedEntityId {
    var text_field_ref = _component.createComponent(_text_field.TextField);
    defer text_field_ref.save();

    var position_ref = _component.createComponent(_position.Position);
    defer position_ref.save();

    var children = [_]_entity.TaggedEntityId{};
    var components = [_]_entity.AnyComponentId{ text_field_ref.id.any(), position_ref.id.any() };
    const label_tagged = Label.construct(alloc, &children, &components);

    text_field_ref.comp = _text_field.TextField.init(alloc, label_tagged.id, depth, size);
    if (text) |_text| {
        text_field_ref.comp.text.appendSlice(_text) catch unreachable;
    }

    position_ref.comp = _position.fromVec(pos);

    return label_tagged;
}
