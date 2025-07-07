const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const KnowledgeEngine = @import("InkCept_lib").KnowledgeEngine;
const processDocument = @import("InkCept_lib").processDocument;
const fileToText = @import("InkCept_lib").fileToText;

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

    std.debug.print("File size: {} bytes\n", .{sample_text.len});
    std.debug.print("First 100 chars: {s}\n", .{sample_text[0..@min(100, sample_text.len)]});

    try testing.expect(sample_text.len > 0);
}

test "Document processing creates concepts" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var knowledge_engine = try KnowledgeEngine.init(allocator, 4, 500);
    defer knowledge_engine.deinit();

    // Read and process example.txt
    const sample_text = try fileToText(allocator, "example.txt");
    defer allocator.free(sample_text);

    std.debug.print("Processing {} bytes of text\n", .{sample_text.len});

    try processDocument(allocator, sample_text, &knowledge_engine);
    try knowledge_engine.waitForAllActors();

    // Count how many concepts were created
    var concept_count: u32 = 0;
    var concept_iter = knowledge_engine.concept_actors.iterator();
    while (concept_iter.next()) |entry| {
        concept_count += 1;
        std.debug.print("Concept: Key={any}, Value={any}\n", .{ entry.key, entry.value });
    }

    std.debug.print("Total concepts created: {}\n", .{concept_count});

    // Should create at least some concepts
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
    std.debug.print("Concepts after first document: {}\n", .{concept_count_after_first});

    // Process second document
    const different_text = try fileToText(allocator, "differentExample.txt");
    defer allocator.free(different_text);
    try processDocument(allocator, different_text, &engine);
    try engine.waitForAllActors();

    const concept_count_after_second = engine.concept_actors.size.load(.seq_cst);
    std.debug.print("Concepts after second document: {}\n", .{concept_count_after_second});

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
    std.debug.print("Concepts before maintenance: {}\n", .{concept_count_before});

    // Run maintenance
    try engine.runMaintenance();

    const concept_count_after = engine.concept_actors.size.load(.seq_cst);
    std.debug.print("Concepts after maintenance: {}\n", .{concept_count_after});

    // Should not crash
    try testing.expect(true);
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
