const std = @import("std");
const log = std.log.scoped(.entity_list);

const _component = @import("../Component/component.zig");
const _entity = @import("../Entity/entity.zig");

comptime {
    @import("../Component/component.zig").registerComponent(EntityList);
}
pub const EntityList = struct {
    list: std.ArrayList(_entity.TaggedEntityId),

    pub fn init(alloc: std.mem.Allocator) EntityList {
        return EntityList{
            .list = std.ArrayList(_entity.TaggedEntityId).init(alloc),
        };
    }

    pub fn deinit(self: *EntityList) void {
        self.list.deinit();
    }

    pub fn copy(self: *const EntityList) EntityList {
        var _copy = EntityList.init(self.list.allocator);
        _copy.list = self.list.clone() catch unreachable;
        return _copy;
    }

    pub fn index(self: *EntityList, id: _entity.EntityId) ?usize {
        for (self.list.items, 0..) |item, i| {
            if (item.id.match(id)) {
                return i;
            }
        }
        return null;
    }
};

comptime {
    @import("../Component/component.zig").registerComponent(ComponentList);
}
pub const ComponentList = struct {
    list: std.ArrayList(_entity.AnyComponentId),

    pub fn init(alloc: std.mem.Allocator) ComponentList {
        return ComponentList{
            .list = std.ArrayList(_entity.AnyComponentId).init(alloc),
        };
    }

    pub fn deinit(self: *ComponentList) void {
        self.list.deinit();
    }

    pub fn copy(self: *const ComponentList) ComponentList {
        var _copy = ComponentList.init(self.list.allocator);
        _copy.list = self.list.clone() catch unreachable;
        return _copy;
    }

    pub fn read(self: *const ComponentList, comptime T: type) ?_component.ReadRef(T) {
        for (self.list.items) |any_id| {
            return _component.readComponent(T, any_id.as(T) catch continue);
        }
        return null;
    }

    pub fn write(self: *const ComponentList, comptime T: type) ?_component.WriteRef(T) {
        for (self.list) |any_id| {
            return _component.writeComponent(T, any_id.as(T) catch continue);
        }
    }
};
