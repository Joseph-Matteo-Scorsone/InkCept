const std = @import("std");
const Allocator = std.mem.Allocator;

const KnowledgeEngine = @import("knowledgeEngine.zig").KnowledgeEngine;
const processDocument = @import("documentParser.zig").processDocument;

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

    const sample_text =
        \\Dogs are loyal animals that make great pets. A dog is a mammal and belongs to the canine family.
        \\Cats are independent animals that also make wonderful pets. A cat is a mammal and is part of the feline family.
        \\Both dogs and cats are domestic animals. Dogs bark while cats meow to communicate.
        \\Mammals are warm-blooded animals that give birth to live young. Mammals have hair or fur.
        \\Pets require care and attention from their owners. Good pets provide companionship.
        \\The canine family includes wolves, dogs, and foxes. The feline family includes lions, tigers, and cats.
        \\Training helps dogs learn commands and become better pets. Cats are naturally clean animals.
        \\Veterinarians help keep pets healthy. Regular checkups are important for pet health.
        \\Pet food provides nutrition for domestic animals. Water is essential for all animals.
        \\Exercise keeps pets healthy and happy. Playing with pets strengthens the bond between pets and owners.
    ;

    std.log.info("\n=== Processing Sample Document ===", .{});
    try processDocument(allocator, sample_text, &knowledge_engine);

    // Wait for message propagation
    std.time.sleep(200_000_000); // 200ms

    // =============================================================================
    // EXAMPLE 2: Query and explore the created knowledge graph
    // =============================================================================

    std.log.info("\n=== Exploring Created Knowledge Graph ===", .{});

    // Query some concepts that should have been created
    const queries = [_][]const u8{ "dogs", "cats", "animals", "mammals", "pets", "family" };

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

    // Activate "dogs" and see how activation spreads
    if (try knowledge_engine.query("dogs")) |dogs_id| {
        std.log.info("Activating 'dogs' concept...", .{});

        // Give multiple activations to trigger strong propagation
        for (0..5) |_| {
            try knowledge_engine.activateConcept(dogs_id);
        }

        // Wait for propagation
        std.time.sleep(300_000_000); // 300ms

        // Check related concepts that should have received activation
        const related_concepts = [_][]const u8{ "animals", "mammals", "pets", "canine" };

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

    // Example: Process a technical document
    const technical_text =
        \\Artificial intelligence is a branch of computer science. Machine learning is part of artificial intelligence.
        \\Neural networks are computational models inspired by biological neural networks. Deep learning uses neural networks.
        \\Algorithms process data to make predictions. Training data helps algorithms learn patterns.
        \\Classification algorithms categorize data into different classes. Regression algorithms predict continuous values.
        \\Natural language processing enables computers to understand human language. Computer vision allows machines to interpret images.
        \\Supervised learning uses labeled data for training. Unsupervised learning finds patterns in unlabeled data.
        \\Reinforcement learning learns through trial and error. Feedback helps improve algorithm performance.
        \\Big data requires specialized tools for processing. Cloud computing provides scalable resources.
        \\Data scientists analyze data to extract insights. Machine learning engineers build and deploy models.
    ;

    try processDocument(allocator, technical_text, &knowledge_engine);

    // Wait for processing
    std.time.sleep(300_000_000);

    // =============================================================================
    // EXAMPLE 5: Cross-domain knowledge integration
    // =============================================================================

    std.log.info("\n=== Cross-Domain Knowledge Integration ===", .{});

    // Now we have concepts from both animal domain and AI domain
    // Let's see how they might interact
    const cross_domain_queries = [_][]const u8{ "learning", "intelligence", "training", "processing", "data", "patterns" };

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
        const random_concepts = [_][]const u8{ "dogs", "cats", "animals", "intelligence", "learning", "data", "pets", "algorithms", "training", "patterns", "mammals", "neural" };

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
    const analysis_concepts = [_][]const u8{ "animals", "learning", "training", "data", "intelligence", "mammals", "pets" };

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
    std.log.info("Most connected concept: '{d}' with {d} relations", .{ most_connected_concept, max_relations });
    std.log.info("Most complex concept: '{d}' with complexity {d:.3}", .{ most_complex_concept, highest_complexity });

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

// =============================================================================
// HELPER FUNCTIONS FOR DOCUMENT PROCESSING
// =============================================================================

// Function to read a file and process it
pub fn processDocumentFile(allocator: Allocator, file_path: []const u8, engine: *KnowledgeEngine) !void {
    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        std.log.err("Failed to open file '{s}': {error}", .{ file_path, err });
        return;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    const contents = try allocator.alloc(u8, file_size);
    defer allocator.free(contents);

    _ = try file.readAll(contents);

    std.log.info("Processing file: {s} ({d} bytes)", .{ file_path, file_size });
    try processDocument(allocator, contents, engine);
}

// Function to process multiple documents from a directory
pub fn processDocumentDirectory(allocator: Allocator, dir_path: []const u8, engine: *KnowledgeEngine) !void {
    var dir = std.fs.cwd().openIterableDir(dir_path, .{}) catch |err| {
        std.log.err("Failed to open directory '{s}': {error}", .{ dir_path, err });
        return;
    };
    defer dir.close();

    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        if (entry.kind == .file) {
            // Check if it's a text file
            if (std.mem.endsWith(u8, entry.name, ".txt") or
                std.mem.endsWith(u8, entry.name, ".md"))
            {
                const file_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, entry.name });
                defer allocator.free(file_path);

                try processDocumentFile(allocator, file_path, engine);

                // Small delay between files to allow processing
                std.time.sleep(100_000_000); // 100ms
            }
        }
    }
}

// Function to demonstrate batch processing
pub fn demonstrateBatchProcessing(allocator: Allocator, engine: *KnowledgeEngine) !void {
    std.log.info("\n=== Batch Document Processing Demo ===", .{});

    const documents = [_][]const u8{
        // Document 1: Science
        \\Physics is the study of matter and energy. Chemistry examines the composition of substances.
        \\Biology investigates living organisms and their processes. Mathematics provides tools for scientific analysis.
        \\Experiments test scientific hypotheses. Data collection supports scientific research.
        \\Scientists use the scientific method to investigate natural phenomena.
        ,

        // Document 2: Technology
        \\Computers process information using binary code. Software controls computer hardware.
        \\Programming languages enable software development. Databases store and organize data.
        \\Networks connect computers for communication. Internet protocols enable global connectivity.
        \\Cybersecurity protects digital systems from threats.
        ,

        // Document 3: Medicine
        \\Doctors diagnose and treat medical conditions. Nurses provide patient care and support.
        \\Hospitals serve as centers for medical treatment. Medicine involves the study of human health.
        \\Diseases affect the normal functioning of the body. Treatment aims to restore health.
        \\Prevention helps avoid illness and maintains wellness.
        ,
    };

    for (documents, 0..) |document, i| {
        std.log.info("Processing document {d} of {d}", .{ i + 1, documents.len });
        try processDocument(allocator, document, engine);

        // Allow processing time between documents
        std.time.sleep(200_000_000); // 200ms
    }

    std.log.info("Batch processing completed. Running final maintenance...", .{});
    try engine.runMaintenance();
}
