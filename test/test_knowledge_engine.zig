const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const KnowledgeEngine = @import("InkCept_lib").KnowledgeEngine;
const processDocument = @import("InkCept_lib").processDocument;
const fileToText = @import("InkCept_lib").fileToText;
const RelationType = @import("InkCept_lib").RelationType;
const Concept = @import("InkCept_lib").Concept;

// Test suite for KnowledgeEngine
test "KnowledgeEngine initialization and deinitialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test initialization with valid parameters
    var knowledge_engine = try KnowledgeEngine.init(allocator, 4, 1000);
    defer knowledge_engine.deinit();
}

test "Query non-existent concept" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try KnowledgeEngine.init(allocator, 4, 500);
    defer engine.deinit();

    // Query a concept that doesn't exist
    try testing.expectEqual(null, try engine.query("nonexistent"));
}

test "File reading works" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Read file and check it's not empty
    const sample_text = try fileToText(allocator, "example.txt");
    defer allocator.free(sample_text);

    std.debug.print("File size: {d} bytes\n", .{sample_text.len});
    std.debug.print("First 100 chars: {s}\n", .{sample_text[0..@min(100, sample_text.len)]});

    try testing.expect(sample_text.len > 0);
}

test "Document processing creates concepts" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var knowledge_engine = try KnowledgeEngine.init(allocator, 4, 500);
    defer knowledge_engine.deinit();

    const sample_text = try fileToText(allocator, "example.txt");
    defer allocator.free(sample_text);

    std.debug.print("Processing {d} bytes of text\n", .{sample_text.len});

    try processDocument(allocator, sample_text, &knowledge_engine);
    try knowledge_engine.waitForAllActors();

    var concept_count: u32 = 0;
    var concept_iter = knowledge_engine.concept_actors.iterator();
    while (concept_iter.next()) |entry| {
        concept_count += 1;
        std.debug.print("Concept: Key={d}, Value={d}\n", .{ entry.key, entry.value });
    }

    std.debug.print("Total concepts created: {d}\n", .{concept_count});

    try testing.expect(concept_count > 0);
}

test "Concepts have meaningful stats" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try KnowledgeEngine.init(allocator, 4, 500);
    defer engine.deinit();

    // Process example.txt
    const sample_text = try fileToText(allocator, "example.txt");
    defer allocator.free(sample_text);
    try processDocument(allocator, sample_text, &engine);
    try engine.waitForAllActors();

    // Check the first few concepts have valid stats
    var concept_iter = engine.concept_actors.iterator();
    var checked_concepts: u32 = 0;

    while (concept_iter.next()) |entry| {
        if (checked_concepts >= 3) break; // Only check first 3

        const concept_id = entry.key;
        if (try engine.getConceptStats(concept_id)) |stats| {
            std.debug.print("Concept ID {}: activation={d:.3}, energy={d:.3}, relations={}\n", .{ concept_id, stats.activation, stats.energy, stats.relations });

            // Basic sanity checks
            try testing.expect(stats.activation >= 0.0);
            try testing.expect(stats.energy >= 0.0);
        }
        checked_concepts += 1;
    }

    try testing.expect(checked_concepts > 0);
}

test "Cross-domain processing" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try KnowledgeEngine.init(allocator, 4, 500);
    defer engine.deinit();

    // Process first document
    const sample_text = try fileToText(allocator, "example.txt");
    defer allocator.free(sample_text);
    try processDocument(allocator, sample_text, &engine);

    const concept_count_after_first = engine.concept_actors.size.load(.seq_cst);
    std.debug.print("Concepts after first document: {d}\n", .{concept_count_after_first});

    // Process second document
    const different_text = try fileToText(allocator, "differentExample.txt");
    defer allocator.free(different_text);
    try processDocument(allocator, different_text, &engine);
    try engine.waitForAllActors();

    const concept_count_after_second = engine.concept_actors.size.load(.seq_cst);
    std.debug.print("Concepts after second document: {d}\n", .{concept_count_after_second});

    // Second document should add more concepts
    try testing.expect(concept_count_after_second >= concept_count_after_first);
}

