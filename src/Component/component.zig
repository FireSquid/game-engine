const std = @import("std");
const log = std.log.scoped(.component);

const registered_components = @import("../generated/component_types.zig").GenTypes;
pub fn registerComponent(comptime T: type) void {
    _ = T;
}
pub fn assertRegistered(comptime T: type) void {
    inline for (registered_components) |RT| {
        if (RT == T) {
            return;
        }
    }
    @compileError(std.fmt.comptimePrint("Type '{s}' has not been registerd as a component!", .{@typeName(T)}));
}

pub fn ComponentSetOptions(comptime T: type) type {
    return struct {
        min_capacity: u32 = 0,
        cmp_fn: ?fn (lhs: T, rhs: T) bool = null,
        thread_safe: bool = false,
        require_copy: bool = false,
    };
}
fn ComponentOptions(comptime T: type) ComponentSetOptions(T) {
    const cmp_fn = if (std.meta.hasFn(T, "componentOrder")) T.componentOrder else null;
    const thread_safe: bool = if (@hasDecl(T, "thread_safe")) T.thread_safe else false;
    const require_copy: bool = std.meta.hasFn(T, "copy");
    return ComponentSetOptions(T){
        .cmp_fn = cmp_fn,
        .thread_safe = thread_safe,
        .require_copy = require_copy,
    };
}

fn CompSetFieldName(comptime T: type) [:0]const u8 {
    return "_" ++ @typeName(T);
}

