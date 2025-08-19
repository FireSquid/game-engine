const std = @import("std");
const log = std.log.scoped(.entity_old);

pub fn EntitySet(comptime T: type, comptime max_count: comptime_int) type {
    std.debug.assert(max_count < std.math.maxInt(isize));
    return struct {
        entities: [max_count]T,
        age: [max_count]usize,
        alive: [max_count]bool,
        next_id: usize,
        last_id: isize,
        entity_count: usize,

        pub const EntityType = T;
        pub const IdType = struct {
            id: usize,
            age: usize,

            pub fn format(self: IdType, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
                _ = try writer.print("E-ID[ T: {s}, I: {d}, A: {d} ]", .{ @typeName(EntityType), self.id, self.age });
            }
        };
        pub const capacity = max_count;

        const This = @This();

        pub fn init() This {
            log.info("Created entity_set for type '{s}' of size {d}", .{ @typeName(T), max_count });
            return This{
                .entities = std.mem.zeroes([max_count]T),
                .age = [_]usize{0} ** max_count,
                .alive = [_]bool{false} ** max_count,
                .next_id = 0,
                .last_id = -1,
                .entity_count = 0,
            };
        }

        pub fn deinit(self: *This) void {
            log.info("Cleaning up entity_set for type '{s}'", .{@typeName(T)});
            if (!std.meta.hasFn(EntityType, "deinit") or self.last_id < 0) {
                return;
            }
            const len: usize = @as(usize, @intCast(self.last_id)) + 1;
            for (0..len) |i| {
                self.killEntity(IdType{ .id = i, .age = self.age[i] }) catch continue;
            }
        }

        pub fn validateId(self: This, id: This.IdType) EntityError!void {
            std.debug.assert(id.id < capacity);
            if (id.id >= max_count) {
                return EntityError.IdOutOfRange;
            }
            if (id.id > self.last_id) {
                return EntityError.EntityInvalid;
            }
            if (!self.alive[id.id]) {
                return EntityError.EntityDead;
            }
            if (self.age[id.id] != id.age) {
                return EntityError.IdExpired;
            }
        }

        pub fn getEntityPtr(self: *This, id: This.IdType) EntityError!*T {
            log.debug("Getting Entity Pointer | {}", .{id});
            try self.validateId(id);

            return &self.entities[id.id];
        }

        pub fn getEntity(self: This, id: This.IdType) EntityError!*const T {
            log.debug("Getting Entity Const | {}", .{id});
            try self.validateId(id);

            return &self.entities[id.id];
        }

        pub fn getEntityId(self: This, index: usize) EntityError!This.IdType {
            log.debug("Getting Entity By Id | (T: {s}, I: {d})", .{ @typeName(EntityType), index });
            if (index >= max_count) {
                return EntityError.IdOutOfRange;
            }
            if (index > self.last_id) {
                return EntityError.EntityInvalid;
            }
            if (!self.alive[index]) {
                return EntityError.EntityDead;
            }

            return This.IdType{ .id = index, .age = self.age[index] };
        }

        pub fn createEntity(self: *This) EntityError!struct { id: This.IdType, entity: *T } {
            const _id = self.next_id;
            if (_id >= This.capacity) {
                return EntityError.ExceededEntityLimit;
            }

            const _age = self.age[_id] + 1;

            for ((_id + 1)..max_count) |i| {
                if (!self.alive[i]) {
                    self.next_id = i;
                    break;
                }
            } else {
                self.next_id = max_count;
            }

            if (_id > self.last_id) {
                self.last_id = @intCast(_id);
            }
            self.entities[_id] = std.mem.zeroes(T);
            self.age[_id] += 1;
            self.alive[_id] = true;
            self.entity_count += 1;

            return .{
                .id = This.IdType{ .id = _id, .age = _age },
                .entity = &self.entities[_id],
            };
        }

        /// Marks an entity as dead so that its space can be used for a new entity
        /// Automatically calls the 'deinit' fn if the entity has it
        pub fn killEntity(self: *This, id: This.IdType) EntityError!void {
            try self.validateId(id);

            const _id = id.id;

            if (_id < self.next_id) {
                self.next_id = _id;
            }
            self.alive[_id] = false;

            if (std.meta.hasFn(T, "deinit")) {
                self.entities[_id].deinit();
            }
            self.entity_count -= 1;
        }

        pub fn selectRandomId(self: This, rng: std.Random) EntityError!This.IdType {
            if (self.entity_count == 0) {
                return EntityError.MissingEntity;
            }
            const offset = rng.intRangeLessThan(usize, 0, self.entity_count);
            var index: usize = 0;
            while (!self.alive[index]) : (index += 1) {}
            for (0..offset) |_| {
                index += 1;
                while (!self.alive[index]) : (index += 1) {}
            }
            return try self.getEntityId(index);
        }

        pub const Iterator = struct {
            entity_set: *const This,
            next_id: usize,
            pub fn next(self: *Iterator) ?struct { id: This.IdType, entity: *const This.EntityType } {
                const max_index: isize = @min(self.entity_set.last_id, capacity - 1);
                std.debug.assert(self.entity_set.last_id < capacity);
                while (self.next_id <= max_index) : (self.next_id += 1) {
                    if (self.entity_set.alive[self.next_id]) {
                        defer self.next_id += 1;
                        return .{
                            .id = .{ .id = self.next_id, .age = self.entity_set.age[self.next_id] },
                            .entity = &self.entity_set.entities[self.next_id],
                        };
                    }
                }
                return null;
            }
        };
        pub fn iterator(self: *const This) Iterator {
            return Iterator{
                .entity_set = self,
                .next_id = 0,
            };
        }

        pub const SortedIterator = struct {
            alloc: std.mem.Allocator,
            entity_order: []*const EntityType,
            next_id: usize,
            pub fn next(self: *SortedIterator) ?*const EntityType {
                if (self.next_id < self.entity_order.len) {
                    const entity = self.entity_order[self.next_id];
                    self.next_id += 1;
                    log.debug("Next Entity: (T: {s}, D: {})", .{ @typeName(EntityType), entity.* });
                    return entity;
                }
                return null;
            }
            pub fn deinit(self: *SortedIterator) void {
                self.alloc.free(self.entity_order);
            }
        };
        pub fn sortedIterator(self: *const This, alloc: std.mem.Allocator, sortFirst: fn (void, *const EntityType, *const EntityType) bool) SortedIterator {
            var sort_list = std.ArrayList(*const EntityType).init(alloc);
            defer sort_list.deinit();

            for (0..self.entities.len) |i| {
                if (self.alive[i]) {
                    log.debug("Adding entity to sorted iterator (I:{d}) | {}", .{ i, self.entities[i] });
                    sort_list.append(&self.entities[i]) catch unreachable;
                }
            }

            const sort_slice = sort_list.toOwnedSlice() catch unreachable;
            std.mem.sort(*const EntityType, sort_slice, {}, sortFirst);

            return SortedIterator{
                .alloc = alloc,
                .entity_order = sort_slice,
                .next_id = 0,
            };
        }

        pub fn search(self: This, comptime Filter: type, filter: *const Filter) ?struct { id: This.IdType, entity: *const This.EntityType } {
            if (!std.meta.hasFn(Filter, "filter")) {
                @compileError("Filter context requires a filter function");
            }
            var e_itr = self.iterator();

            while (e_itr.next()) |entity| {
                if (filter.filter(entity.entity)) {
                    return .{ .id = entity.id, .entity = entity.entity };
                }
            }
            return null;
        }
    };
}