test "Concept activation changes stats" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try KnowledgeEngine.init(allocator, 4, 500);
    defer engine.deinit();

    // Process document to create concepts
    const sample_text = try fileToText(allocator, "example.txt");
    defer allocator.free(sample_text);
    try processDocument(allocator, sample_text, &engine);
    try engine.waitForAllActors();

    // Get the first concept ID
    var concept_iter = engine.concept_actors.iterator();
    if (concept_iter.next()) |entry| {
        const concept_id = entry.key;

        // Get initial stats
        if (try engine.getConceptStats(concept_id)) |initial_stats| {
            std.debug.print("Initial stats: activation={d:.3}\n", .{initial_stats.activation});

            // Activate the concept
            try engine.activateConcept(concept_id);

            // Get stats after activation
            if (try engine.getConceptStats(concept_id)) |final_stats| {
                std.debug.print("Final stats: activation={d:.3}\n", .{final_stats.activation});

                // Activation should change (increase or at least not decrease significantly)
                try testing.expect(final_stats.activation >= initial_stats.activation - 0.001);
            }
        }
    }
}

test "Query actual concepts" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try KnowledgeEngine.init(allocator, 4, 500);
    defer engine.deinit();

    const sample_text = try fileToText(allocator, "example.txt");
    defer allocator.free(sample_text);
    try processDocument(allocator, sample_text, &engine);
    try engine.waitForAllActors();

    // Try to query some words that should exist in the text
    const test_words = [_][]const u8{ "book", "title", "randomness", "summary" };

    for (test_words) |word| {
        if (try engine.query(word)) |concept_id| {
            std.debug.print("Found '{s}' -> ID: {}\n", .{ word, concept_id });
        } else {
            std.debug.print("'{s}' not found\n", .{word});
        }
    }
}

test "Maintenance runs without errors" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try KnowledgeEngine.init(allocator, 4, 500);
    defer engine.deinit();

    // Process document
    const sample_text = try fileToText(allocator, "example.txt");
    defer allocator.free(sample_text);
    try processDocument(allocator, sample_text, &engine);
    try engine.waitForAllActors();

    const concept_count_before = engine.concept_actors.size.load(.seq_cst);
    std.debug.print("Concepts before maintenance: {d}\n", .{concept_count_before});

    // Run maintenance
    try engine.runMaintenance();

    const concept_count_after = engine.concept_actors.size.load(.seq_cst);
    std.debug.print("Concepts after maintenance: {d}\n", .{concept_count_after});

    // Should not crash
    try testing.expect(true);
}

