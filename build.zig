const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const codec_dep = b.dependency("binary_codec", .{
        .target = target,
        .optimize = optimize,
    });
    const codec_mod = codec_dep.module("binary_codec");

    const mod = b.addModule("risk_binary", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.addImport("binary_codec", codec_mod);

    const test_step = b.step("test", "Run tests");

    const mod_tests = b.addTest(.{ .root_module = mod });
    test_step.dependOn(&b.addRunArtifact(mod_tests).step);

    // golden interop frames produced by the engine-side RbpFrame encoder
    const golden_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("tests/golden_interop.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "risk_binary", .module = mod },
            .{ .name = "binary_codec", .module = codec_mod },
        },
    }) });
    test_step.dependOn(&b.addRunArtifact(golden_tests).step);
}
