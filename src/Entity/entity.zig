const std = @import("std");
const log = std.log.scoped(.entity);

const _entity_list = @import("../Entity/entity_list.zig");

const _component = @import("../Component/component.zig");

const _position = @import("../Component/position.zig");

pub const EntityError = error{
    IdOutOfRange,
    IdExpired,
    EntityDead,
    EntityInvalid,
    ExceededEntityLimit,
    MissingEntity,
};

const ComponentId = _component.ComponentId;
const ReadRef = _component.ReadRef(Entity);
const WriteRef = _component.WriteRef(Entity);
pub const AnyComponentId = ComponentId(null);
pub const EntityId = ComponentId(Entity);
pub const TaggedEntityId = struct {
    type_tag: u32,
    id: EntityId,

    pub fn init(entity_id: EntityId, comptime type_name: []const u8) TaggedEntityId {
        return TaggedEntityId{
            .type_tag = Entity.tag(type_name),
            .id = entity_id,
        };
    }

    pub fn checkTag(self: TaggedEntityId, comptime type_name: []const u8) bool {
        return self.type_tag == Entity.tag(type_name);
    }

    pub fn read(self: TaggedEntityId) ?_component.ReadRef(Entity) {
        return _component.readComponent(Entity, self.id);
    }

    pub fn write(self: TaggedEntityId) ?_component.WriteRef(Entity) {
        return _component.writeComponent(Entity, self.id);
    }
};

