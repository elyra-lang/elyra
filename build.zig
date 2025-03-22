const std = @import("std");

pub fn build(b: *std.Build) void {
    const options = .{
        .enable_ztracy = b.option(
            bool,
            "enable_ztracy",
            "Enable Tracy profile markers",
        ) orelse false,
        .enable_fibers = b.option(
            bool,
            "enable_fibers",
            "Enable Tracy fiber support",
        ) orelse false,
        .on_demand = b.option(
            bool,
            "on_demand",
            "Build tracy with TRACY_ON_DEMAND",
        ) orelse false,
        .coverage = b.option(
            bool,
            "coverage",
            "Enable coverage reporting",
        ) orelse false,
    };

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // === Build the app === //

    const ztracy = b.dependency("ztracy", .{
        .enable_ztracy = options.enable_ztracy,
        .enable_fibers = options.enable_fibers,
        .on_demand = options.on_demand,
    });

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/elyra/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addImport("ztracy", ztracy.module("root"));

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("elyra", lib_mod);

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "elyra",
        .root_module = lib_mod,
    });
    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "elyrac",
        .root_module = exe_mod,
        .omit_frame_pointer = true,
    });
    exe.linkLibrary(ztracy.artifact("tracy"));
    b.installArtifact(exe);

    // === Run the app === //

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // === Unit tests === //

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);

    const cov_step = b.step("cov", "Run coverage tests");
    const run_cover = b.addSystemCommand(&.{
        "kcov",
        "--clean",
        "--include-pattern=src/",
        "--dump-summary",
        "./coverage",
    });
    run_cover.addArtifactArg(lib_unit_tests);
    cov_step.dependOn(&run_cover.step);
}
