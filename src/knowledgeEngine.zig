const std = @import("std");
const Allocator = std.mem.Allocator;

const ConcurrentHashMap = @import("concurrentHashMap.zig").ConcurrentHashMap;
const Engine = @import("engine.zig").Engine;
const Message = @import("message.zig").Message;
const InstructionPayload = @import("message.zig").InstructionPayload;

const RelationType = enum {
    Causes,
    IsA,
    PartOf,
    Synonym,
    Antonym,
    AssociatedWith,
    Custom,
};

const KnowledgeCommand = enum {
    activate,
    propagate,
    learn,
    query,
    add_relation,
    decay,
    merge_check,
    split_check,
    death_check,
};

const ActivationThresholds = struct {
    const MIN_ACTIVATION: f64 = 0.1;
    const DECAY_RATE: f64 = 0.95;
    const PROPAGATION_THRESHOLD: f64 = 0.3;
    const CREATION_THRESHOLD: f64 = 0.7;
};

const Relation = struct {
    target_id: u64,
    relation_type: RelationType,
    weight: f64,
    last_accessed: i64,

    pub fn init(target_id: u64, relation_type: RelationType, weight: f64) Relation {
        return Relation{
            .target_id = target_id,
            .relation_type = relation_type,
            .weight = weight,
            .last_accessed = std.time.timestamp(),
        };
    }
};

// contexts for different kinds of messages
const ActivationContext = struct {
    strength: f64,

    pub fn init(allocator: Allocator, strength: f64) !*ActivationContext {
        const self = try allocator.create(ActivationContext);
        self.* = ActivationContext{
            .strength = strength,
        };
        return self;
    }

    pub fn deinit(ctx: *anyopaque, allocator: Allocator) void {
        const self: *ActivationContext = @ptrCast(@alignCast(ctx));
        allocator.destroy(self);
    }

    pub fn clone(ctx: *anyopaque, allocator: Allocator) !*anyopaque {
        const self: *ActivationContext = @ptrCast(@alignCast(ctx));
        const new_ctx = try ActivationContext.init(allocator, self.strength);
        return @ptrCast(new_ctx);
    }

    pub fn handleActivation(ctx: *anyopaque, actor: *anyopaque) void {
        const self: *ActivationContext = @ptrCast(@alignCast(ctx));
        const concept: *Concept = @ptrCast(@alignCast(actor));
        concept.receiveActivation(self.strength);
    }
};

const RelationContext = struct {
    target_id: u64,
    relation_type: RelationType,
    weight: f64,

    pub fn init(allocator: Allocator, target_id: u64, relation_type: RelationType, weight: f64) !*RelationContext {
        const self = try allocator.create(RelationContext);
        self.* = RelationContext{
            .target_id = target_id,
            .relation_type = relation_type,
            .weight = weight,
        };
        return self;
    }

    pub fn deinit(ctx: *anyopaque, allocator: Allocator) void {
        const self: *RelationContext = @ptrCast(@alignCast(ctx));
        allocator.destroy(self);
    }

    pub fn clone(ctx: *anyopaque, allocator: Allocator) !*anyopaque {
        const self: *RelationContext = @ptrCast(@alignCast(ctx));
        const new_ctx = try RelationContext.init(allocator, self.target_id, self.relation_type, self.weight);
        return @ptrCast(new_ctx);
    }

    pub fn handleAddRelation(ctx: *anyopaque, actor: *anyopaque) void {
        const self: *RelationContext = @ptrCast(@alignCast(ctx));
        const concept: *Concept = @ptrCast(@alignCast(actor));
        concept.addRelationInternal(self.target_id, self.relation_type, self.weight);
    }
};

