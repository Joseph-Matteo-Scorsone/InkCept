const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ------------------------
    // Library Module
    // ------------------------
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"), // root.zig imports etc.
        .target = target,
        .optimize = optimize,
    });

    // ------------------------
    // Executable Module
    // ------------------------
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("InkCept_lib", lib_mod);

    // ------------------------
    // Build Library
    // ------------------------
    const lib = b.addLibrary(.{
        .name = "InkCept",
        .root_module = lib_mod,
        .linkage = .static,
    });
    b.installArtifact(lib);

    // ------------------------
    // Build Executable
    // ------------------------
    const exe = b.addExecutable(.{
        .name = "InkCept",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // ------------------------
    // Unit Test for the Library (test/test_knowledge_engine.zig)
    // ------------------------
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("test/test_knowledge_engine.zig"),
        .target = target,
        .optimize = optimize,
        .name = "InkCept-tests",
    });
    lib_unit_tests.root_module.addImport("InkCept_lib", lib_mod);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    run_lib_unit_tests.has_side_effects = true;

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
