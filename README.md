# InkCept - Intelligent Knowledge Engine

InkCept is a concurrent, actor-based knowledge representation and processing system written in Zig. It implements a dynamic knowledge graph where concepts are represented as autonomous actors that can activate, learn, form relationships, and evolve over time.

InkCept models knowledge as a living network of interconnected concepts. Each concept is an independent actor that:

-   **Activates** when accessed or referenced
-   **Propagates** activation to related concepts
-   **Learns** by strengthening or weakening relationships over time
-   **Evolves** through merging, splitting, or natural decay
-   **Self-manages** its lifecycle based on usage patterns

Architecture
----------------

### Actor-Based Design

-   **Concurrent Processing**: Each concept runs as an independent actor, enabling parallel knowledge processing
-   **Message Passing**: Concepts communicate through asynchronous messages for activation, relation updates, and maintenance
-   **Thread-Safe**: Built on Zig's atomic operations and concurrent data structures

### Knowledge Representation

-   **Dynamic Concepts**: Concepts have activation levels, energy, stability, and complexity metrics
-   **Rich Relations**: Support for multiple relationship types (IsA, PartOf, Causes, AssociatedWith, etc.)
-   **Temporal Awareness**: Tracks access patterns, birth time, and relationship usage
-   **Adaptive Weights**: Relationship strengths adjust based on usage and co-activation patterns

Features
-----------

### Core Knowledge Operations

-   **Document Processing**: Extract and create concepts from text documents
-   **Concept Activation**: Trigger concept activation with spreading activation
-   **Relationship Management**: Create and maintain weighted relationships between concepts
-   **Query Processing**: Find and activate concepts by term lookup

### Intelligent Maintenance

-   **Automatic Decay**: Unused concepts gradually lose activation and energy
-   **Lifecycle Management**: Concepts can merge, split, or die based on usage patterns
-   **Relationship Evolution**: Connection weights adapt based on co-activation patterns
-   **Periodic Cleanup**: Background maintenance processes optimize the knowledge graph

### Monitoring & Analytics

-   **Real-time Stats**: Track activation, energy, stability, and complexity for each concept
-   **Relationship Visualization**: Inspect concept relationships and their properties
-   **Usage Analytics**: Monitor access patterns and concept evolution

Project Structure
--------------------

```
InkCept/
├── src/
│   ├── knowledge_engine.zig   # Main KnowledgeEngine implementation
│   ├── documentParser.zig     # Document reader
│   ├── actor.zig              # Actor implementation
│   ├── engine.zig             # Actor system engine
│   ├── message.zig            # Message passing system
│   └── concurrentHashMap.zig  # Thread-safe hash map
|   └── lockFreeQueue.zig      # Thread-safe queue
├── tests/
│   └── knowledge_tests.zig    # Comprehensive test suite
|
├── example.txt                # Sample document for testing
├── differentExample.txt       # Additional test document
└── build.zig                  # Zig build configuration

```

Building and Testing
------------------------

### Prerequisites

-   Zig 0.14.0 or later

### Build

```
zig build

```

### Run Tests

```
zig build test

```

