const std = @import("std");
const Allocator = std.mem.Allocator;

const KnowledgeEngine = @import("knowledgeEngine.zig").KnowledgeEngine;
const processDocument = @import("documentParser.zig").processDocument;
const fileToText = @import("documentParser.zig").fileToText;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize Knowledge Engine with 4 threads and capacity for 1000 actors
    var knowledge_engine = try KnowledgeEngine.init(allocator, 4, 1000);
    defer knowledge_engine.deinit();

    std.log.info("=== Autopoietic Knowledge Engine with Document Processing ===", .{});

    // =============================================================================
    // EXAMPLE 1: Process a sample document about animals
    // =============================================================================

    const sample_text = try fileToText(allocator, "example.txt");
    defer allocator.free(sample_text);

    std.log.info("\n=== Processing Sample Document ===", .{});
    try processDocument(allocator, sample_text, &knowledge_engine);

    // Wait for message propagation
    std.time.sleep(200_000_000); // 200ms

    // =============================================================================
    // EXAMPLE 2: Query and explore the created knowledge graph
    // =============================================================================

    std.log.info("\n=== Exploring Created Knowledge Graph ===", .{});

    // Query some concepts that should have been created
    const queries = [_][]const u8{ "events", "publication", "antifragile", "swan", "title", "summary" };

    for (queries) |query| {
        if (try knowledge_engine.query(query)) |concept_id| {
            std.log.info("Found concept '{s}' with ID: {d}", .{ query, concept_id });

            if (try knowledge_engine.getConceptStats(concept_id)) |stats| {
                std.log.info("  Stats: activation={d:.3}, energy={d:.3}, stability={d:.3}, complexity={d:.3}, relations={}", .{ stats.activation, stats.energy, stats.stability, stats.complexity, stats.relations });
            }
        } else {
            std.log.info("Concept '{s}' not found in knowledge base", .{query});
        }
    }

    // =============================================================================
    // EXAMPLE 3: Demonstrate knowledge propagation
    // =============================================================================

    std.log.info("\n=== Testing Knowledge Propagation ===", .{});

    // Activate "events" and see how activation spreads
    if (try knowledge_engine.query("events")) |id| {
        std.log.info("Activating 'events' concept...", .{});

        // Give multiple activations to trigger strong propagation
        for (0..5) |_| {
            try knowledge_engine.activateConcept(id);
        }

        // Wait for propagation
        std.time.sleep(300_000_000); // 300ms

        // Check related concepts that should have received activation
        const related_concepts = [_][]const u8{ "book", "decision", "disorder", "implications" };

        for (related_concepts) |concept_name| {
            if (knowledge_engine.findConcept(concept_name)) |concept_id| {
                if (try knowledge_engine.getConceptStats(concept_id)) |stats| {
                    std.log.info("  '{s}' received activation: {d:.3}", .{ concept_name, stats.activation });
                }
            }
        }
    }

    // =============================================================================
    // EXAMPLE 4: Advanced document processing with file reading
    // =============================================================================

    std.log.info("\n=== Processing Multiple Document Types ===", .{});

    // Process a different document
    const different_text = try fileToText(allocator, "differentExample.txt");
    defer allocator.free(different_text);

    try processDocument(allocator, different_text, &knowledge_engine);

    // Wait for processing
    std.time.sleep(300_000_000);

    // =============================================================================
    // EXAMPLE 5: Cross-domain knowledge integration
    // =============================================================================

    std.log.info("\n=== Cross-Domain Knowledge Integration ===", .{});

    // Now we have concepts from both animal domain and AI domain
    // Let's see how they might interact
    const cross_domain_queries = [_][]const u8{ "unity", "seperation", "theory", "systems", "framework", "education" };

    for (cross_domain_queries) |query| {
        if (try knowledge_engine.query(query)) |concept_id| {
            if (try knowledge_engine.getConceptStats(concept_id)) |stats| {
                std.log.info("Cross-domain concept '{s}': relations={d}, complexity={d:.3}", .{ query, stats.relations, stats.complexity });
            }
        }
    }

    // =============================================================================
    // EXAMPLE 6: Simulation with maintenance and evolution
    // =============================================================================

    std.log.info("\n=== Running Extended Simulation ===", .{});

    // Run a longer simulation to see concept evolution
    for (0..20) |cycle| {
        // Randomly activate concepts from our vocabulary
        const random_concepts = [_][]const u8{ "events", "publication", "antifragile", "swan", "title", "summary", "unity", "seperation", "theory", "systems", "framework", "education" };

        // Activate 2-3 random concepts each cycle
        const activations_per_cycle = 2 + (cycle % 2);
        for (0..activations_per_cycle) |_| {
            const random_concept = random_concepts[cycle % random_concepts.len];
            _ = try knowledge_engine.query(random_concept);
        }

        // Run maintenance every few cycles
        if (cycle % 3 == 0) {
            try knowledge_engine.runMaintenance();
        }

        // Print progress every 5 cycles
        if (cycle % 5 == 0) {
            std.log.info("Simulation cycle {d} completed", .{cycle + 1});

            // Show stats for a few key concepts
            if (knowledge_engine.findConcept("learning")) |concept_id| {
                if (try knowledge_engine.getConceptStats(concept_id)) |stats| {
                    std.log.info("  'learning' concept: activation={d:.3}, relations={d}", .{ stats.activation, stats.relations });
                }
            }
        }

        std.time.sleep(150_000_000); // 150ms between cycles
    }

    // =============================================================================
    // EXAMPLE 7: Final analysis and reporting
    // =============================================================================

    std.log.info("\n=== Final Knowledge Graph Analysis ===", .{});

    // Analyze the most connected concepts
    const analysis_concepts = [_][]const u8{ "events", "publication", "antifragile", "swan", "title", "summary" };

    var most_connected_concept: []const u8 = "";
    var max_relations: usize = 0;
    var highest_complexity: f64 = 0.0;
    var most_complex_concept: []const u8 = "";

    for (analysis_concepts) |concept_name| {
        if (knowledge_engine.findConcept(concept_name)) |concept_id| {
            if (try knowledge_engine.getConceptStats(concept_id)) |stats| {
                std.log.info("Final stats for '{s}': activation={d:.3}, energy={d:.3}, stability={d:.3}, complexity={d:.3}, relations={d}", .{ concept_name, stats.activation, stats.energy, stats.stability, stats.complexity, stats.relations });

                if (stats.relations > max_relations) {
                    max_relations = stats.relations;
                    most_connected_concept = concept_name;
                }

                if (stats.complexity > highest_complexity) {
                    highest_complexity = stats.complexity;
                    most_complex_concept = concept_name;
                }
            }
        }
    }

    std.log.info("\n=== Knowledge Graph Summary ===", .{});
    std.log.info("Most connected concept: '{s}' with {d} relations", .{ most_connected_concept, max_relations });
    std.log.info("Most complex concept: '{s}' with complexity {d:.3}", .{ most_complex_concept, highest_complexity });

    // =============================================================================
    // EXAMPLE 8: Save knowledge graph state (conceptual)
    // =============================================================================

    std.log.info("\n=== Saving Knowledge Graph State ===", .{});

    // This would be where you'd implement serialization
    // For now, we'll just demonstrate the concept

    var concept_count: u32 = 0;
    var total_relations: u32 = 0;
    var total_activation: f64 = 0.0;

    for (analysis_concepts) |concept_name| {
        if (knowledge_engine.findConcept(concept_name)) |concept_id| {
            if (try knowledge_engine.getConceptStats(concept_id)) |stats| {
                concept_count += 1;
                total_relations += @intCast(stats.relations);
                total_activation += stats.activation;
            }
        }
    }

    if (concept_count > 0) {
        const avg_relations = @as(f64, @floatFromInt(total_relations)) / @as(f64, @floatFromInt(concept_count));
        const avg_activation = total_activation / @as(f64, @floatFromInt(concept_count));

        std.log.info("Knowledge graph metrics:", .{});
        std.log.info("  Active concepts: {d}", .{concept_count});
        std.log.info("  Average relations per concept: {d:.2}", .{avg_relations});
        std.log.info("  Average activation level: {d:.3}", .{avg_activation});
    }

    // Wait for all actors to finish processing
    try knowledge_engine.waitForAllActors();

    std.log.info("\n=== Enhanced Simulation Complete ===", .{});
}
