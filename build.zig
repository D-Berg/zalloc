const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zalloc_mod = b.addModule("zalloc", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const lib = b.addLibrary(.{
        .name = "zalloc",
        .linkage = .static,
        .root_module = zalloc_mod,
    });

    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_module = zalloc_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

pub fn infect(mod: *std.Build.Module) void {
    mod.addCMacro("malloc", "zmalloc");
    mod.addCMacro("realloc", "zrealloc");
    mod.addCMacro("calloc", "zcalloc");
    mod.addCMacro("free", "zfree");
}