### Example Test Output
```
File size: 1221 bytes
First 100 chars: Book Title: Fooled by Randomness
Publication Year: 2001
Summary: Explores the role of randomness in
Processing 1221 bytes of text
Concept: Key=6, Value=6
Concept: Key=2, Value=2
Concept: Key=10, Value=10
Concept: Key=1, Value=1
Concept: Key=5, Value=5
Concept: Key=7, Value=7
Concept: Key=9, Value=9
Concept: Key=4, Value=4
Concept: Key=8, Value=8
Concept: Key=3, Value=3
Total concepts created: 10
Concept ID 6: activation=0.285, energy=2.000, relations=6
Concept ID 2: activation=0.442, energy=2.000, relations=6
Concept ID 10: activation=0.285, energy=2.000, relations=6
Concepts after first document: 20
Concepts after second document: 20
Initial stats: activation=0.285
Final stats: activation=0.285
Found 'book' -> ID: 4
Found 'title' -> ID: 7
Found 'randomness' -> ID: 9
Found 'summary' -> ID: 8
Concepts before maintenance: 20
Concepts after maintenance: 20

--- Concept ID: 6 ---
Term: 'antifragile'
Activation: 0.285
Energy: 2.000
Stability: 0.500
Complexity: 0.324
Relations count: 6
Relations:
  1: antifragile -> 'title' (ID: 7) | Weight: 0.378 | Type: AssociatedWith | Last accessed: 0s ago
  2: antifragile -> 'book' (ID: 4) | Weight: 0.311 | Type: AssociatedWith | Last accessed: 0s ago
  3: antifragile -> 'swan' (ID: 10) | Weight: 0.244 | Type: AssociatedWith | Last accessed: 0s ago
  4: antifragile -> 'year' (ID: 5) | Weight: 0.300 | Type: AssociatedWith | Last accessed: 0s ago
  5: antifragile -> 'summary' (ID: 8) | Weight: 0.244 | Type: AssociatedWith | Last accessed: 0s ago
  6: antifragile -> 'publication' (ID: 2) | Weight: 0.467 | Type: AssociatedWith | Last accessed: 0s ago

--- Concept ID: 2 ---
Term: 'publication'
Activation: 0.442
Energy: 2.000
Stability: 0.500
Complexity: 0.583
Relations count: 6
Relations:
  1: publication -> 'swan' (ID: 10) | Weight: 0.533 | Type: AssociatedWith | Last accessed: 0s ago
  2: publication -> 'summary' (ID: 8) | Weight: 0.667 | Type: AssociatedWith | Last accessed: 0s ago
  3: publication -> 'randomness' (ID: 9) | Weight: 0.378 | Type: AssociatedWith | Last accessed: 0s ago
  4: publication -> 'antifragile' (ID: 6) | Weight: 0.467 | Type: AssociatedWith | Last accessed: 0s ago
  5: publication -> 'title' (ID: 7) | Weight: 0.619 | Type: AssociatedWith | Last accessed: 0s ago
  6: publication -> 'year' (ID: 5) | Weight: 0.833 | Type: AssociatedWith | Last accessed: 0s ago

--- Concept ID: 10 ---
Term: 'swan'
Activation: 0.285
Energy: 2.000
Stability: 0.500
Complexity: 0.426
Relations count: 6
Relations:
  1: swan -> 'book' (ID: 4) | Weight: 0.311 | Type: AssociatedWith | Last accessed: 0s ago
  2: swan -> 'antifragile' (ID: 6) | Weight: 0.244 | Type: AssociatedWith | Last accessed: 0s ago
  3: swan -> 'publication' (ID: 2) | Weight: 0.533 | Type: AssociatedWith | Last accessed: 0s ago
  4: swan -> 'title' (ID: 7) | Weight: 0.400 | Type: AssociatedWith | Last accessed: 0s ago
  5: swan -> 'randomness' (ID: 9) | Weight: 0.367 | Type: AssociatedWith | Last accessed: 0s ago
  6: swan -> 'black' (ID: 3) | Weight: 0.700 | Type: AssociatedWith | Last accessed: 0s ago

--- Concept ID: 1 ---
Term: 'events'
Activation: 0.285
Energy: 2.000
Stability: 0.500
Complexity: 0.339
Relations count: 2
Relations:
  1: events -> 'title' (ID: 7) | Weight: 0.311 | Type: AssociatedWith | Last accessed: 0s ago
  2: events -> 'book' (ID: 4) | Weight: 0.367 | Type: AssociatedWith | Last accessed: 0s ago

--- Concept ID: 5 ---
Term: 'year'
Activation: 0.442
Energy: 2.000
Stability: 0.500
Complexity: 0.586
Relations count: 4
Relations:
  1: year -> 'summary' (ID: 8) | Weight: 0.833 | Type: AssociatedWith | Last accessed: 0s ago
  2: year -> 'antifragile' (ID: 6) | Weight: 0.300 | Type: AssociatedWith | Last accessed: 0s ago
  3: year -> 'randomness' (ID: 9) | Weight: 0.378 | Type: AssociatedWith | Last accessed: 0s ago
  4: year -> 'publication' (ID: 2) | Weight: 0.833 | Type: AssociatedWith | Last accessed: 0s ago

Concept 'book' (ID: 1): 2 relations
  1: book --[PartOf]--> title (weight: 0.800)
  2: book --[AssociatedWith]--> randomness (weight: 0.600)

Concept 'title' (ID: 2): 1 relations
  1: title --[Synonym]--> randomness (weight: 0.400)

Concept 'randomness' (ID: 3): 0 relations
```

