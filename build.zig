const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/dwm.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "zwm",
        .root_module = root_module,
    });

    exe.linkSystemLibrary("X11");
    exe.linkSystemLibrary("Xinerama");
    exe.linkSystemLibrary("Xft");
    exe.linkSystemLibrary("fontconfig");
    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the window manager");
    run_step.dependOn(&run_cmd.step);

    const check = b.step("check", "Check if the code compiles");
    const check_module = b.createModule(.{
        .root_source_file = b.path("src/dwm.zig"),
        .target = target,
        .optimize = optimize,
    });
    const check_exe = b.addExecutable(.{
        .name = "zwm",
        .root_module = check_module,
    });
    check_exe.linkSystemLibrary("X11");
    check_exe.linkSystemLibrary("Xft");
    check_exe.linkSystemLibrary("fontconfig");
    check_exe.linkLibC();
    check.dependOn(&check_exe.step);
}
