pub const GenTypes: []const type = &[_]type{
    @import("../Component/position.zig").Position,
    @import("../Component/texture.zig").TextureObject,
    @import("../Component/text_field.zig").TextField,
    @import("../Entity/entity.zig").Entity,
    @import("../Entity/entity_list.zig").EntityList,
    @import("../Entity/entity_list.zig").ComponentList,
};
