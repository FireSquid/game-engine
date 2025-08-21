const std = @import("std");
const log = std.log.scoped(.button);

const c = @import("../c.zig");

const _entity = @import("../Entity/entity.zig");

const _component = @import("../Component/component.zig");
const _ui_frame = @import("../Component/ui_frame.zig");
const _text_field = @import("../Component/text_field.zig");
const _position = @import("../Component/position.zig");
const _bounds = @import("../Component/bounds.zig");
const _callback = @import("../Component/callback.zig");

const _ui = @import("../ui.zig");

const Layers = @import("../Render/render.zig").Layers;

pub const TextButton = _entity.DefineEntity("TextButton", .{}, .{ _text_field.TextField, _ui_frame.UiFrame, _bounds.Bounds, _position.Position });

pub const TextButtonArgs = struct {
    base_depth: i32 = Layers.UI,
    text_size: u32,
    txt_color: c.Color = c.WHITE,
    pos: c.Vector2,
    dim: ?c.Vector2 = null,
    fill: ?c.Color = c.GRAY,
    line: ?c.Color = null,
    line_thick: f32 = 0.0,
    mode: _text_field.Mode = .CENTER_MID,
    click: _callback.Callback,
};
pub fn createTextButton(alloc: std.mem.Allocator, text: []const u8, args: TextButtonArgs) _entity.TaggedEntityId {
    log.debug("Creating Text Button", .{});
    var text_field_ref = _component.createComponent(_text_field.TextField);
    defer text_field_ref.save();

    var ui_frame_ref = _component.createComponent(_ui_frame.UiFrame);
    defer ui_frame_ref.save();

    var bounds_ref = _component.createComponent(_bounds.Bounds);
    defer bounds_ref.save();

    var position_ref = _component.createComponent(_position.Position);
    defer position_ref.save();

    var children = [_]_entity.TaggedEntityId{};
    var components = [_]_entity.AnyComponentId{ text_field_ref.id.any(), ui_frame_ref.id.any(), bounds_ref.id.any(), position_ref.id.any() };
    const text_button_tagged = TextButton.construct(alloc, &children, &components);

    text_field_ref.comp = _text_field.TextField.init(alloc, text_button_tagged.id, args.base_depth - 10, args.text_size, args.mode);
    text_field_ref.comp.text.appendSlice(text) catch unreachable;

    const dim = if (args.dim) |_dim| _dim else calc_dim: {
        const c_str = std.fmt.allocPrintZ(alloc, "{s}", .{text}) catch unreachable;
        defer alloc.free(c_str);

        const width = c.MeasureText(c_str, @intCast(args.text_size));
        const margin = c.Vector2{ .x = 16.0, .y = 10.0 };

        break :calc_dim c.Vector2{ .x = @as(f32, @floatFromInt(width)) + margin.x, .y = @as(f32, @floatFromInt(args.text_size)) + margin.y };
    };

    ui_frame_ref.comp = _ui_frame.UiFrame.init(text_button_tagged.id, args.base_depth, dim, args.fill, args.line, args.line_thick, args.mode);

    bounds_ref.comp = _bounds.Bounds.init(text_button_tagged, args.pos, dim, args.mode, .{ .click = args.click });

    position_ref.comp = _position.fromVec(args.pos);

    return text_button_tagged;
}
