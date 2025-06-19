const std = @import("std");
const Allocator = std.mem.Allocator;
const KnowledgeEngine = @import("knowledgeEngine.zig").KnowledgeEngine;
const RelationType = @import("knowledgeEngine.zig").RelationType;

const WordInfo = struct {
    word: []u8,
    frequency: u32,
    positions: std.ArrayList(usize), // Track positions in document
    concept_id: ?u64 = null,

    pub fn init(allocator: Allocator, word: []const u8) !WordInfo {
        return WordInfo{
            .word = try allocator.dupe(u8, word),
            .frequency = 1,
            .positions = std.ArrayList(usize).init(allocator),
        };
    }

    pub fn deinit(self: *WordInfo, allocator: Allocator) void {
        allocator.free(self.word);
        self.positions.deinit();
    }
};

const Sentence = struct {
    words: std.ArrayList([]const u8),
    start_pos: usize,
    end_pos: usize,

    pub fn init(allocator: Allocator) Sentence {
        return Sentence{
            .words = std.ArrayList([]const u8).init(allocator),
            .start_pos = 0,
            .end_pos = 0,
        };
    }

    pub fn deinit(self: *Sentence, allocator: Allocator) void {
        for (self.words.items) |word| {
            allocator.free(word); // Free each allocated string
        }
        self.words.deinit(); // Free the ArrayList's internal buffer
    }
};

const CoOccurrence = struct {
    word1: []const u8,
    word2: []const u8,
    frequency: u32,
    distance_sum: u32, // Sum of distances between occurrences
    sentence_cooccur: u32, // Times they appear in same sentence

    pub fn averageDistance(self: CoOccurrence) f64 {
        if (self.frequency == 0) return 0.0;
        return @as(f64, @floatFromInt(self.distance_sum)) / @as(f64, @floatFromInt(self.frequency));
    }
};

