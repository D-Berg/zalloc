const std = @import("std");

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

    const c_tests = b.addLibrary(.{
        .name = "test_free",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    c_tests.root_module.addCSourceFiles(.{
        .root = b.path("."),
        .files = &.{
            "tests/free.c",
            "tests/malloc.c",
            "tests/realloc.c",
            "tests/calloc.c",
            "tests/multithreading.c",
        },
    });
    c_tests.addIncludePath(b.path("tests"));
    infect(c_tests.root_module);

    const lib_unit_tests = b.addTest(.{
        .name = "tests",
        .root_module = zalloc_mod,
    });
    lib_unit_tests.linkLibrary(c_tests);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const install_test_runner = b.addInstallArtifact(lib_unit_tests, .{});

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    const install_test_step = b.step("install-tests", "install test runner");
    install_test_step.dependOn(&install_test_runner.step);
}

pub fn infect(mod: *std.Build.Module) void {
    mod.addCMacro("malloc", "zmalloc");
    mod.addCMacro("realloc", "zrealloc");
    mod.addCMacro("calloc", "zcalloc");
    mod.addCMacro("free", "zfree");
}