comptime {
    @import("../Component/component.zig").registerComponent(Entity);
}
pub const Entity = struct {
    type_tag: ?u32,
    id: EntityId,
    parent: ?EntityId,
    children: ?ComponentId(_entity_list.EntityList),
    components: ?ComponentId(_entity_list.ComponentList),

    pub const thread_safe = true;

    pub fn setTag(self: *Entity, comptime type_name: []const u8) void {
        std.debug.assert(self.type_tag == null);
        self.type_tag = tag(type_name);
    }

    pub fn forceTag(self: *Entity, comptime type_name: []const u8) void {
        self.type_tag = tag(type_name);
    }

    pub inline fn tag(comptime type_name: []const u8) u32 {
        if (type_name.len == 0) {
            return 0;
        }
        const _tag = std.hash.CityHash32.hash(type_name);
        std.debug.assert(_tag > 0);
        return _tag;
    }

    pub fn createTagged(id: EntityId, parent: ?EntityId, comptime type_name: []const u8) Entity {
        return Entity{
            .type_tag = tag(type_name),
            .id = id,
            .parent = parent,
            .children = null,
            .components = null,
        };
    }

    pub fn checkTag(self: Entity, comptime type_name: []const u8) bool {
        return self.type_tag == tag(type_name);
    }

    pub fn assertTag(self: Entity, comptime type_name: []const u8) void {
        std.debug.assert(self.checkTag(type_name));
    }

    pub fn getComponentId(self: Entity, comptime T: type) ?ComponentId(T) {
        if (self.components) |cs_id| {
            var cs_ref = cs_id.read() orelse return null;
            defer cs_ref.close();

            for (cs_ref.comp.list.items) |c_id| {
                return c_id.as(T) catch continue;
            }
        }
        return null;
    }

    pub fn getComponentIdRecursive(self: Entity, comptime T: type) ?ComponentId(T) {
        if (self.getComponentId(T)) |comp| {
            return comp;
        }
        if (self.getParent()) |parent| {
            defer parent.close();
            return parent.getComponentIdRecursive(T);
        }
        return null;
    }

    pub fn readComponent(self: Entity, comptime T: type) ?_component.ReadRef(T) {
        if (self.components) |cs_id| {
            var cs_ref = cs_id.read() orelse return null;
            defer cs_ref.close();

            return cs_ref.comp.read(T);
        }
        return null;
    }

    pub fn readComponentRecursive(self: Entity, comptime T: type) ?_component.ReadRef(T) {
        if (self.readComponent(T)) |comp| {
            return comp;
        }
        if (self.getParent()) |parent| {
            defer parent.close();
            return parent.readComponentRecursive(T);
        }
        return null;
    }

    pub fn writeComponent(self: Entity, comptime T: type) ?_component.WriteRef(T) {
        if (self.components) |cs_id| {
            var cs_ref = cs_id.read() orelse return null;
            defer cs_ref.close();

            return cs_ref.comp.write(T);
        }
    }

    pub fn writeComponentRecursive(self: Entity, comptime T: type) ?_component.Write(T) {
        if (self.writeComponent(T)) |comp| {
            return comp;
        }
        if (self.getParent()) |parent| {
            defer parent.close();
            return parent.getComponentRecursive(T);
        }
        return null;
    }

    pub fn root(self: *Entity) ?_component.ReadRef(Entity) {
        if (self.getParent()) |parent_ref| {
            return parent_ref.comp.root();
        }
        return self.read();
    }

    pub fn globalPosition(self: Entity) _position.Position {
        var local_pos_ref = self.readComponent(_position.Position);
        defer if (local_pos_ref) |*lp_ref| lp_ref.close();

        const local_pos = if (local_pos_ref) |lp_ref| lp_ref.comp else _position.origin;

        log.debug("Local Pos: {}", .{local_pos});

        var parent_ref = self.readParent();
        if (parent_ref) |*p_ref| {
            defer p_ref.close();
            log.debug("Parent Pos: {}", .{p_ref.comp});
            return local_pos.add(p_ref.comp.globalPosition());
        }
        return local_pos;
    }

    pub fn readParent(self: Entity) ?_component.ReadRef(Entity) {
        if (self.parent == null) {
            log.debug("No Parent Entity", .{});
        }
        return (self.parent orelse return null).read();
    }

    pub fn writeParent(self: Entity) ?_component.WriteRef(Entity) {
        return (self.parent orelse return null).write();
    }

    pub fn attach(self: *Entity, lifetime: std.mem.Allocator, component: AnyComponentId) void {
        var comps_ref = cRef: {
            if (self.components) |comps| {
                if (comps.write()) |ref| {
                    log.debug("Found Ref to attach: {}", .{ref});
                    break :cRef ref;
                }
            }
            log.debug("No ref to attach, creating new", .{});
            var new_ref = _component.createComponent(_entity_list.ComponentList);
            new_ref.comp = _entity_list.ComponentList.init(lifetime);
            self.components = new_ref.id;
            break :cRef new_ref;
        };

        log.debug("Attaching Component || LIST: {} || COMP: {} |", .{ comps_ref.comp, component });

        comps_ref.comp.list.append(component) catch unreachable;
        comps_ref.save();
    }

    pub fn detach(self: Entity, component: AnyComponentId) bool {
        var comps_ref = cRef: {
            if (self.components) |comps| {
                const ref = comps.write();
                if (ref) |_ref| {
                    break :cRef _ref;
                }
            }
            return false;
        };

        for (comps_ref.comp.list.items, 0..) |comp_id, i| {
            if (component.match(comp_id)) {
                _ = comps_ref.comp.list.swapRemove(i);
                comps_ref.save();
                return true;
            }
        }
        comps_ref.close();
        return false;
    }

    pub fn addChild(self: *Entity, lifetime: std.mem.Allocator, child: TaggedEntityId) bool {
        var children_ref = cRef: {
            if (self.children) |childs| {
                const ref = childs.write();
                if (ref) |_ref| {
                    break :cRef _ref;
                }
            }
            var new_ref = _component.createComponent(_entity_list.EntityList);
            new_ref.comp = _entity_list.EntityList.init(lifetime);
            self.children = new_ref.id;
            break :cRef new_ref;
        };
        defer children_ref.save();

        var child_ref = child.write() orelse {
            log.warn("Failed to add child... Child entity not found", .{});
            return false;
        };
        if (child_ref.comp.parent != null) {
            log.warn("Failed to add child... Child entity already has a parent", .{});
            child_ref.close();
            return false;
        }
        defer child_ref.save();
        child_ref.comp.parent = self.id;

        children_ref.comp.list.append(child) catch unreachable;
        return true;
    }

    pub fn removeChild(self: Entity, child: EntityId) bool {
        var children_ref = cRef: {
            if (self.children) |childs| {
                const ref = childs.write();
                if (ref) |_ref| {
                    break :cRef _ref;
                }
            }
            log.warn("Failed to remove child... Parent entity does not have child entities", .{});
            return false;
        };
        var result = false;
        defer if (result) children_ref.save() else children_ref.close();

        const index = children_ref.comp.index(child) orelse {
            log.warn("Failed to remove child... Not in the child list of the parent entity", .{});
            return result;
        };

        const child_ref = child.read() orelse {
            log.warn("Failed to remove child... Child entity not found", .{});
            return result;
        };
        defer child_ref.close();

        _ = children_ref.comp.list.swapRemove(index);
        result = true;
        return result;
    }
};