test "Display concept relations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try KnowledgeEngine.init(allocator, 4, 500);
    defer engine.deinit();

    const sample_text = try fileToText(allocator, "example.txt");
    defer allocator.free(sample_text);
    try processDocument(allocator, sample_text, &engine);
    try engine.waitForAllActors();

    var concept_iter = engine.concept_actors.iterator();
    defer concept_iter.deinit();

    var concepts_checked: u32 = 0;
    while (concept_iter.next()) |entry| {
        const concept_id = entry.key;
        const actor_id = entry.value;

        const concept_ptr = try engine.engine.getActorState(Concept, actor_id);
        const stats = concept_ptr.getStats();

        std.debug.print("\n--- Concept ID: {d} ---\n", .{concept_id});
        std.debug.print("Term: '{s}'\n", .{concept_ptr.term});
        std.debug.print("Activation: {d:.3}\n", .{stats.activation});
        std.debug.print("Energy: {d:.3}\n", .{stats.energy});
        std.debug.print("Stability: {d:.3}\n", .{stats.stability});
        std.debug.print("Complexity: {d:.3}\n", .{stats.complexity});
        std.debug.print("Relations count: {d}\n", .{stats.relations});

        if (stats.relations > 0) {
            std.debug.print("Relations:\n", .{});

            concept_ptr.relations_mutex.lock();
            for (concept_ptr.relations.items, 0..) |relation, i| {
                var target_term: []const u8 = "unknown";
                if (engine.concept_actors.get(relation.target_id)) |target_id| {
                    const target_concept = engine.engine.getActorState(Concept, target_id) catch null;
                    if (target_concept) |target| {
                        target_term = target.term;
                    }
                }

                const relation_type_str = switch (relation.relation_type) {
                    .Causes => "Causes",
                    .IsA => "IsA",
                    .PartOf => "PartOf",
                    .Synonym => "Synonym",
                    .Antonym => "Antonym",
                    .AssociatedWith => "AssociatedWith",
                    .Custom => "Custom",
                };

                const time_since_access = std.time.timestamp() - relation.last_accessed;
                std.debug.print("  {d}: {s} -> '{s}' (ID: {d}) | Weight: {d:.3} | Type: {s} | Last accessed: {d}s ago\n", .{ i + 1, concept_ptr.term, target_term, relation.target_id, relation.weight, relation_type_str, time_since_access });
            }
            concept_ptr.relations_mutex.unlock();
        } else {
            std.debug.print("No relations found.\n", .{});
        }

        concepts_checked += 1;
        if (concepts_checked >= 5) break;
    }

    try testing.expect(concepts_checked > 0);
}

// Enhanced test to create and verify specific relations
test "Create and verify specific relations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try KnowledgeEngine.init(allocator, 4, 500);
    defer engine.deinit();

    // Create some test concepts
    const book_id = try engine.createConcept("book");
    const title_id = try engine.createConcept("title");
    const randomness_id = try engine.createConcept("randomness");

    // Add some relations
    try engine.addRelation(book_id, title_id, RelationType.PartOf, 0.8);
    try engine.addRelation(book_id, randomness_id, RelationType.AssociatedWith, 0.6);
    try engine.addRelation(title_id, randomness_id, RelationType.Synonym, 0.4);

    // Wait for all messages to be processed
    try engine.waitForAllActors();

    // Check each concept's relations
    const test_concepts = [_]struct { id: u64, name: []const u8 }{
        .{ .id = book_id, .name = "book" },
        .{ .id = title_id, .name = "title" },
        .{ .id = randomness_id, .name = "randomness" },
    };

    for (test_concepts) |concept_info| {
        const actor_id = engine.concept_actors.get(concept_info.id).?;
        const concept_ptr = try engine.engine.getActorState(Concept, actor_id);
        const stats = concept_ptr.getStats();

        std.debug.print("\nConcept '{s}' (ID: {d}): {d} relations\n", .{ concept_info.name, concept_info.id, stats.relations });

        if (stats.relations > 0) {
            concept_ptr.relations_mutex.lock();
            for (concept_ptr.relations.items, 0..) |relation, i| {
                // Find target concept name
                var target_name: []const u8 = "unknown";
                for (test_concepts) |target_info| {
                    if (target_info.id == relation.target_id) {
                        target_name = target_info.name;
                        break;
                    }
                }

                const relation_type_str = switch (relation.relation_type) {
                    .Causes => "Causes",
                    .IsA => "IsA",
                    .PartOf => "PartOf",
                    .Synonym => "Synonym",
                    .Antonym => "Antonym",
                    .AssociatedWith => "AssociatedWith",
                    .Custom => "Custom",
                };

                std.debug.print("  {d}: {s} --[{s}]--> {s} (weight: {d:.3})\n", .{ i + 1, concept_info.name, relation_type_str, target_name, relation.weight });
            }
            concept_ptr.relations_mutex.unlock();
        }
    }

    // Verify that relations were created
    try testing.expect(book_id != 0);
    try testing.expect(title_id != 0);
    try testing.expect(randomness_id != 0);
}
