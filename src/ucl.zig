pub const ucl_uint32 = c_uint;
pub const ucl_int32 = c_int;
pub const ucl_uint = c_uint;
pub const ucl_int = c_int;
pub const ucl_bool = c_int;
pub const ucl_compress_t = ?*const fn ([*c]const u8, ucl_uint, [*c]u8, [*c]ucl_uint, ?*anyopaque) callconv(.c) c_int;
pub const ucl_decompress_t = ?*const fn ([*c]const u8, ucl_uint, [*c]u8, [*c]ucl_uint, ?*anyopaque) callconv(.c) c_int;
pub const ucl_optimize_t = ?*const fn ([*c]u8, ucl_uint, [*c]u8, [*c]ucl_uint, ?*anyopaque) callconv(.c) c_int;
pub const ucl_compress_dict_t = ?*const fn ([*c]const u8, ucl_uint, [*c]u8, [*c]ucl_uint, ?*anyopaque, [*c]const u8, ucl_uint) callconv(.c) c_int;
pub const ucl_decompress_dict_t = ?*const fn ([*c]const u8, ucl_uint, [*c]u8, [*c]ucl_uint, ?*anyopaque, [*c]const u8, ucl_uint) callconv(.c) c_int;
pub const ucl_progress_callback_t = extern struct {
    callback: ?*const fn (ucl_uint, ucl_uint, c_int, ?*anyopaque) callconv(.c) void = @import("std").mem.zeroes(?*const fn (ucl_uint, ucl_uint, c_int, ?*anyopaque) callconv(.c) void),
    user: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
};
pub const struct_ucl_compress_config_t = extern struct {
    bb_endian: c_int = -1,
    bb_size: c_int = -1,
    max_offset: ucl_uint = @import("std").math.maxInt(ucl_uint),
    max_match: ucl_uint = @import("std").math.maxInt(ucl_uint),
    s_level: c_int = -1,
    h_level: c_int = -1,
    p_level: c_int = -1,
    c_flags: c_int = -1,
    m_size: ucl_uint = @import("std").math.maxInt(ucl_uint),
};
pub extern fn ucl_nrv2b_99_compress(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, cb: [*c]ucl_progress_callback_t, level: c_int, conf: [*c]const struct_ucl_compress_config_t, result: [*c]ucl_uint) c_int;
pub extern fn ucl_nrv2d_99_compress(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, cb: [*c]ucl_progress_callback_t, level: c_int, conf: [*c]const struct_ucl_compress_config_t, result: [*c]ucl_uint) c_int;
pub extern fn ucl_nrv2e_99_compress(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, cb: [*c]ucl_progress_callback_t, level: c_int, conf: [*c]const struct_ucl_compress_config_t, result: [*c]ucl_uint) callconv(.c) c_int;
pub extern fn ucl_nrv2b_decompress_8(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2b_decompress_le16(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2b_decompress_le32(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2b_decompress_safe_8(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2b_decompress_safe_le16(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2b_decompress_safe_le32(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2d_decompress_8(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2d_decompress_le16(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2d_decompress_le32(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2d_decompress_safe_8(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2d_decompress_safe_le16(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2d_decompress_safe_le32(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2e_decompress_8(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2e_decompress_le16(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2e_decompress_le32(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2e_decompress_safe_8(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2e_decompress_safe_le16(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2e_decompress_safe_le32(src: [*c]const u8, src_len: ucl_uint, dst: [*c]u8, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2b_test_overlap_8(buf: [*c]const u8, src_off: ucl_uint, src_len: ucl_uint, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2b_test_overlap_le16(buf: [*c]const u8, src_off: ucl_uint, src_len: ucl_uint, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2b_test_overlap_le32(buf: [*c]const u8, src_off: ucl_uint, src_len: ucl_uint, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2d_test_overlap_8(buf: [*c]const u8, src_off: ucl_uint, src_len: ucl_uint, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2d_test_overlap_le16(buf: [*c]const u8, src_off: ucl_uint, src_len: ucl_uint, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2d_test_overlap_le32(buf: [*c]const u8, src_off: ucl_uint, src_len: ucl_uint, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2e_test_overlap_8(buf: [*c]const u8, src_off: ucl_uint, src_len: ucl_uint, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2e_test_overlap_le16(buf: [*c]const u8, src_off: ucl_uint, src_len: ucl_uint, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub extern fn ucl_nrv2e_test_overlap_le32(buf: [*c]const u8, src_off: ucl_uint, src_len: ucl_uint, dst_len: [*c]ucl_uint, wrkmem: ?*anyopaque) c_int;
pub const UCL_E_OK = @as(c_int, 0);
pub const UCL_E_ERROR = -@as(c_int, 1);
pub const UCL_E_INVALID_ARGUMENT = -@as(c_int, 2);
pub const UCL_E_OUT_OF_MEMORY = -@as(c_int, 3);
pub const UCL_E_NOT_COMPRESSIBLE = -@as(c_int, 101);
pub const UCL_E_INPUT_OVERRUN = -@as(c_int, 201);
pub const UCL_E_OUTPUT_OVERRUN = -@as(c_int, 202);
pub const UCL_E_LOOKBEHIND_OVERRUN = -@as(c_int, 203);
pub const UCL_E_EOF_NOT_FOUND = -@as(c_int, 204);
pub const UCL_E_INPUT_NOT_CONSUMED = -@as(c_int, 205);
pub const UCL_E_OVERLAP_OVERRUN = -@as(c_int, 206);
pub const ucl_compress_config_t = struct_ucl_compress_config_t;
