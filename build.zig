const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ucl_zig = b.addModule("ucl", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .link_libc = true,
    });

    const ucl_c = b.addModule("ucl_c", .{
        .root_source_file = b.path("src/ucl.zig"),
        .target = target,
        .link_libc = true,
    });
    ucl_c.addCSourceFiles(.{
        .files = &.{
            "ucl-1.03/src/alloc.c",
            "ucl-1.03/src/n2b_99.c",
            "ucl-1.03/src/n2b_d.c",
            "ucl-1.03/src/n2d_99.c",
            "ucl-1.03/src/n2e_99.c",
            "ucl-1.03/src/ucl_init.c",
            "ucl-1.03/src/ucl_util.c",
            "ucl-1.03/src/ucl_ptr.c",
        },
        .flags = &.{ "-Iucl-1.03", "-Iucl-1.03/include" },
    });

    const exe = b.addExecutable(.{
        .name = "ucl_zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ucl", .module = ucl_zig },
            },
        }),
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ucl", .module = ucl_zig },
                .{ .name = "ucl_c", .module = ucl_c },
            },
        }),
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    const afl = @import("afl_kit");

    // Define a step for generating fuzzing tooling:
    const fuzz = b.step("fuzz", "Generate an instrumented executable for AFL++");
    const afl_obj = b.addObject(.{
        .name = "my_fuzz_obj",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/fuzz.zig"),
            .target = target,
            .optimize = .Debug,
            .imports = &.{
                .{ .name = "ucl", .module = ucl_zig },
                .{ .name = "ucl_c", .module = ucl_c },
            },
        }),
    });

    // Required options:
    afl_obj.root_module.stack_check = false; // not linking with compiler-rt
    afl_obj.root_module.link_libc = true; // afl runtime depends on libc
    afl_obj.root_module.fuzz = true;

    // Generate an instrumented executable:
    const afl_fuzz = afl.addInstrumentedExe(b, target, optimize, null, true, afl_obj, &.{
        "-Iucl-1.03",
        "-Iucl-1.03/include",
        "ucl-1.03/src/alloc.c",
        "ucl-1.03/src/n2b_99.c",
        "ucl-1.03/src/n2d_99.c",
        "ucl-1.03/src/n2e_99.c",
        "ucl-1.03/src/ucl_init.c",
        "ucl-1.03/src/ucl_util.c",
        "ucl-1.03/src/ucl_ptr.c",
    });
    // Install it
    fuzz.dependOn(&b.addInstallBinFile(afl_fuzz.?, "fuzz").step);

    const fuzz_check = b.addExecutable(.{
        .name = "fuzz-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/fuzz-check.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ucl", .module = ucl_zig },
                .{ .name = "ucl_c", .module = ucl_c },
            },
        }),
    });
    b.installArtifact(fuzz_check);
    const fuzz_check_step = b.step("fuzz-check", "Run fuzz binary on input");
    const fuzz_check_cmd = b.addRunArtifact(fuzz_check);
    fuzz_check_step.dependOn(&fuzz_check_cmd.step);
    fuzz_check_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        fuzz_check_cmd.addArgs(args);
    }
}