pub const DocumentParser = struct {
    const Self = @This();
    const WordMap = std.HashMap(u64, WordInfo, std.hash_map.AutoContext(u64), std.hash_map.default_max_load_percentage);
    const CoOccurMap = std.HashMap(u64, CoOccurrence, std.hash_map.AutoContext(u64), std.hash_map.default_max_load_percentage);
    const StopWordsSet = std.AutoHashMap(u64, void);

    const ScoredWord = struct {
        word: []const u8,
        score: f64,
    };

    allocator: Allocator,
    vocabulary: WordMap,
    cooccurrences: CoOccurMap,
    sentences: std.ArrayList(Sentence),
    stopwords: StopWordsSet,

    pub fn init(allocator: Allocator) !Self {
        var parser = Self{
            .allocator = allocator,
            .vocabulary = WordMap.init(allocator),
            .cooccurrences = CoOccurMap.init(allocator),
            .sentences = std.ArrayList(Sentence).init(allocator),
            .stopwords = StopWordsSet.init(allocator),
        };

        try parser.initStopwords();
        return parser;
    }

    pub fn deinit(self: *Self) void {
        // Clean up vocabulary
        var vocab_iter = self.vocabulary.iterator();
        while (vocab_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.vocabulary.deinit();

        self.cooccurrences.deinit();

        // Clean up sentences
        for (self.sentences.items) |*sentence| {
            sentence.deinit(self.allocator);
        }
        self.sentences.deinit();

        self.stopwords.deinit();
    }

    fn initStopwords(self: *Self) !void {
        const stopwords = [_][]const u8{
            "a",    "an",   "and",  "are",   "as",    "at",    "be",   "by",   "for",  "from",
            "has",  "he",   "in",   "is",    "it",    "its",   "of",   "on",   "that", "the",
            "to",   "was",  "will", "with",  "but",   "or",    "not",  "this", "they", "have",
            "had",  "what", "said", "each",  "which", "their", "time", "if",   "up",   "out",
            "many", "then", "them", "these", "so",    "some",
        };

        for (stopwords) |word| {
            const hash = std.hash_map.hashString(word);
            try self.stopwords.put(hash, {});
        }
    }

    fn isStopword(self: *Self, word: []const u8) bool {
        const hash = std.hash_map.hashString(word);
        return self.stopwords.contains(hash);
    }

    pub fn normalizeWord(self: *Self, allocator: Allocator, word: []const u8) ![]u8 {
        _ = self;
        var normalized = try allocator.alloc(u8, word.len);
        var write_idx: usize = 0;

        for (word) |char| {
            if (std.ascii.isAlphabetic(char)) {
                normalized[write_idx] = std.ascii.toLower(char);
                write_idx += 1;
            }
        }

        return allocator.realloc(normalized, write_idx);
    }

    pub fn parseDocument(self: *Self, text: []const u8) !void {
        std.log.info("Starting document parsing...", .{});

        // First pass: tokenize and build vocabulary
        try self.tokenizeAndBuildVocabulary(text);

        // Second pass: extract sentences
        try self.extractSentences(text);

        // Third pass: analyze co-occurrences
        try self.analyzeCoOccurrences();

        std.log.info("Document parsing complete. Vocabulary size: {any}, Sentences: {any}", .{ self.vocabulary.count(), self.sentences.items.len });
    }

    fn tokenizeAndBuildVocabulary(self: *Self, text: []const u8) !void {
        var position: usize = 0;
        var word_start: ?usize = null;

        for (text, 0..) |char, i| {
            if (std.ascii.isAlphabetic(char)) {
                if (word_start == null) {
                    word_start = i;
                }
            } else {
                if (word_start) |start| {
                    const word = text[start..i];
                    if (word.len > 2) { // Skip very short words
                        const normalized = try self.normalizeWord(self.allocator, word);
                        defer self.allocator.free(normalized);

                        if (!self.isStopword(normalized)) {
                            try self.addWordToVocabulary(normalized, position);
                            position += 1;
                        }
                    }
                    word_start = null;
                }
            }
        }

        // Handle last word if text doesn't end with punctuation
        if (word_start) |start| {
            const word = text[start..];
            if (word.len > 2) {
                const normalized = try self.normalizeWord(self.allocator, word);
                defer self.allocator.free(normalized);

                if (!self.isStopword(normalized)) {
                    try self.addWordToVocabulary(normalized, position);
                }
            }
        }
    }

    fn addWordToVocabulary(self: *Self, word: []const u8, position: usize) !void {
        const hash = std.hash_map.hashString(word);

        if (self.vocabulary.getPtr(hash)) |word_info| {
            word_info.frequency += 1;
            try word_info.positions.append(position);
        } else {
            var word_info = try WordInfo.init(self.allocator, word);
            try word_info.positions.append(position);
            try self.vocabulary.put(hash, word_info);
        }
    }

    fn extractSentences(self: *Self, text: []const u8) !void {
        var sentence = Sentence.init(self.allocator);
        var word_start: ?usize = null;
        var sentence_start: usize = 0;

        for (text, 0..) |char, i| {
            if (std.ascii.isAlphabetic(char)) {
                if (word_start == null) {
                    word_start = i;
                }
            } else {
                // End of word
                if (word_start) |start| {
                    const word = text[start..i];
                    if (word.len > 2) {
                        const normalized = try self.normalizeWord(self.allocator, word);
                        defer self.allocator.free(normalized);

                        if (!self.isStopword(normalized)) {
                            const stored_word = try self.allocator.dupe(u8, normalized);
                            try sentence.words.append(stored_word);
                        }
                    }
                    word_start = null;
                }

                // Check for sentence end
                if (char == '.' or char == '!' or char == '?') {
                    sentence.start_pos = sentence_start;
                    sentence.end_pos = i;

                    if (sentence.words.items.len > 0) {
                        try self.sentences.append(sentence);
                        sentence = Sentence.init(self.allocator);
                    }
                    sentence_start = i + 1;
                }
            }
        }

        // Add final sentence if it exists
        if (sentence.words.items.len > 0) {
            sentence.start_pos = sentence_start;
            sentence.end_pos = text.len;
            try self.sentences.append(sentence);
        } else {
            sentence.deinit(self.allocator);
        }
    }

    fn analyzeCoOccurrences(self: *Self) !void {
        const WINDOW_SIZE = 5; // Words within 5 positions of each other

        // Analyze positional co-occurrences
        var vocab_iter = self.vocabulary.iterator();
        while (vocab_iter.next()) |entry1| {
            const word1 = entry1.value_ptr;

            var vocab_iter2 = self.vocabulary.iterator();
            while (vocab_iter2.next()) |entry2| {
                const word2 = entry2.value_ptr;

                if (std.mem.eql(u8, word1.word, word2.word)) continue;

                // Check positional co-occurrence
                for (word1.positions.items) |pos1| {
                    for (word2.positions.items) |pos2| {
                        const distance = if (pos1 > pos2) pos1 - pos2 else pos2 - pos1;
                        if (distance <= WINDOW_SIZE) {
                            try self.recordCoOccurrence(word1.word, word2.word, @intCast(distance));
                        }
                    }
                }
            }
        }

        // Analyze sentence-level co-occurrences
        for (self.sentences.items) |sentence| {
            for (sentence.words.items, 0..) |word1, i| {
                for (sentence.words.items[i + 1 ..]) |word2| {
                    try self.recordSentenceCoOccurrence(word1, word2);
                }
            }
        }
    }

    fn recordCoOccurrence(self: *Self, word1: []const u8, word2: []const u8, distance: u32) !void {
        // Create a consistent hash for the word pair
        const pair_key = if (std.mem.lessThan(u8, word1, word2))
            try std.fmt.allocPrint(self.allocator, "{s}|{s}", .{ word1, word2 })
        else
            try std.fmt.allocPrint(self.allocator, "{s}|{s}", .{ word2, word1 });
        defer self.allocator.free(pair_key);

        const hash = std.hash_map.hashString(pair_key);

        if (self.cooccurrences.getPtr(hash)) |cooccur| {
            cooccur.frequency += 1;
            cooccur.distance_sum += distance;
        } else {
            try self.cooccurrences.put(hash, CoOccurrence{
                .word1 = if (std.mem.lessThan(u8, word1, word2)) word1 else word2,
                .word2 = if (std.mem.lessThan(u8, word1, word2)) word2 else word1,
                .frequency = 1,
                .distance_sum = distance,
                .sentence_cooccur = 0,
            });
        }
    }

    fn recordSentenceCoOccurrence(self: *Self, word1: []const u8, word2: []const u8) !void {
        const pair_key = if (std.mem.lessThan(u8, word1, word2))
            try std.fmt.allocPrint(self.allocator, "{s}|{s}", .{ word1, word2 })
        else
            try std.fmt.allocPrint(self.allocator, "{s}|{s}", .{ word2, word1 });
        defer self.allocator.free(pair_key);

        const hash = std.hash_map.hashString(pair_key);

        if (self.cooccurrences.getPtr(hash)) |cooccur| {
            cooccur.sentence_cooccur += 1;
        }
    }

    // Knowledge graph
    pub fn buildKnowledgeGraph(self: *Self, engine: *KnowledgeEngine) !void {
        std.log.info("Building knowledge graph from parsed document...", .{});

        // Create concepts from significant words
        try self.createConceptsFromVocabulary(engine);

        // Build relationships based on co-occurrence patterns
        try self.buildRelationshipsFromCoOccurrence(engine);

        // Extract semantic relationships using patterns
        try self.extractSemanticRelationships(engine);

        std.log.info("Knowledge graph construction complete.", .{});
    }

    fn createConceptsFromVocabulary(self: *Self, engine: *KnowledgeEngine) !void {
        const MIN_FREQUENCY = 3; // Only create concepts for words appearing at least 3 times

        var vocab_iter = self.vocabulary.iterator();
        while (vocab_iter.next()) |entry| {
            const word_info = entry.value_ptr;

            if (word_info.frequency >= MIN_FREQUENCY) {
                const concept_id = try engine.createConcept(word_info.word);
                word_info.concept_id = concept_id;

                // Boost activation based on frequency
                const activation_boost = @min(5, word_info.frequency);
                for (0..activation_boost) |_| {
                    try engine.activateConcept(concept_id);
                }
            }
        }
    }

    fn buildRelationshipsFromCoOccurrence(self: *Self, engine: *KnowledgeEngine) !void {
        const MIN_COOCCURRENCE = 2;
        const MAX_AVG_DISTANCE = 3.0;

        var cooccur_iter = self.cooccurrences.iterator();
        while (cooccur_iter.next()) |entry| {
            const cooccur = entry.value_ptr;

            if (cooccur.frequency >= MIN_COOCCURRENCE and
                cooccur.averageDistance() <= MAX_AVG_DISTANCE)
            {
                const concept1_id = self.getConceptId(cooccur.word1);
                const concept2_id = self.getConceptId(cooccur.word2);

                if (concept1_id != null and concept2_id != null) {
                    // Calculate relationship strength
                    const proximity_weight = 1.0 / @max(1.0, cooccur.averageDistance());
                    const frequency_weight = @min(1.0, @as(f64, @floatFromInt(cooccur.frequency)) / 10.0);
                    const sentence_weight = @min(0.5, @as(f64, @floatFromInt(cooccur.sentence_cooccur)) / 5.0);

                    const total_weight = @min(1.0, (proximity_weight + frequency_weight + sentence_weight) / 3.0);

                    // Create bidirectional associations
                    try engine.addRelation(concept1_id.?, concept2_id.?, .AssociatedWith, total_weight);
                    try engine.addRelation(concept2_id.?, concept1_id.?, .AssociatedWith, total_weight);
                }
            }
        }
    }

    fn extractSemanticRelationships(self: *Self, engine: *KnowledgeEngine) !void {
        // Look for common patterns in sentences to identify semantic relationships
        for (self.sentences.items) |sentence| {
            try self.extractIsARelationships(sentence, engine);
            try self.extractPartOfRelationships(sentence, engine);
            try self.extractCausesRelationships(sentence, engine);
        }
    }

    fn extractIsARelationships(self: *Self, sentence: Sentence, engine: *KnowledgeEngine) !void {
        // Look for patterns like "X is a Y" or "X are Y"
        for (sentence.words.items, 0..) |_, i| {
            if (i + 2 < sentence.words.items.len) {
                const word1 = sentence.words.items[i];
                const word2 = sentence.words.items[i + 1];
                const word3 = sentence.words.items[i + 2];

                if ((std.mem.eql(u8, word2, "is") or std.mem.eql(u8, word2, "are")) and
                    std.mem.eql(u8, word3, "a"))
                {
                    if (i + 3 < sentence.words.items.len) {
                        const subject = word1;
                        const object = sentence.words.items[i + 3];

                        const subject_id = self.getConceptId(subject);
                        const object_id = self.getConceptId(object);

                        if (subject_id != null and object_id != null) {
                            try engine.addRelation(subject_id.?, object_id.?, .IsA, 0.8);
                        }
                    }
                }
            }
        }
    }

    fn extractPartOfRelationships(self: *Self, sentence: Sentence, engine: *KnowledgeEngine) !void {
        // Look for patterns like "X part of Y" or "X in Y"
        for (sentence.words.items, 0..) |_, i| {
            if (i + 2 < sentence.words.items.len) {
                const word1 = sentence.words.items[i];
                const word2 = sentence.words.items[i + 1];
                const word3 = sentence.words.items[i + 2];

                if (std.mem.eql(u8, word2, "part") and std.mem.eql(u8, word3, "of")) {
                    if (i + 3 < sentence.words.items.len) {
                        const part = word1;
                        const whole = sentence.words.items[i + 3];

                        const part_id = self.getConceptId(part);
                        const whole_id = self.getConceptId(whole);

                        if (part_id != null and whole_id != null) {
                            try engine.addRelation(part_id.?, whole_id.?, .PartOf, 0.7);
                        }
                    }
                }
            }
        }
    }

    fn extractCausesRelationships(self: *Self, sentence: Sentence, engine: *KnowledgeEngine) !void {
        // Look for causal patterns like "X causes Y" or "X leads to Y"
        for (sentence.words.items, 0..) |_, i| {
            if (i + 2 < sentence.words.items.len) {
                const word1 = sentence.words.items[i];
                const word2 = sentence.words.items[i + 1];
                const word3 = sentence.words.items[i + 2];

                if ((std.mem.eql(u8, word2, "causes") or
                    (std.mem.eql(u8, word2, "leads") and std.mem.eql(u8, word3, "to"))))
                {
                    const effect_idx = if (std.mem.eql(u8, word2, "causes")) i + 2 else i + 3;
                    if (effect_idx < sentence.words.items.len) {
                        const cause = word1;
                        const effect = sentence.words.items[effect_idx];

                        const cause_id = self.getConceptId(cause);
                        const effect_id = self.getConceptId(effect);

                        if (cause_id != null and effect_id != null) {
                            try engine.addRelation(cause_id.?, effect_id.?, .Causes, 0.6);
                        }
                    }
                }
            }
        }
    }

    fn getConceptId(self: *Self, word: []const u8) ?u64 {
        const hash = std.hash_map.hashString(word);
        if (self.vocabulary.get(hash)) |word_info| {
            return word_info.concept_id;
        }
        return null;
    }

    pub fn extractKeywords(self: *Self, top_n: usize) !std.ArrayList([]const u8) {
        var keywords = std.ArrayList([]const u8).init(self.allocator);
        var scored_words = std.ArrayList(ScoredWord).init(self.allocator);
        defer scored_words.deinit();

        // Score words based on frequency, position, and co-occurrence strength
        var vocab_iter = self.vocabulary.iterator();
        while (vocab_iter.next()) |entry| {
            const word_info = entry.value_ptr;

            // TF-IDF-like scoring
            const tf = @as(f64, @floatFromInt(word_info.frequency));
            const position_bonus: f64 = if (word_info.positions.items.len > 0 and word_info.positions.items[0] < 100) 1.2 else 1.0;

            // Calculate co-occurrence strength
            var cooccur_strength: f64 = 0.0;
            var cooccur_iter = self.cooccurrences.iterator();
            while (cooccur_iter.next()) |cooccur_entry| {
                const cooccur = cooccur_entry.value_ptr;
                if (std.mem.eql(u8, cooccur.word1, word_info.word) or
                    std.mem.eql(u8, cooccur.word2, word_info.word))
                {
                    cooccur_strength += @as(f64, @floatFromInt(cooccur.frequency)) / cooccur.averageDistance();
                }
            }

            const final_score = tf * position_bonus * (1.0 + cooccur_strength / 10.0);
            try scored_words.append(.{ .word = word_info.word, .score = final_score });
        }

        // Sort by score (descending)
        std.sort.heap(ScoredWord, scored_words.items, {}, struct {
            fn lessThan(context: void, a: ScoredWord, b: ScoredWord) bool {
                _ = context;
                return a.score > b.score; // Descending order
            }
        }.lessThan);

        // Return top N keywords
        const limit = @min(top_n, scored_words.items.len);
        for (scored_words.items[0..limit]) |item| {
            try keywords.append(try self.allocator.dupe(u8, item.word));
        }

        return keywords;
    }

    pub fn printStatistics(self: *Self) void {
        std.log.info("=== Document Parser Statistics ===", .{});
        std.log.info("Vocabulary size: {any}", .{self.vocabulary.count()});
        std.log.info("Sentences: {any}", .{self.sentences.items.len});
        std.log.info("Co-occurrences: {any}", .{self.cooccurrences.count()});

        // Find most frequent words
        var max_freq: u32 = 0;
        var most_frequent: []const u8 = "";
        var vocab_iter = self.vocabulary.iterator();
        while (vocab_iter.next()) |entry| {
            if (entry.value_ptr.frequency > max_freq) {
                max_freq = entry.value_ptr.frequency;
                most_frequent = entry.value_ptr.word;
            }
        }
        std.log.info("Most frequent word: '{any}' ({any})", .{ most_frequent, max_freq });
    }
};

pub fn processDocument(allocator: Allocator, text: []const u8, engine: *KnowledgeEngine) !void {
    var parser = try DocumentParser.init(allocator);
    defer parser.deinit();

    // Parse the document
    try parser.parseDocument(text);

    // Print statistics
    parser.printStatistics();

    // Extract keywords
    const keywords = try parser.extractKeywords(10);
    defer {
        for (keywords.items) |keyword| {
            allocator.free(keyword);
        }
        keywords.deinit();
    }

    std.log.info("Top keywords:", .{});
    for (keywords.items, 0..) |keyword, i| {
        std.log.info("  {d}: {s}", .{ i + 1, keyword });
    }

    // Build knowledge graph
    try parser.buildKnowledgeGraph(engine);
}

pub fn fileToText(allocator: Allocator, file_path: []const u8) ![]const u8 {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var buffered = std.io.bufferedReader(file.reader());
    var in_stream = buffered.reader();

    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();

    var buf: [1024]u8 = undefined;
    while (true) {
        const line = try in_stream.readUntilDelimiterOrEof(&buf, '\n');
        if (line == null) break;

        try text.appendSlice(line.?);
        try text.append('\n'); // Preserve newlines
    }

    return text.toOwnedSlice(); // returns []u8, implicitly castable to []const u8
}
