const std = @import("std");
const fuzz = @import("fuzz.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);
    if (args.len == 2) {
        const file = try std.fs.cwd().openFileZ(args[1], .{});
        defer file.close();

        var file_buf: [4096]u8 = undefined;
        var file_reader = file.reader(&file_buf);
        const content = try file_reader.interface.allocRemaining(alloc, .unlimited);
        defer alloc.free(content);
        try fuzz.fuzz(content);
    } else {
        std.debug.print("Invalid args\n", .{});
    }
}