# Example main
```
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
    // Process a sample document
    // =============================================================================

    const sample_text = try fileToText(allocator, "example.txt");
    defer allocator.free(sample_text);

    std.log.info("\n=== Processing Sample Document ===", .{});
    try processDocument(allocator, sample_text, &knowledge_engine);

    // Wait for message propagation
    try knowledge_engine.waitForAllActors();

    // =============================================================================
    // Query and explore the created knowledge graph
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
    // Demonstrate knowledge propagation
    // =============================================================================

    std.log.info("\n=== Testing Knowledge Propagation ===", .{});

    // Activate "events" and see how activation spreads
    if (try knowledge_engine.query("events")) |id| {
        std.log.info("Activating 'events' concept...", .{});

        // Give multiple activations to trigger strong propagation
        for (0..5) |_| {
            try knowledge_engine.activateConcept(id);
        }

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
    // Different document reading
    // =============================================================================

    std.log.info("\n=== Processing Sample Document ===", .{});

    // Process a different document
    const different_text = try fileToText(allocator, "differentExample.txt");
    defer allocator.free(different_text);

    try processDocument(allocator, different_text, &knowledge_engine);

    // =============================================================================
    // Cross-domain knowledge integration
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
    // Simulation with maintenance and evolution
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
    // Final analysis and reporting
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
    // Save knowledge graph state
    // =============================================================================

    std.log.info("\n=== Saving Knowledge Graph State ===", .{});

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

    std.log.info("\n=== End ===", .{});
}
```

Testing

The project includes comprehensive tests covering:

-   **Initialization**: Engine setup and cleanup
-   **Concept Creation**: Dynamic concept generation from text
-   **Activation Patterns**: Spreading activation and propagation
-   **Relationship Management**: Creating and evolving concept relationships
-   **Lifecycle Operations**: Maintenance, decay, and concept evolution
-   **Cross-domain Processing**: Handling multiple document types
-   **Query Processing**: Finding and activating concepts

### Key Test Categories

1.  **Core Functionality Tests**

    -   Engine initialization and cleanup
    -   Concept creation and management
    -   Basic query operations
2.  **Activation System Tests**

    -   Concept activation and propagation
    -   Spreading activation networks
    -   Energy and stability tracking
3.  **Relationship Tests**

    -   Relation creation and management
    -   Relationship evolution over time
    -   Cross-concept connections
4.  **Maintenance Tests**

    -   Periodic cleanup operations
    -   Concept lifecycle management
    -   System optimization

Configuration
----------------

### Engine Parameters

-   **Thread Count**: Number of worker threads for actor processing
-   **Initial Size**: Starting capacity for internal data structures
-   **Activation Thresholds**: Configurable thresholds for concept behavior

### Concept Behavior

-   **Decay Rate**: How quickly unused concepts lose activation
-   **Propagation Threshold**: Minimum activation needed for spreading
-   **Merge/Split Criteria**: Conditions for concept evolution

Use Cases
------------

### Knowledge Management

-   **Document Analysis**: Extract and organize concepts from text documents
-   **Semantic Search**: Find related concepts through activation spreading
-   **Knowledge Discovery**: Identify emerging relationships and patterns

### AI and Machine Learning

-   **Feature Learning**: Discover relevant features in data
-   **Representation Learning**: Build dynamic knowledge representations
-   **Associative Memory**: Implement content-addressable memory systems

### Research and Analysis

-   **Concept Evolution**: Study how ideas develop and change over time
-   **Network Analysis**: Analyze knowledge graph structure and dynamics
-   **Information Retrieval**: Build intelligent search and recommendation systems

License
----------

This project is licensed under the MIT License - see the LICENSE file for details.