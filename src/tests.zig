const std = @import("std");
const ucl_zig = @import("ucl");
const ucl_c = @import("ucl_c");
const forall = @import("forall.zig");

fn test_compress(content: []const u8, level: u8, comptime variant: ucl_zig.NrvVariant, comptime bits: ucl_zig.Bits) !void {
    var out: [16536]u8 = undefined;
    var reference_out: [16536]u8 = undefined;
    var reference_out_len: ucl_zig.ucl_uint = reference_out.len;

    const config = ucl_zig.CompressConfig{
        .bits = bits,
    };
    const reference_config: ucl_c.ucl_compress_config_t = .{
        .bb_size = @intCast(bits.bits()),
    };

    var result: [16]ucl_zig.ucl_uint = undefined;
    var reference_result: [16]ucl_c.ucl_uint = undefined;

    const compressed = try ucl_zig.compress(std.testing.allocator, variant, content, &out, null, level, &config, &result);
    try std.testing.expect(compressed.len <= out.len);

    const reference_err = switch (variant) {
        .Nrv2b => ucl_c.ucl_nrv2b_99_compress(content.ptr, @intCast(content.len), &reference_out, &reference_out_len, null, level, &reference_config, &reference_result),
        .Nrv2d => ucl_c.ucl_nrv2d_99_compress(content.ptr, @intCast(content.len), &reference_out, &reference_out_len, null, level, &reference_config, &reference_result),
        .Nrv2e => ucl_c.ucl_nrv2e_99_compress(content.ptr, @intCast(content.len), &reference_out, &reference_out_len, null, level, &reference_config, &reference_result),
    };

    try std.testing.expectEqual(ucl_c.UCL_E_OK, reference_err);
    try std.testing.expect(reference_out_len <= reference_out.len);

    const reference = reference_out[0..reference_out_len];
    try std.testing.expectEqualSlices(u8, reference, compressed);
    try std.testing.expectEqualSlices(ucl_zig.ucl_uint, &reference_result, &result);
}

fn compress_decompress(input: []const u8, level: u8, comptime variant: ucl_zig.NrvVariant, comptime bits: ucl_zig.Bits) anyerror!void {
    var out: [16536]u8 = undefined;

    const config = ucl_zig.CompressConfig{
        .bits = bits,
    };

    const compressed = try ucl_zig.compress(std.testing.allocator, variant, input, &out, null, level, &config, null);

    var decompressed: [16536]u8 = @splat(0);
    var decompressed_len: usize = decompressed.len;
    try ucl_zig.decompress(compressed, &decompressed, &decompressed_len, variant, bits, true, null);
    try std.testing.expectEqualSlices(u8, input, decompressed[0..decompressed_len]);
}

const lorem =
    \\Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet.
    \\
    \\Duis autem vel eum iriure dolor in hendrerit in vulputate velit esse molestie consequat, vel illum dolore eu feugiat nulla facilisis at vero eros et accumsan et iusto odio dignissim qui blandit praesent luptatum zzril delenit augue duis dolore te feugait nulla facilisi. Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat.
;
test "compress and decompres lorem" {
    try forall.forall_level_variant_bits(@as([]const u8, lorem), compress_decompress);
}

test "test compress" {
    try forall.forall_level_variant_bits(@as([]const u8, lorem), test_compress);
}

test "compress and decompress random" {
    var random = std.Random.DefaultPrng.init(std.testing.random_seed);
    var random_data: [14000]u8 = undefined;
    random.fill(&random_data);
    try forall.forall_level_variant_bits(@as([]const u8, &random_data), compress_decompress);
}

test "random" {
    var random = std.Random.DefaultPrng.init(std.testing.random_seed);
    var random_data: [14000]u8 = undefined;
    random.fill(&random_data);
    try forall.forall_level_variant_bits(@as([]const u8, &random_data), test_compress);
}