pub fn DefineEntity(comptime type_name: []const u8, comptime children: anytype, comptime components: anytype) type {
    return struct {
        const _type_name = type_name;
        pub const type_tag = Entity.tag(_type_name);
        pub fn checkTag(tag: u32) bool {
            return tag == type_tag;
        }
        pub fn assertTag(tag: u32) void {
            std.debug.assert(checkTag(tag));
        }

        pub fn construct(lifetime: std.mem.Allocator, entity_ids: ?[]TaggedEntityId, component_ids: ?[]AnyComponentId) TaggedEntityId {
            log.debug("Constructing Entity '{s}' ({d})", .{ _type_name, type_tag });
            var entity_ref = EntityId.create();
            defer entity_ref.save();

            entity_ref.comp = Entity.createTagged(entity_ref.id, null, _type_name);

            if (children.len > 0) {
                const _entity_ids = entity_ids.?;
                std.debug.assert(children.len == _entity_ids.len);
                inline for (children, 0..) |child, i| {
                    if (_entity_ids[i].checkTag(child._type_name)) {
                        const result = entity_ref.comp.addChild(lifetime, _entity_ids[i]);
                        std.debug.assert(result);
                    } else {
                        std.debug.panic("DefineEntity({s}): Child entity '{d}' was expected to be of type '{s}'\n", .{ _type_name, i, child._type_name });
                    }
                }
            }

            if (components.len > 0) {
                const _component_ids = component_ids.?;
                std.debug.assert(components.len == _component_ids.len);
                inline for (components, 0..) |c_Type, i| {
                    if (_component_ids[i].isType(c_Type)) {
                        entity_ref.comp.attach(lifetime, _component_ids[i]);
                    } else {
                        std.debug.panic("DefineEntity({s}): Component '{d}' was expected to be of type '{s}'\n", .{ _type_name, i, @typeName(components[i]) });
                    }
                }
            }

            return TaggedEntityId.init(entity_ref.id, type_name);
        }

        pub fn component(tagged_id: TaggedEntityId, comptime T: type, comptime entity_path: []const type) ?ComponentId(T) {
            log.debug("'{s}' -> ({d}) -> Component:'{s}'", .{ _type_name, entity_path.len, @typeName(T) });
            _component.assertRegistered(T);
            assertTag(tagged_id.type_tag);

            var entity_ref = tagged_id.id.read() orelse return null;
            defer entity_ref.close();

            if (entity_path.len == 0) {
                return entity_ref.comp.getComponentId(T);
            }
            const child_index = comptime childPathIndex(children, entity_path[0]) orelse @compileError(
                std.fmt.comptimePrint("Could not find entity path. Type Name: '{s}', Next Type Name: '{s}'", .{ _type_name, entity_path[0]._type_name }),
            );

            if (entity_ref.comp.children == null) {
                log.warn("Failed to load component for defined entity... entity missing child list", .{});
                return null;
            }
            var children_ref = entity_ref.comp.children.?.read() orelse return null;
            defer children_ref.close();

            const child_id = children_ref.comp.list.items[child_index];
            std.debug.assert(child_id.checkTag(entity_path[0]._type_name));

            return entity_path[0].component(child_id, T, entity_path[1..]);
        }

        fn childPathIndex(comptime _children: anytype, comptime child: type) ?u32 {
            comptime {
                for (_children, 0..) |_child, i| {
                    if (std.mem.eql(u8, child._type_name, _child._type_name)) {
                        return i;
                    }
                }
                return null;
            }
        }
    };
}
