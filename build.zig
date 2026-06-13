const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const root = b.createModule(.{ .target = target, .optimize = optimize, .root_source_file = b.path("src/main.zig"), .link_libc = true });
    const exe = b.addExecutable(.{
        .name = "way2direct",
        .root_module = root,
    });
    const run_step = b.step("run", "Run way2direct");
    const run_exe = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_exe.addArgs(args);
    }
    run_step.dependOn(&run_exe.step);
    root.linkSystemLibrary("nm",.{});
    b.installArtifact(exe);
}