pub fn LockedEntitySet(comptime SetType: type) type {
    return struct {
        const This = @This();
        alloc: std.mem.Allocator,
        lock: *std.Thread.Mutex,
        set: SetType,

        pub fn init(alloc: std.mem.Allocator) This {
            const lock = alloc.create(std.Thread.Mutex) catch unreachable;
            lock.* = std.Thread.Mutex{};
            return This{
                .alloc = alloc,
                .lock = lock,
                .set = SetType.init(),
            };
        }

        pub fn deinit(self: *This) void {
            self.set.deinit();
            self.alloc.destroy(self.lock);
        }
    };
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

const SimpleEntity = struct {
    int_val: i32,
    float_val: f32,
    string_val: []const u8,

    pub fn init(int_val: i32, float_val: f32, string_val: []const u8) SimpleEntity {
        return SimpleEntity{
            .int_val = int_val,
            .float_val = float_val,
            .string_val = string_val,
        };
    }
};

const SimpleEntitySet = EntitySet(SimpleEntity, 4);
test "Create Single Entity" {
    var single_entity_set = SimpleEntitySet.init();

    const e_0 = try single_entity_set.createEntity();
    e_0.entity.int_val = 7;
    e_0.entity.float_val = 3.14;
    e_0.entity.string_val = "test";

    try expectEqual(e_0.entity, &single_entity_set.entities[0]);
    try expectEqual(1, single_entity_set.age[0]);
    try expectEqual(true, single_entity_set.alive[0]);
    try expectEqual(1, single_entity_set.next_id);
    try expectEqual(0, single_entity_set.last_id);

    try expectEqual(SimpleEntitySet.IdType{ .id = 0, .age = 1 }, e_0.id);
    try expectEqual(SimpleEntity{ .float_val = 3.14, .int_val = 7, .string_val = "test" }, (try single_entity_set.getEntityPtr(e_0.id)).*);

    try single_entity_set.killEntity(e_0.id);

    try expectEqual(1, single_entity_set.age[0]);
    try expectEqual(false, single_entity_set.alive[0]);
    try expectEqual(0, single_entity_set.next_id);
    try expectEqual(0, single_entity_set.last_id);

    try expectError(EntityError.EntityDead, single_entity_set.getEntityPtr(e_0.id));
}

test "Test Entity Backfill" {
    var entity_backfill_set = SimpleEntitySet.init();

    const e_0a = try entity_backfill_set.createEntity();
    const e_1a = try entity_backfill_set.createEntity();
    _ = try entity_backfill_set.createEntity();

    try expectEqual(3, entity_backfill_set.next_id);
    try expectEqual(2, entity_backfill_set.last_id);

    try entity_backfill_set.killEntity(e_0a.id);

    try expectEqual(0, entity_backfill_set.next_id);
    try expectEqual(2, entity_backfill_set.last_id);

    try entity_backfill_set.killEntity(e_1a.id);

    try expectEqual(0, entity_backfill_set.next_id);
    try expectEqual(2, entity_backfill_set.last_id);

    const e_0b = try entity_backfill_set.createEntity();
    const e_1b = try entity_backfill_set.createEntity();

    try expectEqual(3, entity_backfill_set.next_id);
    try expectEqual(2, entity_backfill_set.last_id);
    try expectEqual(0, e_0b.id.id);
    try expectEqual(1, e_1b.id.id);
}

test "Trigger Entity Errors" {
    var entity_error_set = SimpleEntitySet.init();

    const e_0 = try entity_error_set.createEntity();
    _ = try entity_error_set.createEntity();
    try entity_error_set.killEntity(e_0.id);

    // Attempt to access an entity id beyond the max id count
    // NOTE: This case is handled by an assertion in validateId that the id doesn't exceed the capacity
    //
    //try expectError(EntityError.IdOutOfRange, entity_error_set.getEntityPtr(SimpleEntitySet.IdType{ .id = SimpleEntitySet.capacity + 1, .age = 1 }));

    // Attempt to access an entity id that hasn't been created yet
    std.debug.assert(SimpleEntitySet.capacity - 1 > entity_error_set.last_id); // double check that we are actually trying to access an uncreated entity
    try expectError(EntityError.EntityInvalid, entity_error_set.getEntityPtr(SimpleEntitySet.IdType{ .id = SimpleEntitySet.capacity - 1, .age = 1 }));

    // Attempt to access a dead entity
    try expectError(EntityError.EntityDead, entity_error_set.getEntityPtr(e_0.id));

    // Attempt to add more entities to the set than are available
    inline for (0..(SimpleEntitySet.capacity - 1)) |_| {
        _ = try entity_error_set.createEntity();
    }
    try expectError(EntityError.ExceededEntityLimit, entity_error_set.createEntity());
}

test "Entity Set Iterator" {
    var entity_iterator_set = SimpleEntitySet.init();

    // Iterate through empty set
    var e0_itr = entity_iterator_set.iterator();
    try expect(e0_itr.next() == null);

    // Iterate through sparse set
    const e_0 = try entity_iterator_set.createEntity();
    const te_1 = try entity_iterator_set.createEntity();
    const e_2 = try entity_iterator_set.createEntity();
    try entity_iterator_set.killEntity(te_1.id);
    var e1_itr = entity_iterator_set.iterator();
    try expectEqual(e_0.id, e1_itr.next().?.id);
    try expectEqual(e_2.id, e1_itr.next().?.id);
    try expect(e1_itr.next() == null);

    // Iterate through full set
    const e_1 = try entity_iterator_set.createEntity();
    const e_3 = try entity_iterator_set.createEntity();
    var e2_itr = entity_iterator_set.iterator();
    try expectEqual(e_0.id, e2_itr.next().?.id);
    try expectEqual(e_1.id, e2_itr.next().?.id);
    try expectEqual(e_2.id, e2_itr.next().?.id);
    try expectEqual(e_3.id, e2_itr.next().?.id);
    try expect(e2_itr.next() == null);
}

const SimpleEntitySetExt = EntitySet(SimpleEntity, 64);
test "Select Random Entity" {
    const seed: u64 = 1234567890; //@bitCast(std.time.milliTimestamp());
    var rng = std.Random.DefaultPrng.init(seed);

    var entity_random_set = SimpleEntitySetExt.init();

    inline for (0..64) |_| {
        _ = try entity_random_set.createEntity();
    }

    inline for (0..64) |_| {
        const id = try entity_random_set.selectRandomId(rng.random());
        try entity_random_set.killEntity(id);
    }
}

test {
    @import("std").testing.refAllDecls(@This());
}
