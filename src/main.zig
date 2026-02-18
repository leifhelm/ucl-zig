const std = @import("std");
const Allocator = std.mem.Allocator;
const ucl = @import("ucl");
const forall = @import("forall.zig");

const lorem =
    \\Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet.
    \\
    \\Duis autem vel eum iriure dolor in hendrerit in vulputate velit esse molestie consequat, vel illum dolore eu feugiat nulla facilisis at vero eros et accumsan et iusto odio dignissim qui blandit praesent luptatum zzril delenit augue duis dolore te feugait nulla facilisi. Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat.
;

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var dir = try std.fs.cwd().openDir("afl_input", .{});
    defer dir.close();

    try forall.forall_level_variant_bits(Context{ .dir = dir, .allocator = allocator }, write_compressed_lorem);
}

const Context = struct {
    allocator: Allocator,
    dir: std.fs.Dir,
};

fn write_compressed_lorem(ctx: Context, level: u8, comptime variant: ucl.NrvVariant, comptime bits: ucl.Bits) !void {
    var buf: [4096]u8 = undefined;
    const config = ucl.ucl_compress_config_t{
        .bits = bits,
    };
    const compressed = try ucl.compress(ctx.allocator, variant, lorem, &buf, null, level, &config, null);

    var filename: std.io.Writer.Allocating = .init(ctx.allocator);
    defer filename.deinit();
    try filename.writer.print("lorem{}.{}{}.bin", .{ variant, level, bits });

    const file = try ctx.dir.createFile(filename.written(), .{});
    defer file.close();

    var writer_buf: [4096]u8 = undefined;
    var writer = file.writer(&writer_buf);
    try writer.interface.writeByte(switch (variant) {
        .Nrv2b => 'b',
        .Nrv2d => 'd',
        .Nrv2e => 'e',
    });
    try writer.interface.writeByte(@intCast(bits.bits()));
    try writer.interface.writeAll(compressed);
    try writer.interface.flush();
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

// test "fuzz example" {
//     const Context = struct {
//         fn testOne(context: @This(), input: []const u8) anyerror!void {
//             _ = context;
//             // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
//             try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
//         }
//     };
//     try std.testing.fuzz(Context{}, Context.testOne, .{});
// }
