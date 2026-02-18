const std = @import("std");
const ucl_zig = @import("ucl");
const ucl_c = @import("ucl_c");

var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
const allocator = gpa.allocator();

export fn zig_fuzz_init() void {}
export fn zig_fuzz_test(buf: [*]u8, len: isize) void {
    const input = buf[0..@intCast(len)];
    fuzz(input) catch unreachable;
}

pub fn fuzz(content: []const u8) !void {
    // return test_compress(content);
    return test_decompress(content);
}

fn test_compress(content: []const u8) !void {
    if (content.len < @sizeOf(ucl_zig.ucl_compress_config_t) + 1) {
        return;
    }
    const level = content[@sizeOf(ucl_zig.ucl_compress_config_t)] % 9 + 1;
    const input = content[@sizeOf(ucl_zig.ucl_compress_config_t) + 1 ..];
    const config: ucl_zig.ucl_compress_config_t = @bitCast(content[0..@sizeOf(ucl_zig.ucl_compress_config_t)].*);

    // try test_compress_level(input, 1, .Nrv2b, config);
    // try test_compress_level(input, 1, .Nrv2d, config);
    // try test_compress_level(input, 1, .Nrv2e, config);

    try test_compress_level(input, level, .Nrv2d, config);
    // try test_compress_level(input, 2, .Nrv2d, config);
    // try test_compress_level(input, 3, .Nrv2d, config);
    // try test_compress_level(input, 4, .Nrv2d, config);
    // try test_compress_level(input, 5, .Nrv2d, config);
    // try test_compress_level(input, 6, .Nrv2d, config);
    // try test_compress_level(input, 7, .Nrv2d, config);
    // try test_compress_level(input, 8, .Nrv2d, config);
    // try test_compress_level(input, 9, .Nrv2d, config);
}

fn test_compress_level(content: []const u8, level: u8, comptime variant: ucl_zig.NrvVariant, config: ucl_zig.ucl_compress_config_t) !void {
    var out: [1024 * 1024]u8 = undefined;
    var reference_out: [1024 * 1024]u8 = undefined;
    var reference_out_len: ucl_zig.ucl_uint = reference_out.len;

    const reference_config: ucl_c.ucl_compress_config_t = @bitCast(config);
    var result: [16]ucl_zig.ucl_uint = undefined;
    var reference_result: [16]ucl_c.ucl_uint = undefined;

    const reference_err = switch (variant) {
        .Nrv2b => ucl_c.ucl_nrv2b_99_compress(content.ptr, @intCast(content.len), &reference_out, &reference_out_len, null, level, &reference_config, &reference_result),
        .Nrv2d => ucl_c.ucl_nrv2d_99_compress(content.ptr, @intCast(content.len), &reference_out, &reference_out_len, null, level, &reference_config, &reference_result),
        .Nrv2e => ucl_c.ucl_nrv2e_99_compress(content.ptr, @intCast(content.len), &reference_out, &reference_out_len, null, level, &reference_config, &reference_result),
    };

    const call_result = ucl_zig.compress(allocator, variant, content, &out, null, level, &config, &result);
    try std.testing.expectEqual(reference_err, ucl_zig.int_from_ucl_error_return(call_result));

    if (reference_err != ucl_zig.UCL_E_OK) {
        return;
    }
    const compressed = try call_result;
    try std.testing.expect(compressed.len <= out.len);
    try std.testing.expect(reference_out_len <= reference_out.len);

    const reference = reference_out[0..reference_out_len];
    try std.testing.expectEqualSlices(u8, reference, compressed);
    try std.testing.expectEqualSlices(ucl_zig.ucl_uint, &reference_result, &result);
}

fn test_decompress(input: []const u8) !void {
    if (input.len == 0) return;
    switch (input[0]) {
        'b' => try test_decompress_variant(input[1..], .Nrv2b),
        'd' => try test_decompress_variant(input[1..], .Nrv2d),
        'e' => try test_decompress_variant(input[1..], .Nrv2e),
        else => return,
    }
}

fn test_decompress_variant(input: []const u8, comptime variant: ucl_zig.NrvVariant) !void {
    if (input.len == 0) return;
    var decompressed: [4096]u8 = undefined;
    var decompressed_len: usize = undefined;
    const compressed = input[1..];
    switch (input[0]) {
        8 => ucl_zig.decompress(compressed, &decompressed, &decompressed_len, variant, .bits8, true, null) catch {},
        16 => ucl_zig.decompress(compressed, &decompressed, &decompressed_len, variant, .bits16, true, null) catch {},
        32 => ucl_zig.decompress(compressed, &decompressed, &decompressed_len, variant, .bits32, true, null) catch {},
        else => return,
    }
}