const Concept = struct {
    const Self = @This();
    // const RelationList = ConcurrentArrayList(Relation);

    allocator: Allocator,
    id: u64,
    term: []u8,
    activation: std.atomic.Value(f64),
    last_activation: std.atomic.Value(i64),
    birth_time: i64,
    access_count: std.atomic.Value(u64),
    energy: std.atomic.Value(f64),
    stability: std.atomic.Value(f64),
    complexity: std.atomic.Value(f64),
    relations: std.ArrayList(Relation),
    relations_mutex: std.Thread.Mutex,
    engine_ref: ?*KnowledgeEngine,

    pub fn init(allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .allocator = allocator,
            .id = 0,
            .term = try allocator.alloc(u8, 0),
            .activation = std.atomic.Value(f64).init(0.0),
            .last_activation = std.atomic.Value(i64).init(std.time.timestamp()),
            .birth_time = std.time.timestamp(),
            .access_count = std.atomic.Value(u64).init(0),
            .energy = std.atomic.Value(f64).init(1.0),
            .stability = std.atomic.Value(f64).init(0.5),
            .complexity = std.atomic.Value(f64).init(0.0),
            .relations = std.ArrayList(Relation).init(allocator),
            .relations_mutex = std.Thread.Mutex{},
            .engine_ref = null,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.term);
        self.relations.deinit(); // Free the ConcurrentHashMap's resources
        self.allocator.destroy(self); // Free the Concept struct itself
    }

    pub fn receive(self: *Self, allocator: std.mem.Allocator, msg: *Message) !void {
        _ = allocator;
        // Every time we get a custom payload.
        switch (msg.instruction) {
            .custom => |payload| {
                try self.handleCustomMessage(payload);
            },
            .func => |f| {
                // For handler payloads, call the handler's function:
                f.call_fn(f.context, @ptrCast(self));
            },
        }
    }

    fn handleCustomMessage(self: *Self, payload: []const u8) !void {
        if (payload.len == 0) return;

        // Parse command from payload
        if (std.mem.eql(u8, payload, "activate")) {
            self.activate();
        } else if (std.mem.eql(u8, payload, "propagate")) {
            self.propagateActivation();
        } else if (std.mem.eql(u8, payload, "learn")) {
            self.learn();
        } else if (std.mem.eql(u8, payload, "decay")) {
            self.decay();
        } else if (std.mem.eql(u8, payload, "merge_check")) {
            self.considerMerge();
        } else if (std.mem.eql(u8, payload, "split_check")) {
            self.considerSplit();
        } else if (std.mem.eql(u8, payload, "death_check")) {
            try self.considerDeath();
        }
    }

    fn activate(self: *Self) void {
        // Since f64 doesn't support atomic compare-and-swap, we'll use a simpler approach
        const current_activation = self.activation.load(.seq_cst);
        self.activation.store(current_activation + 0.1, .seq_cst);

        self.last_activation.store(std.time.timestamp(), .seq_cst);
        _ = self.access_count.fetchAdd(1, .seq_cst);

        const current_energy = self.energy.load(.seq_cst);
        self.energy.store(@min(2.0, current_energy + 0.5), .seq_cst);

        self.updateStability();

        if (self.activation.load(.seq_cst) > ActivationThresholds.PROPAGATION_THRESHOLD) {
            self.propagateActivation();
        }
    }

    fn propagateActivation(self: *Self) void {
        const current_activation = self.activation.load(.seq_cst);
        if (current_activation < ActivationThresholds.MIN_ACTIVATION) return;

        self.relations_mutex.lock();
        defer self.relations_mutex.unlock();

        for (self.relations.items) |*relation| {
            const propagation_strength = current_activation * relation.weight * 0.5;

            if (propagation_strength > ActivationThresholds.MIN_ACTIVATION) {
                self.sendActivationTo(relation.target_id, propagation_strength);
                relation.last_accessed = std.time.timestamp();
            }
        }

        // Decay after propagation
        const decayed = current_activation * ActivationThresholds.DECAY_RATE;
        self.activation.store(decayed, .seq_cst);
    }

    fn sendActivationTo(self: *Self, target_id: u64, strength: f64) void {
        if (self.engine_ref) |engine| {
            engine.sendActivationMessage(target_id, strength) catch |err| {
                std.log.warn("Failed to send activation to concept {}: {}", .{ target_id, err });
            };
        }
    }

    fn learn(self: *Self) void {
        self.relations_mutex.lock();
        defer self.relations_mutex.unlock();

        const now = std.time.timestamp();

        for (self.relations.items) |*relation| {
            const time_since_access = now - relation.last_accessed;

            if (time_since_access < 3600) { // Within last hour
                relation.weight = @min(1.0, relation.weight * 1.05);
            } else if (time_since_access > 86400) { // Older than a day
                relation.weight = @max(0.1, relation.weight * 0.95);
            }
        }

        self.updateComplexity();
    }

    fn updateStability(self: *Self) void {
        const age = std.time.timestamp() - self.birth_time;
        const access_count = self.access_count.load(.seq_cst);

        if (age > 0) {
            const stability = @min(1.0, @as(f64, @floatFromInt(access_count)) / @as(f64, @floatFromInt(@divFloor(age, 60)))); // Access per minute
            self.stability.store(stability, .seq_cst);
        }
    }

    fn updateComplexity(self: *Self) void {
        var total_weight: f64 = 0.0;
        var relation_count: u32 = 0;

        for (self.relations.items) |relation| {
            total_weight += relation.weight;
            relation_count += 1;
        }

        const complexity = if (relation_count > 0) total_weight / @as(f64, @floatFromInt(relation_count)) else 0.0;
        self.complexity.store(complexity, .seq_cst);
    }

    fn considerMerge(self: *Self) void {
        const stability = self.stability.load(.seq_cst);
        const complexity = self.complexity.load(.seq_cst);

        if (stability < 0.3 and complexity < 0.2) {
            std.log.info("Concept '{s}' (ID: {}) considering merge - low stability and complexity", .{ self.term, self.id });
            // TODO: Implement merge logic with engine coordination
        }
    }

    fn considerSplit(self: *Self) void {
        const complexity = self.complexity.load(.seq_cst);

        self.relations_mutex.lock();
        const relation_count = self.relations.items.len;
        self.relations_mutex.unlock();

        if (complexity > 0.8 and relation_count > 20) {
            std.log.info("Concept '{s}' (ID: {}) considering split - high complexity", .{ self.term, self.id });
            // TODO: Implement split logic
        }
    }

    fn considerDeath(self: *Self) !void {
        const age = std.time.timestamp() - self.birth_time;
        const time_since_last_use = std.time.timestamp() - self.last_activation.load(.seq_cst);
        const energy = self.energy.load(.seq_cst);
        const stability = self.stability.load(.seq_cst);

        if (age > 86400 and // Older than 1 day
            time_since_last_use > 3600 and // Not used in last hour
            energy < 0.1 and // Low energy
            stability < 0.1) // Low stability
        {
            std.log.info("Concept '{s}' (ID: {}) marked for death - unused and unstable", .{ self.term, self.id });

            try self.engine_ref.?.engine.poisonActor(Self, self.id);
        }
    }

    pub fn receiveActivation(self: *Self, strength: f64) void {
        const current = self.activation.load(.seq_cst);
        self.activation.store(@min(2.0, current + strength), .seq_cst);
        self.last_activation.store(std.time.timestamp(), .seq_cst);
        _ = self.access_count.fetchAdd(1, .seq_cst);
    }

    pub fn addRelationInternal(self: *Self, target_id: u64, relation_type: RelationType, weight: f64) void {
        self.relations_mutex.lock();
        defer self.relations_mutex.unlock();

        // Check if relation already exists
        for (self.relations.items) |*existing| {
            if (existing.target_id == target_id and existing.relation_type == relation_type) {
                existing.weight = @max(existing.weight, weight); // Take stronger weight
                existing.last_accessed = std.time.timestamp();
                return;
            }
        }

        // Add new relation
        const relation = Relation.init(target_id, relation_type, weight);
        self.relations.append(relation) catch |err| {
            std.log.warn("Failed to add relation: {}", .{err});
        };

        self.updateComplexity();
    }

    pub fn decay(self: *Self) void {
        const current_activation = self.activation.load(.seq_cst);
        const decayed = current_activation * ActivationThresholds.DECAY_RATE;
        self.activation.store(@max(0.0, decayed), .seq_cst);

        const current_energy = self.energy.load(.seq_cst);
        self.energy.store(@max(0.0, current_energy * 0.99), .seq_cst);
    }

    pub fn getStats(self: *Self) struct { activation: f64, energy: f64, stability: f64, complexity: f64, relations: usize } {
        const relation_count = self.relations.items.len;

        return .{
            .activation = self.activation.load(.seq_cst),
            .energy = self.energy.load(.seq_cst),
            .stability = self.stability.load(.seq_cst),
            .complexity = self.complexity.load(.seq_cst),
            .relations = relation_count,
        };
    }
};