fn ComponentStore() type {
    const fields = blk: {
        var field_list: [registered_components.len]std.builtin.Type.StructField = undefined;
        for (registered_components, 0..) |T, i| {
            const FieldType = ComponentSet(T, ComponentOptions(T));
            field_list[i] = std.builtin.Type.StructField{
                .name = CompSetFieldName(T),
                .type = FieldType,
                .default_value_ptr = null,
                .is_comptime = false,
                .alignment = @alignOf(FieldType),
            };
        }
        break :blk field_list;
    };

    return @Type(std.builtin.Type{
        .@"struct" = .{
            .layout = .auto,
            .fields = &fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });
}
pub fn InitStore(alloc: std.mem.Allocator) void {
    inline for (comptime std.meta.fieldNames(@TypeOf(component_store))) |comp_set_name| {
        @field(component_store, comp_set_name) = @TypeOf(@field(component_store, comp_set_name)).init(alloc);
    }
}
pub fn DeinitStore() void {
    inline for (comptime std.meta.fieldNames(@TypeOf(component_store))) |comp_set_name| {
        @field(component_store, comp_set_name).deinit();
    }
}
var component_store: ComponentStore() = undefined;

pub fn readComponent(comptime T: type, id: ComponentId(T)) ?ReadRef(T) {
    comptime {
        assertRegistered(T);
    }

    return @field(component_store, CompSetFieldName(T)).read(id) catch return null;
}
pub fn writeComponent(comptime T: type, id: ComponentId(T)) ?WriteRef(T) {
    comptime {
        assertRegistered(T);
    }

    return @field(component_store, CompSetFieldName(T)).write(id) catch return null;
}

fn saveComponent(comptime T: type, id: ComponentId(T), value: T) void {
    comptime {
        assertRegistered(T);
    }

    return @field(component_store, CompSetFieldName(T)).commitWrite(id, value);
}

pub fn createComponent(comptime T: type) WriteRef(T) {
    comptime {
        assertRegistered(T);
    }
    return @field(component_store, CompSetFieldName(T)).create();
}

pub fn removeComponent(comptime T: type, id: ComponentId(T)) bool {
    comptime {
        assertRegistered(T);
    }
    return @field(component_store, CompSetFieldName(T)).remove(id);
}

pub fn componentIterator(comptime T: type, alloc: std.mem.Allocator) ComponentSet(T, ComponentOptions(T)).Iterator {
    comptime {
        assertRegistered(T);
    }
    return @field(component_store, CompSetFieldName(T)).iterator(alloc);
}

pub fn componentAlloc(comptime T: type) std.mem.Allocator {
    comptime {
        assertRegistered(T);
    }
    return @field(component_store, CompSetFieldName(T)).alloc;
}

fn lockSet(comptime T: type) void {
    comptime {
        assertRegistered(T);
    }
    @field(component_store, CompSetFieldName(T)).lock.lock();
}
fn unlockSet(comptime T: type) void {
    comptime {
        assertRegistered(T);
    }
    @field(component_store, CompSetFieldName(T)).lock.unlock();
}
fn tryLockSet(comptime T: type) bool {
    comptime {
        assertRegistered(T);
    }
    return @field(component_store, CompSetFieldName(T)).lock.tryLock();
}

pub fn multiLock(comptime Ts: anytype) void {
    inline for (registered_components) |RC_T| {
        inline for (Ts) |T| {
            if (RC_T == T and comptime ComponentOptions(T).thread_safe) {
                lockSet(T);
            }
        }
    }
}
pub fn multiUnlock(comptime Ts: anytype) void {
    inline for (registered_components) |RC_T| {
        inline for (Ts) |T| {
            if (RC_T == T and comptime ComponentOptions(T).thread_safe) {
                unlockSet(T);
            }
        }
    }
}

pub fn ComponentId(comptime T: ?type) type {
    if (T) |_T| {
        return struct {
            pub const CompType = _T;
            pub const TypeId = std.hash.CityHash32.hash(@typeName(_T));
            id: u32,
            index: u32,
            pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
                _ = try writer.print("C-ID[ T: '{s}', I: '{d}', N: '{d}' ]", .{ @typeName(_T), self.id, self.index });
            }
            pub fn any(self: @This()) ComponentId(null) {
                return ComponentId(null){
                    .type_id = TypeId,
                    .id = self.id,
                    .index = self.index,
                };
            }

            pub fn read(self: @This()) ?ReadRef(_T) {
                return readComponent(_T, self);
            }

            pub fn write(self: @This()) ?WriteRef(_T) {
                return writeComponent(_T, self);
            }

            pub fn create() WriteRef(_T) {
                return createComponent(_T);
            }

            pub fn match(self: @This(), other: @This()) bool {
                return self.id == other.id;
            }
        };
    } else {
        return struct {
            type_id: u32,
            id: u32,
            index: u32,

            pub fn match(self: @This(), other: @This()) bool {
                return (self.type_id == other.type_id and self.index == other.index);
            }

            pub fn as(self: @This(), comptime FromType: type) !ComponentId(FromType) {
                if (self.isType(FromType)) {
                    return ComponentId(FromType){
                        .id = self.id,
                        .index = self.index,
                    };
                }
                return error.WrongType;
            }
            pub fn isType(compId: @This(), comptime _T: type) bool {
                return compId.type_id == ComponentId(_T).TypeId;
            }

            pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
                _ = try writer.print("C-ID[ H: '{d}', I: '{d}', N: '{d}' ]", .{ self.type_id, self.id, self.index });
            }
        };
    }
}

pub fn ReadRef(comptime T: type) type {
    const alloced = std.meta.hasFn(T, "deinit");
    return struct {
        open: if (alloced) bool else void = if (alloced) true else {},
        id: ComponentId(T),
        comp: T,

        pub fn sync(self: *@This()) !void {
            if (alloced) {
                std.debug.assert(self.open);
            }
            const new_ref = readComponent(T, self.id) orelse return error.ExpiredReference;
            self.id = new_ref.id;
            self.comp = new_ref.comp;
        }

        pub fn close(self: *@This()) void {
            if (!alloced) {
                return;
            }
            std.debug.assert(self.open);
            self.comp.deinit();
            self.open = false;
        }
    };
}

