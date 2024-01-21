const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const iw_dep = b.dependency("iw", .{});
    const generated = try generateFiles(b, iw_dep.path("nl80211.h"));
    const exe = b.addExecutable(.{
        .name = "iw",
        .target = target,
        .optimize = optimize,
    });
    exe.link_gc_sections = false;
    exe.root_module.addCMacro("_GNU_SOURCE", "");
    exe.root_module.linkLibrary(b.dependency("libnl_tiny", .{
        .target = target,
        .optimize = optimize,
    }).artifact("nl-tiny"));
    inline for (iw_src_files) |src| {
        exe.addCSourceFile(.{
            .file = iw_dep.path(src),
            .flags = &.{
                "-Wall",
                "-Wextra",
                "-Wundef",
                "-Wstrict-prototypes",
                "-Wno-trigraphs",
                "-fno-strict-aliasing",
                "-fno-common",
                "-Werror-implicit-function-declaration",
                "-Wsign-compare",
                "-Wno-unused-parameter",
                "-Wdeclaration-after-statement",
            },
        });
    }
    exe.step.dependOn(&generated.step.step);
    exe.addCSourceFile(.{ .file = generated.version_path, .flags = &.{} });
    exe.addIncludePath(generated.commands_path.dirname());
    exe.addIncludePath(iw_dep.path("."));
    exe.defineCMacro("CONFIG_LIBNL20", null);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

const GeneratedFiles = struct {
    step: *std.Build.Step.WriteFile,
    version_path: std.Build.LazyPath,
    commands_path: std.Build.LazyPath,
};

fn generateFiles(b: *std.Build, path: std.Build.LazyPath) !GeneratedFiles {
    var buf: [4096]u8 = undefined;
    const version_fmt =
        \\#include "iw.h"
        \\const char iw_version[] = "{s}";
    ;
    var commands = std.ArrayList(u8).init(b.allocator);
    const version_bytes = try std.fmt.allocPrint(b.allocator, version_fmt, .{"6.7.0"});
    const step = b.addWriteFiles();
    const nl80211_h = try std.fs.cwd().readFileAlloc(b.allocator, path.getPath(b), 512 * 1024);
    const start = std.mem.indexOf(u8, nl80211_h, "\tNL80211_CMD_UNSPEC,");
    const end = std.mem.indexOf(u8, nl80211_h, "\t__NL80211_CMD_AFTER_LAST,");
    var stream = std.io.fixedBufferStream(nl80211_h[start.?..end.?]);
    while (try stream.reader().readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const trimmed = std.mem.trimLeft(u8, line, "\t");
        const sub_end = std.mem.indexOf(u8, trimmed, ",");
        if (std.mem.containsAtLeast(u8, line, 1, " = ")) continue;
        if (std.mem.containsAtLeast(u8, line, 1, "reserved")) continue;
        if (std.mem.startsWith(u8, trimmed, "NL80211_CMD_")) {
            try commands.appendSlice(try std.mem.concat(b.allocator, u8, &.{
                "\t[",
                trimmed[0..sub_end.?],
                "]",
                " = ",
                "\"",
            }));
            for (trimmed["NL80211_CMD_".len..sub_end.?]) |c| {
                try commands.append(std.ascii.toLower(c));
            }
            try commands.appendSlice(try std.mem.concat(b.allocator, u8, &.{
                "\",",
                "\n",
            }));
        }
    }
    return .{
        .step = step,
        .version_path = step.add("version.c", version_bytes),
        .commands_path = step.add("nl80211-commands.inc", commands.items),
    };
}

const iw_src_files = [_][]const u8{
    "phy.c",
    "reason.c",
    "status.c",
    "ap.c",
    "connect.c",
    "mpath.c",
    "sar.c",
    "cqm.c",
    "ibss.c",
    "mpp.c",
    "scan.c",
    "reg.c",
    "mesh.c",
    "coalesce.c",
    "bloom.c",
    "roc.c",
    "p2p.c",
    "ps.c",
    "vendor.c",
    "bitrate.c",
    "ftm.c",
    "event.c",
    "sections.c",
    "util.c",
    "nan.c",
    "wowlan.c",
    "sha256.c",
    "ocb.c",
    "station.c",
    "genl.c",
    "mgmt.c",
    "link.c",
    "hwsim.c",
    "measurements.c",
    "info.c",
    "iw.c",
    "survey.c",
    //"version.c",
    "interface.c",
};