pub const KnowledgeEngine = struct {
    const Self = @This();
    const ConceptActorMap = ConcurrentHashMap(u64, u64, std.hash_map.AutoContext(u64));
    const TermToConceptMap = ConcurrentHashMap(u64, u64, std.hash_map.AutoContext(u64));

    allocator: Allocator,
    engine: Engine,
    concept_actors: ConceptActorMap, // concept_id -> actor_id
    term_to_concept: TermToConceptMap, // term_hash -> concept_id
    next_concept_id: std.atomic.Value(u64),
    last_maintenance: std.atomic.Value(i64),

    pub fn init(allocator: Allocator, n_threads: usize, initial_size: u64) !Self {
        return Self{
            .allocator = allocator,
            .engine = try Engine.init(allocator, .{ .allocator = allocator, .n_jobs = n_threads }, initial_size),
            .concept_actors = try ConceptActorMap.init(allocator, 10, .{}),
            .term_to_concept = try TermToConceptMap.init(allocator, 10, .{}),
            .next_concept_id = std.atomic.Value(u64).init(1),
            .last_maintenance = std.atomic.Value(i64).init(std.time.timestamp()),
        };
    }

    pub fn deinit(self: *Self) void {
        self.engine.deinit();
        self.concept_actors.deinit();
        self.term_to_concept.deinit();
    }

    pub fn createConcept(self: *Self, term: []const u8) !u64 {
        const term_hash = std.hash_map.hashString(term);

        // Check if concept already exists
        if (self.term_to_concept.get(term_hash)) |existing_id| {
            return existing_id;
        }

        const concept_id = self.next_concept_id.fetchAdd(1, .seq_cst);

        // Create concept with initialization data
        const actor_id = try self.engine.spawnActor(Concept);

        const actual_actor = try self.engine.getActorState(Concept, actor_id);

        self.allocator.free(actual_actor.term);
        actual_actor.term = try self.allocator.dupe(u8, term);
        actual_actor.engine_ref = self;

        try self.concept_actors.put(concept_id, actor_id);
        try self.term_to_concept.put(term_hash, concept_id);

        std.log.info("Created concept '{s}' with ID: {} (Actor: {})", .{ term, concept_id, actor_id });
        return concept_id;
    }

    pub fn activateConcept(self: *Self, concept_id: u64) !void {
        const maybe_actor_id = self.concept_actors.get(concept_id);

        if (maybe_actor_id) |actor_id| {
            const msg = try Message.makeCustomPayload(self.allocator, 0, "activate");
            try self.engine.sendMessage(actor_id, msg);
        }
    }

    pub fn sendActivationMessage(self: *Self, concept_id: u64, strength: f64) !void {
        const maybe_actor_id = self.concept_actors.get(concept_id);

        if (maybe_actor_id) |actor_id| {
            const ctx = try ActivationContext.init(self.allocator, strength);
            const msg = try Message.makeFuncPayload(
                self.allocator,
                0, // sender_id
                ActivationContext.handleActivation,
                @ptrCast(ctx),
                ActivationContext.deinit,
                ActivationContext.clone,
            );
            try self.engine.sendMessage(actor_id, msg);
        }
    }

    pub fn addRelation(self: *Self, source_id: u64, target_id: u64, relation_type: RelationType, weight: f64) !void {
        const maybe_actor_id = self.concept_actors.get(source_id);

        if (maybe_actor_id) |actor_id| {
            const ctx = try RelationContext.init(self.allocator, target_id, relation_type, weight);
            const msg = try Message.makeFuncPayload(
                self.allocator,
                0,
                RelationContext.handleAddRelation,
                @ptrCast(ctx),
                RelationContext.deinit,
                RelationContext.clone,
            );
            try self.engine.sendMessage(actor_id, msg);
        }
    }

    pub fn findConcept(self: *Self, term: []const u8) ?u64 {
        const term_hash = std.hash_map.hashString(term);
        return self.term_to_concept.get(term_hash);
    }

    pub fn query(self: *Self, term: []const u8) !?u64 {
        if (self.findConcept(term)) |concept_id| {
            try self.activateConcept(concept_id);
            return concept_id;
        }
        return null;
    }

    pub fn runMaintenance(self: *Self) !void {
        const now = std.time.timestamp();
        const last_maintenance = self.last_maintenance.load(.seq_cst);

        if (now - last_maintenance > 60) { // Run every minute
            self.last_maintenance.store(now, .seq_cst);

            var iterator = self.concept_actors.iterator();
            defer iterator.deinit();

            while (iterator.next()) |entry| {
                const actor_id = entry.value;

                // Send decay message
                const decay_msg = try Message.makeCustomPayload(self.allocator, 0, "decay");
                try self.engine.sendMessage(actor_id, decay_msg);

                // Send death check message
                const death_msg = try Message.makeCustomPayload(self.allocator, 0, "death_check");
                try self.engine.sendMessage(actor_id, death_msg);
            }

            std.log.info("Maintenance cycle completed for {} concepts", .{self.concept_actors.count});
        }
    }

    pub fn getConceptStats(self: *Self, concept_id: u64) !?@TypeOf(Concept.getStats(@as(*Concept, undefined))) {
        const maybe_actor_id = self.concept_actors.get(concept_id);

        if (maybe_actor_id) |actor_id| {
            const concept_ptr = try self.engine.getActorState(Concept, actor_id);
            return concept_ptr.getStats();
        }
        return null;
    }

    pub fn waitForAllActors(self: *Self) !void {
        var iterator = self.concept_actors.iterator();
        defer iterator.deinit();

        while (iterator.next()) |entry| {
            try self.engine.waitForActor(entry.value);
        }
    }
};