pub fn WriteRef(comptime T: type) type {
    const alloced = std.meta.hasFn(T, "deinit");
    return struct {
        open: bool = true,
        id: ComponentId(T),
        comp: T,

        pub fn save(self: *@This()) void {
            std.debug.assert(self.open);
            defer self.close();
            saveComponent(T, self.id, self.comp);
        }

        pub fn close(self: *@This()) void {
            defer self.open = false;
            if (!alloced) {
                return;
            }
            std.debug.assert(self.open);
            self.comp.deinit();
        }
    };
}

pub fn MultiIterator(comptime Types: anytype) type {
    const _IdUnion, const _SortUnion, const _Map = generateUnions(Types);

    return struct {
        index: u32,
        ids: std.ArrayList(IdUnion),

        pub const IdUnion = _IdUnion;
        pub const SortUnion = _SortUnion;
        pub const fieldName = CompSetFieldName;
        pub const SortOptions = struct {
            ascending: bool = true,
            sortValFn: fn (comp: SortUnion) i32,
        };

        pub fn init(alloc: std.mem.Allocator, sort_options: ?SortOptions) @This() {
            var id_list = std.ArrayList(IdUnion).init(alloc);

            multiLock(Types);
            defer multiUnlock(Types);

            inline for (Types) |T| {
                const t_components = &@field(component_store, CompSetFieldName(T)).components;

                for (t_components.items, 0..) |comp_type, i| {
                    id_list.append(@unionInit(IdUnion, CompSetFieldName(T), ComponentId(T){ .id = comp_type.id, .index = @intCast(i) })) catch unreachable;
                }
            }

            if (sort_options) |sort_opt| {
                const sort_fn = struct {
                    fn sort(_: void, lhs: IdUnion, rhs: IdUnion) bool {
                        const l_val = sort_opt.sortValFn(_Map.map(lhs));
                        const r_val = sort_opt.sortValFn(_Map.map(rhs));
                        return if (sort_opt.ascending) (l_val < r_val) else (r_val < l_val);
                    }
                }.sort;

                std.mem.sort(IdUnion, id_list.items, {}, sort_fn);
            }

            return @This(){
                .index = 0,
                .ids = id_list,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.ids.deinit();
        }

        pub fn next(self: *@This()) ?IdUnion {
            if (self.index >= self.ids.items.len) {
                return null;
            }
            const next_id = self.ids.items[self.index];
            self.index += 1;
            return next_id;
        }
    };
}
fn generateUnions(comptime Types: anytype) struct { type, type, type } {
    comptime var enum_fields: [Types.len]std.builtin.Type.EnumField = undefined;
    comptime var id_union_fields: [Types.len]std.builtin.Type.UnionField = undefined;
    comptime var sort_union_fields: [Types.len]std.builtin.Type.UnionField = undefined;

    inline for (Types, 0..) |T, i| {
        assertRegistered(T);
        enum_fields[i] = std.builtin.Type.EnumField{
            .name = CompSetFieldName(T),
            .value = i,
        };
    }

    inline for (Types, 0..) |T, i| {
        id_union_fields[i] = std.builtin.Type.UnionField{
            .name = CompSetFieldName(T),
            .type = ComponentId(T),
            .alignment = @alignOf(ComponentId(T)),
        };
        sort_union_fields[i] = std.builtin.Type.UnionField{
            .name = CompSetFieldName(T),
            .type = T,
            .alignment = @alignOf(T),
        };
    }

    const UnionEnum = @Type(std.builtin.Type{ .@"enum" = std.builtin.Type.Enum{
        .decls = &.{},
        .fields = &enum_fields,
        .is_exhaustive = true,
        .tag_type = u8,
    } });
    const IdUnion = @Type(std.builtin.Type{ .@"union" = std.builtin.Type.Union{
        .layout = .auto,
        .tag_type = UnionEnum,
        .fields = &id_union_fields,
        .decls = &.{},
    } });
    const SortUnion = @Type(std.builtin.Type{ .@"union" = std.builtin.Type.Union{
        .layout = .auto,
        .tag_type = UnionEnum,
        .fields = &sort_union_fields,
        .decls = &.{},
    } });

    const Map = struct {
        fn map(id: IdUnion) SortUnion {
            switch (id) {
                inline else => |_id| {
                    const T = @TypeOf(_id).CompType;
                    return @unionInit(
                        SortUnion,
                        CompSetFieldName(T),
                        @field(component_store, CompSetFieldName(T)).components.items[_id.index].comp,
                    );
                }
            }
        }
    };

    return .{
        IdUnion,
        SortUnion,
        Map,
    };
}

pub fn ComponentSet(comptime T: type, comptime options: ComponentSetOptions(T)) type {
    const ComponentType = struct {
        id: u32,
        comp: T,

        fn toReadRef(self: @This(), index: u32) ReadRef(T) {
            return ReadRef(T){
                .id = ComponentId(T){ .id = self.id, .index = index },
                .comp = if (options.require_copy) self.comp.copy() else self.comp,
            };
        }

        fn toWriteRef(self: @This(), index: u32) WriteRef(T) {
            return WriteRef(T){
                .id = ComponentId(T){ .id = self.id, .index = index },
                .comp = if (options.require_copy) self.comp.copy() else self.comp,
            };
        }
    };
    const IdType = ComponentId(T);
    const _ComponentSet = struct {
        const This = @This();
        const ordered = (options.cmp_fn != null);
        alloc: std.mem.Allocator,
        components: std.ArrayList(ComponentType),
        lock: std.Thread.Mutex.Recursive,
        mod_lock: bool,

        pub fn init(alloc: std.mem.Allocator) This {
            return This{
                .alloc = alloc,
                .components = std.ArrayList(ComponentType).init(alloc),
                .lock = std.Thread.Mutex.Recursive.init,
                .mod_lock = false,
            };
        }

        pub fn deinit(self: *This) void {
            if (std.meta.hasFn(T, "deinit")) {
                for (self.components.items) |*item| {
                    item.comp.deinit();
                }
            }
            self.components.deinit();
        }
        var _id: u32 = 0;
        fn GetNextComponentId() u32 {
            _id += 1;
            return _id;
        }

        fn read(self: *This, id_index: IdType) !ReadRef(T) {
            log.debug("GETTING ReadRef(CompStore: {s}, id: {d}):", .{ @typeName(T), id_index.id });
            if (options.thread_safe) {
                self.lock.lock();
                defer self.lock.unlock();

                return _read(self, id_index);
            } else {
                return _read(self, id_index);
            }
        }
        fn _read(self: *This, id_index: IdType) !ReadRef(T) {
            if (id_index.index < self.components.items.len and self.components.items[id_index.index].id == id_index.id) {
                return self.components.items[id_index.index].toReadRef(id_index.index);
            }

            for (self.components.items, 0..) |item, index| {
                if (item.id == id_index.id) {
                    return item.toReadRef(@intCast(index));
                }
            }
            log.debug("No component found. (CompType: {s}, IdIndex: {})", .{ @typeName(T), id_index });
            return error.ComponentNotFound;
        }

        fn write(self: *This, id_index: IdType) !WriteRef(T) {
            log.debug("GETTING WriteRef(CompStore: {s}, id: {d}):", .{ @typeName(T), id_index.id });
            if (options.thread_safe) {
                self.lock.lock();
                defer self.lock.unlock();

                return _write(self, id_index);
            } else {
                return _write(self, id_index);
            }
        }
        fn _write(self: *This, id_index: IdType) !WriteRef(T) {
            if (id_index.index < self.components.items.len and self.components.items[id_index.index].id == id_index.id) {
                return self.components.items[id_index.index].toWriteRef(id_index.index);
            }

            for (self.components.items, 0..) |item, index| {
                if (item.id == id_index.id) {
                    return item.toWriteRef(@intCast(index));
                }
            }
            log.debug("No component found. (CompType: {s}, IdIndex: {})", .{ @typeName(T), id_index });
            return error.ComponentNotFound;
        }
        fn commitWrite(self: *This, id_index: IdType, value: T) void {
            self.lock.lock();
            defer self.lock.unlock();
            if (id_index.index < self.components.items.len and self.components.items[id_index.index].id == id_index.id) {
                self.components.items[id_index.index].comp = if (options.require_copy) value.copy() else value;
                return;
            }

            for (self.components.items) |*item| {
                if (item.id == id_index.id) {
                    item.comp = if (options.require_copy) value.copy() else value;
                }
            }
            log.debug("No component found. Appending new component. (CompType: {s}, IdIndex: {})", .{ @typeName(T), id_index });
            self.components.append(ComponentType{
                .id = id_index.id,
                .comp = if (options.require_copy) value.copy() else value,
            }) catch unreachable;
        }

        pub fn create(self: *This) WriteRef(T) {
            log.debug("CREATING(CompStore: {s}):", .{@typeName(T)});

            if (options.thread_safe) {
                self.lock.lock();
                defer self.lock.unlock();

                return _create(self);
            } else {
                return _create(self);
            }
        }
        fn _create(self: *This) WriteRef(T) {
            const id = This.GetNextComponentId();
            const index: u32 = @intCast(self.components.items.len);
            const component = ComponentType{
                .comp = undefined,
                .id = id,
            };

            return component.toWriteRef(index);
        }

        pub fn remove(self: *This, id_index: IdType) bool {
            log.debug("REMOVING(CompStore: {s}):", .{@typeName(T)});

            if (options.thread_safe) {
                self.lock.lock();
                defer self.lock.unlock();

                return _remove(self, id_index);
            } else {
                return _remove(self, id_index);
            }
        }
        fn _remove(self: *This, id_index: IdType) bool {
            if (id_index.index < self.components.items.len and self.components.items[id_index.index].id == id_index.id) {
                if (std.meta.hasFn(T, "deinit")) {
                    self.components.items[id_index.index].deinit();
                }
                _ = self.components.swapRemove(id_index.index);
                return true;
            }

            for (self.components.items, 0..) |*item, index| {
                if (item.id == id_index.id) {
                    if (std.meta.hasFn(T, "deinit")) {
                        item.deinit();
                    }
                    _ = self.components.swapRemove(index);
                    return true;
                }
            }
            log.debug("No component removed. (CompType: {s})", .{@typeName(T)});
            return false;
        }

        pub const Iterator = struct {
            alloc: std.mem.Allocator,
            comp_store: *This,
            ids: []IdType,
            index: u32,

            pub fn deinit(self: *Iterator) void {
                self.alloc.free(self.ids);
            }

            pub fn next(self: *Iterator) ?ReadRef(T) {
                if (self.index < self.ids.len) {
                    const ref = self.comp_store.read(self.ids[self.index]) catch return null;
                    self.index += 1;
                    return ref;
                }
                return null;
            }

            pub fn peek(self: Iterator) ?ReadRef(T) {
                if (self.index < self.ids.len) {
                    return self.comp_store.read(self.ids[self.index]) catch return null;
                }
                return null;
            }
        };
        pub fn iterator(self: *This, alloc: std.mem.Allocator) Iterator {
            self.lock.lock();
            defer self.lock.unlock();

            var id_array = std.ArrayList(IdType).init(alloc);

            for (self.components.items, 0..) |comp, i| {
                id_array.append(IdType{ .id = comp.id, .index = @intCast(i) }) catch unreachable;
            }

            if (options.cmp_fn) |cmp| {
                const sort_fn = struct {
                    pub fn sortfn(context: *This, lhs: IdType, rhs: IdType) bool {
                        return cmp(context.components.items[lhs.index].comp, context.components.items[rhs.index].comp);
                    }
                }.sortfn;

                log.debug("Sorting component set (T: {s})", .{@typeName(T)});
                std.mem.sort(IdType, id_array.items, self, sort_fn);
            }
            return Iterator{
                .alloc = alloc,
                .comp_store = self,
                .ids = id_array.toOwnedSlice() catch unreachable,
                .index = 0,
            };
        }
    };
    return _ComponentSet;
}
