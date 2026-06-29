const std = @import("std");
const Allocator = std.mem.Allocator;
pub const NrvVariant = enum {
    Nrv2b,
    Nrv2d,
    Nrv2e,
};
pub const ucl_uint = c_uint;
pub const ucl_progress_callback_t = struct {
    callback: *const fn (ucl_uint, ucl_uint, c_int, ?*anyopaque) void,
    user: ?*anyopaque = null,
};
pub const struct_ucl_compress_config_t = struct {
    bits: Bits = .bits8,
    max_offset: ucl_uint = std.math.maxInt(ucl_uint),
    max_match: ucl_uint = std.math.maxInt(ucl_uint),
};
pub const Bits = enum {
    bits8,
    bits16,
    bits32,
    pub fn bits(self: @This()) c_uint {
        return switch (self) {
            .bits8 => 8,
            .bits16 => 16,
            .bits32 => 32,
        };
    }
};

inline fn unaligned_get(comptime T: type, slice: []const u8) T {
    return @bitCast(slice[0..@sizeOf(T)].*);
}

inline fn getbit_8(bb: *u32, bc: *u5, src: []const u8, ilen: *ucl_uint, comptime safe: bool) Error!u1 {
    _ = bc;
    bb.* = if (bb.* & 0x7f != 0) bb.* * 2 else blk: {
        if (safe and ilen.* >= src.len) return Error.InputOverrun;
        const tmp = @as(u32, @intCast(src[ilen.*])) * 2 + 1;
        ilen.* += 1;
        break :blk tmp;
    };
    return @truncate(bb.* >> 8);
}
inline fn getbit_le16(bb: *u32, bc: *u5, src: []const u8, ilen: *ucl_uint, comptime safe: bool) Error!u1 {
    _ = bc;
    bb.* *%= 2;
    if (bb.* & 0xffff == 0) {
        if (safe and ilen.* + 1 >= src.len) return Error.InputOverrun;
        bb.* = (@as(u32, @intCast(unaligned_get(u16, src[ilen.*..])))) * 2 + 1;
        ilen.* += 2;
    }
    return @truncate(bb.* >> 16);
}
inline fn getbit_le32(bb: *u32, bc: *u5, src: []const u8, ilen: *ucl_uint, comptime safe: bool) Error!u1 {
    if (bc.* > 0) {
        bc.* -= 1;
        return @truncate(bb.* >> bc.*);
    } else {
        if (safe and ilen.* + 3 >= src.len) return Error.InputOverrun;
        bc.* = 31;
        bb.* = unaligned_get(u32, src[ilen.*..]);
        ilen.* += 4;
        return @truncate(bb.* >> 31);
    }
}
pub fn decompress(src: []const u8, dst: []u8, dst_len: *usize, comptime variant: NrvVariant, comptime bits: Bits, comptime safe: bool, test_overlap: anytype) Error!void {
    const getbit = switch (bits) {
        .bits8 => getbit_8,
        .bits16 => getbit_le16,
        .bits32 => getbit_le32,
    };
    var bb: u32 = 0;
    var bc: u5 = 0;
    var ilen: ucl_uint = if (test_overlap == null) 0 else test_overlap.src_off;
    var olen: ucl_uint = 0;
    var last_m_off: ucl_uint = 1;
    var src_len = src.len;
    const oend: usize = dst.len;

    defer dst_len.* = olen;

    if (test_overlap != null) {
        src_len += test_overlap.src_off;
        if (safe and oend >= src_len) return UCL_E_OVERLAP_OVERRUN;
    }

    while (true) {
        var m_len: ucl_uint = undefined;

        while (try getbit(&bb, &bc, src, &ilen, safe) != 0) {
            if (safe and ilen >= src_len) return Error.InputOverrun;
            if (safe and olen >= oend) return Error.OutputOverrun;
            if (test_overlap != null) {
                if (safe and olen > ilen) return Error.OverlapOverrun;
            } else {
                dst[olen] = src[ilen];
            }
            olen += 1;
            ilen += 1;
        }
        var m_off: ucl_uint = 1;
        while (true) {
            m_off = m_off * 2 + try getbit(&bb, &bc, src, &ilen, safe);
            if (safe and ilen >= src_len) return Error.InputOverrun;
            if (safe and m_off > 0xffffff + 3) return Error.LookbehindOverrun;
            if (try getbit(&bb, &bc, src, &ilen, safe) != 0) break;
            if (variant == .Nrv2d or variant == .Nrv2e) {
                m_off = (m_off - 1) * 2 + try getbit(&bb, &bc, src, &ilen, safe);
            }
        }
        if (m_off == 2) {
            m_off = last_m_off;
            if (variant == .Nrv2d or variant == .Nrv2e) {
                m_len = try getbit(&bb, &bc, src, &ilen, safe);
            }
        } else {
            if (safe and ilen >= src_len) return Error.InputOverrun;
            m_off = (m_off -% 3) * 256 + src[ilen];
            ilen += 1;
            if (m_off == 0xffffffff)
                break;
            if (variant == .Nrv2d or variant == .Nrv2e) {
                m_len = (m_off ^ 0xffffffff) & 1;
                m_off >>= 1;
            }
            m_off += 1;
            last_m_off = m_off;
        }
        if (variant == .Nrv2b) m_len = try getbit(&bb, &bc, src, &ilen, safe);
        if (variant != .Nrv2e) m_len = m_len * 2 + try getbit(&bb, &bc, src, &ilen, safe);
        if (variant == .Nrv2e and m_len != 0) {
            m_len = @as(ucl_uint, 1) + try getbit(&bb, &bc, src, &ilen, safe);
        } else if (variant == .Nrv2e and try getbit(&bb, &bc, src, &ilen, safe) != 0) {
            m_len = @as(ucl_uint, 3) + try getbit(&bb, &bc, src, &ilen, safe);
        } else if (variant == .Nrv2e or m_len == 0) {
            m_len += 1;
            while (true) {
                m_len = m_len * 2 + try getbit(&bb, &bc, src, &ilen, safe);
                if (safe and ilen >= src_len) return Error.InputOverrun;
                if (safe and m_len >= oend) return Error.OutputOverrun;
                if (try getbit(&bb, &bc, src, &ilen, safe) != 0) break;
            }
            m_len += if (variant == .Nrv2e) 3 else 2;
        }
        m_len += @intFromBool(m_off > M2_MAX_OFFSET(variant));
        if (safe and olen + m_len > oend) return Error.OutputOverrun;
        if (safe and m_off > olen) return Error.LookbehindOverrun;
        if (olen + m_len >= dst.len) return Error.OutputOverrun;
        if (test_overlap == null) {
            var m_pos: [*]const u8 = (dst.ptr + olen) - m_off;
            dst[olen] = m_pos[0];
            olen += 1;
            m_pos += 1;
            while (true) {
                dst[olen] = m_pos[0];
                olen += 1;
                m_pos += 1;
                m_len -= 1;
                if (m_len == 0) break;
            }
        } else {
            olen += m_len + 1;
            if (safe and olen > ilen) return UCL_E_OVERLAP_OVERRUN;
        }
    }
    return if (ilen == src_len) {} else if (ilen < src_len)
        Error.InputNotConsumed
    else
        Error.InputOverrun;
}

pub const swd_uint = if (SWD_N + 2 * SWD_F < std.math.maxInt(u16)) u16 else u32;
const SlidingWindowDictionary = struct {
    const Self = @This();

    n: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    f: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    threshold: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    hmask: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    max_chain: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    nice_length: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    use_best_off: bool = @import("std").mem.zeroes(bool),
    lazy_insert: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    m_len: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    m_off: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    look: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    b_char: c_int = @import("std").mem.zeroes(c_int),
    c: *Compress,
    m_pos: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    dict: []const u8 = @import("std").mem.zeroes([]const u8),
    dict_end: [*c]const u8 = @import("std").mem.zeroes([*c]const u8),
    ip: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    bp: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    rp: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    b_size: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    b_wrap: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    node_count: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    first_rp: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    b: []u8 = &.{},
    head3: []swd_uint = &.{},
    succ3: []swd_uint = &.{},
    best3: []swd_uint = &.{},
    llen3: []swd_uint = &.{},
    head2: []swd_uint = &.{},

    pub fn swd_initdict(self: *Self, dict: []const u8) void {
        var offset: usize = 0;
        var length = dict.len;
        self.dict = &.{};
        self.dict_end = null;

        if (length == 0) return;
        if (length > self.n) {
            offset = length - self.n;
            length = self.n;
        }

        self.dict = dict[offset..length];
        self.dict_end = dict.ptr + offset + length;
        @memcpy(self.b[0..length], self.dict);
        self.ip = @intCast(length);
    }
    pub fn swd_insertdict(self: *Self, arg_node: ucl_uint, arg_len: usize) void {
        var node = arg_node;
        var len = arg_len;
        self.node_count = self.n - @as(ucl_uint, @intCast(len));
        self.first_rp = node;
        while (len > 0) : (node += 1) {
            len -= 1;

            var key = HEAD3(self.b, node);
            self.succ3[node] = self.head3[key];
            self.head3[key] = @intCast(node);
            self.best3[node] = @intCast(self.f + 1);
            self.llen3[key] += 1;
            std.debug.assert(self.llen3[key] <= self.n);
            {
                key = HEAD2(self.b, node);
                self.head2[key] = @intCast(node);
            }
        }
    }
    pub fn swd_init(self: *Self, allocator: Allocator, dict: []const u8) Error!void {
        self.b = &.{};
        self.head3 = &.{};
        self.succ3 = &.{};
        self.best3 = &.{};
        self.llen3 = &.{};
        self.head2 = &.{};

        if (self.n == 0) {
            self.n = SWD_N;
        }
        if (self.f == 0) {
            self.f = SWD_F;
        }
        self.threshold = SWD_THRESHOLD;
        if (self.n > SWD_N or self.f > SWD_F)
            return Error.InvalidArgument;
        self.b = try allocator.alloc(u8, self.n + 2 * self.f);
        errdefer allocator.free(self.b);
        self.head3 = try allocator.alloc(swd_uint, SWD_HSIZE);
        errdefer allocator.free(self.head3);
        self.succ3 = try allocator.alloc(swd_uint, self.n + self.f);
        errdefer allocator.free(self.succ3);
        self.best3 = try allocator.alloc(swd_uint, self.n + self.f);
        errdefer allocator.free(self.best3);
        self.llen3 = try allocator.alloc(swd_uint, SWD_HSIZE);
        errdefer allocator.free(self.llen3);
        {
            self.head2 = try allocator.alloc(swd_uint, 65536);
            errdefer allocator.free(self.head2);
        }

        // defaults
        self.max_chain = SWD_MAX_CHAIN;
        self.nice_length = self.f;
        self.use_best_off = false;
        self.lazy_insert = 0;

        self.b_size = self.n + self.f;
        if ((self.b_size + self.f) >= std.math.maxInt(swd_uint)) return Error.Error;
        self.b_wrap = self.b.ptr + self.b_size;
        self.node_count = self.n;

        @memset(self.llen3[0..SWD_HSIZE], 0);
        {
            @memset(self.head2[0..65536], NIL2);
        }

        self.ip = 0;
        self.swd_initdict(dict);
        self.bp = self.ip;
        self.first_rp = self.ip;

        std.debug.assert(self.ip + self.f <= self.b_size);
        self.look = @as(ucl_uint, @intCast(self.c.in_end - self.c.ip));
        if (self.look > 0) {
            if (self.look > self.f) {
                self.look = self.f;
            }
            @memcpy(self.b[self.ip..self.look], self.c.ip);
            self.c.ip += self.look;
            self.ip += self.look;
        }
        if (self.ip == self.b_size) {
            self.ip = 0;
        }

        if (self.look >= 2 and self.dict.len > 0) {
            self.swd_insertdict(0, self.dict.len);
        }

        self.rp = self.first_rp;
        if (self.rp >= self.node_count) {
            self.rp -= self.node_count;
        } else {
            self.rp += self.b_size - self.node_count;
        }
    }
    pub fn swd_exit(self: *Self, allocator: Allocator) void {
        // free in reverse order of allocations
        allocator.free(self.head2);
        self.head2 = &.{};
        allocator.free(self.llen3);
        self.llen3 = &.{};
        allocator.free(self.best3);
        self.best3 = &.{};
        allocator.free(self.succ3);
        self.succ3 = &.{};
        allocator.free(self.head3);
        self.head3 = &.{};
        allocator.free(self.b);
        self.b = &.{};
    }
    pub fn swd_getbyte(self: *Self) void {
        const c: c_int = getbyte(self.c);
        if (c < 0) {
            if (self.look > 0) {
                self.look -= 1;
            }
        } else {
            self.b[self.ip] = @as(u8, @bitCast(@as(i8, @truncate(c))));
            if (self.ip < self.f) {
                self.b_wrap[self.ip] = @as(u8, @bitCast(@as(i8, @truncate(c))));
            }
        }
        self.ip += 1;
        if (self.ip == self.b_size) {
            self.ip = 0;
        }
        self.bp += 1;
        if (self.bp == self.b_size) {
            self.bp = 0;
        }
        self.rp += 1;
        if (self.rp == self.b_size) {
            self.rp = 0;
        }
    }
    /// remove node from lists
    pub fn swd_remove_node(self: *Self, node: ucl_uint) void {
        if (self.node_count == 0) {
            var key = HEAD3(self.b, node);
            std.debug.assert(self.llen3[key] > 0);
            self.llen3[key] -%= 1;

            {
                key = HEAD2(self.b, node);
                std.debug.assert(self.head2[key] != NIL2);
                if (@as(ucl_uint, @intCast(self.head2[key])) == node) {
                    self.head2[key] = NIL2;
                }
            }
        } else {
            self.node_count -= 1;
        }
    }
    pub fn swd_accept(self: *Self, arg_n: ucl_uint) void {
        var n = arg_n;
        std.debug.assert(n <= self.look);

        if (n > 0) while (true) {
            var key: ucl_uint = undefined;

            self.swd_remove_node(self.*.rp);

            // add bp into HEAD3
            key = HEAD3(self.b, self.bp);
            self.succ3[self.bp] = self.head3[key];
            self.head3[key] = @intCast(self.bp);
            self.best3[self.bp] = @intCast(self.f + 1);
            self.llen3[key] += 1;
            std.debug.assert(self.llen3[key] <= self.n);
            {
                // add bp into HEAD2
                key = HEAD2(self.b, self.bp);
                self.head2[key] = @intCast(self.bp);
            }

            self.swd_getbyte();
            n -= 1;
            if (!(n > 0)) break;
        };
    }
    pub fn swd_search(self: *Self, arg_node: ucl_uint, arg_cnt: ucl_uint) void {
        var node = arg_node;
        var cnt = arg_cnt;
        var p1: [*c]const u8 = undefined;
        var p2: [*c]const u8 = undefined;
        var px: [*c]const u8 = undefined;
        var m_len: ucl_uint = self.m_len;
        const b: [*c]const u8 = self.b.ptr;
        const bp: [*c]const u8 = self.b.ptr + self.bp;
        const bx: [*c]const u8 = (self.b.ptr + self.bp) + self.look;

        std.debug.assert(self.m_len > 0);

        var scan_end1 = bp[m_len - 1];
        while (cnt > 0) : (node = self.succ3[node]) {
            cnt -= 1;
            p1 = bp;
            p2 = b + node;
            px = bx;

            std.debug.assert(m_len < self.look);

            if (p2[m_len - 1] == scan_end1 and p2[m_len] == p1[m_len] and
                p2[0] == p1[0] and p2[1] == p1[1])
            {
                var i: ucl_uint = undefined;
                std.debug.assert(std.mem.eql(u8, bp[0..3], b[node .. node + 3]));

                p1 += 2;
                p2 += 2;
                while (true) {
                    p1 += 1;
                    p2 += 1;
                    if (!(p1 < px and p1.* == p2.*)) break;
                }
                i = @as(ucl_uint, @intCast(p1 - bp));

                std.debug.assert(std.mem.eql(u8, bp[0..i], b[node .. node + i]));

                if (i > m_len) {
                    self.m_len = i;
                    m_len = i;
                    self.m_pos = node;
                    if (m_len == self.look) return;
                    if (m_len >= self.nice_length) return;
                    if (m_len > @as(ucl_uint, @intCast(self.best3[node]))) return;
                    scan_end1 = bp[m_len - 1];
                }
            }
        }
    }
    pub fn swd_search2(self: *Self) bool {
        std.debug.assert(self.look >= 2);
        std.debug.assert(self.m_len > 0);

        const key = self.head2[HEAD2(self.b, self.bp)];
        if (key == NIL2) return false;
        std.debug.assert(std.mem.eql(u8, self.b[self.bp .. self.bp + 2], self.b[key .. key + 2]));
        if (self.m_len < 2) {
            self.m_len = 2;
            self.m_pos = key;
        }
        return true;
    }
    pub fn swd_findbest(self: *Self) void {
        std.debug.assert(self.m_len > 0);

        // get current head, add bp into HEAD3
        var key = HEAD3(self.b, self.bp);
        const node = s_get_head3(self, key);
        self.succ3[self.bp] = node;
        var cnt = self.llen3[key];
        self.llen3[key] += 1;
        std.debug.assert(self.llen3[key] <= self.n + self.f);
        if (cnt > self.max_chain and self.max_chain > 0) {
            cnt = @intCast(self.max_chain);
        }
        self.head3[key] = @intCast(self.bp);

        self.b_char = self.b[self.bp];
        const len = self.m_len;
        if (self.m_len >= self.look) {
            if (self.look == 0) {
                self.b_char = -1;
            }
            self.m_off = 0;
            self.best3[self.bp] = @intCast(self.f + 1);
        } else {
            if (self.swd_search2() and self.look >= 3) {
                self.swd_search(node, cnt);
            }
            if (self.m_len > len) {
                self.m_off = swd_pos2off(self, self.m_pos);
            }
            self.best3[self.bp] = @intCast(self.m_len);
        }

        self.swd_remove_node(self.rp);

        // add bp into HEAD2
        {
            key = HEAD2(self.b, self.bp);
            self.head2[key] = @intCast(self.bp);
        }
    }
};
const BitBuffer = struct {
    const Self = @This();

    b: u32 = @import("std").mem.zeroes(u32),
    k: c_uint = @import("std").mem.zeroes(c_uint),
    c_s: c_uint = @import("std").mem.zeroes(c_uint),
    c_s8: c_uint = @import("std").mem.zeroes(c_uint),
    p: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    op: [*c]u8 = @import("std").mem.zeroes([*c]u8),

    pub fn config(self: *Self, bitsize: Bits) void {
        // TODO: rework arguments
        self.c_s = bitsize.bits();
        self.c_s8 = @divTrunc(bitsize.bits(), 8);
        self.b = 0;
        self.k = 0;
        self.p = null;
        self.op = null;
    }
    pub fn write_bits(self: *Self) void {
        var p: [*c]u8 = self.p;
        const b: u32 = self.b;
        p[0] = @truncate(b >> 0);
        if (self.c_s >= 16) {
            p[1] = @truncate(b >> 8);
            if (self.c_s == 32) {
                p[2] = @truncate(b >> 16);
                p[3] = @truncate(b >> 24);
            }
        }
    }
    pub fn put_bit(self: *Self, bit: c_uint) void {
        // TODO: Change signature to u1
        std.debug.assert(bit == 0 or bit == 1);
        std.debug.assert(self.k <= self.c_s);
        if (self.k < self.c_s) {
            if (self.k == 0) {
                std.debug.assert(self.p == null);
                self.p = self.op;
                self.op += self.c_s8;
            }
            std.debug.assert(self.p != null);
            std.debug.assert(self.p + self.c_s8 <= self.op);

            self.b = (self.b << 1) + bit;
            self.k += 1;
        } else {
            std.debug.assert(self.p != null);
            std.debug.assert(self.p + self.c_s8 <= self.op);

            write_bits(self);
            self.p = self.op;
            self.op += self.c_s8;
            self.b = bit;
            self.k = 1;
        }
    }
    pub fn put_byte(self: *Self, b: c_uint) void {
        std.debug.assert(self.p == null or self.p + self.c_s8 <= self.op);
        self.op.* = @truncate(b);
        self.op += 1;
    }
    pub fn flush_bits(self: *Self, filler_bit: c_uint) void {
        if (self.k > 0) {
            std.debug.assert(self.k <= self.c_s);
            while (self.k != self.c_s) {
                self.put_bit(filler_bit);
            }
            self.write_bits();
            self.k = 0;
        }
        self.p = null;
    }
};

pub fn compress(
    allocator: Allocator,
    comptime variant: NrvVariant,
    in: []const u8,
    out: []u8,
    call_back: ?*ucl_progress_callback_t,
    level: u8,
    conf: ?*const struct_ucl_compress_config_t,
    result: ?*[16]ucl_uint,
) Error![]u8 {
    const struct_swd_config_t = struct {
        try_lazy: c_uint,
        good_length: ucl_uint,
        max_lazy: ucl_uint,
        nice_length: ucl_uint,
        max_chain: ucl_uint,
        flags: u32,
        max_offset: u32,
    };
    const swd_config = [_]struct_swd_config_t{
        // faster compression
        struct_swd_config_t{
            .try_lazy = 0,
            .good_length = 0,
            .max_lazy = 0,
            .nice_length = 8,
            .max_chain = 4,
            .flags = 0,
            .max_offset = 48 * 1024,
        },
        struct_swd_config_t{
            .try_lazy = 0,
            .good_length = 0,
            .max_lazy = 0,
            .nice_length = 16,
            .max_chain = 8,
            .flags = 0,
            .max_offset = 48 * 1024,
        },
        struct_swd_config_t{
            .try_lazy = 0,
            .good_length = 0,
            .max_lazy = 0,
            .nice_length = 32,
            .max_chain = 16,
            .flags = 0,
            .max_offset = 48 * 1024,
        },
        struct_swd_config_t{
            .try_lazy = 1,
            .good_length = 4,
            .max_lazy = 4,
            .nice_length = 16,
            .max_chain = 16,
            .flags = 0,
            .max_offset = 48 * 1024,
        },
        struct_swd_config_t{
            .try_lazy = 1,
            .good_length = 8,
            .max_lazy = 16,
            .nice_length = 32,
            .max_chain = 32,
            .flags = 0,
            .max_offset = 48 * 1024,
        },
        struct_swd_config_t{
            .try_lazy = 1,
            .good_length = 8,
            .max_lazy = 16,
            .nice_length = 128,
            .max_chain = 128,
            .flags = 0,
            .max_offset = 48 * 1024,
        },
        struct_swd_config_t{
            .try_lazy = 2,
            .good_length = 8,
            .max_lazy = 32,
            .nice_length = 128,
            .max_chain = 256,
            .flags = 0,
            .max_offset = 128 * 1024,
        },
        struct_swd_config_t{
            .try_lazy = 2,
            .good_length = 32,
            .max_lazy = 128,
            .nice_length = SWD_F,
            .max_chain = 2048,
            .flags = 1,
            .max_offset = 128 * 1024,
        },
        struct_swd_config_t{
            .try_lazy = 2,
            .good_length = 32,
            .max_lazy = 128,
            .nice_length = SWD_F,
            .max_chain = 2048,
            .flags = 1,
            .max_offset = 256 * 1024,
        },
        struct_swd_config_t{
            .try_lazy = 2,
            .good_length = SWD_F,
            .max_lazy = SWD_F,
            .nice_length = SWD_F,
            .max_chain = 4096,
            .flags = 1,
            .max_offset = SWD_N,
        },
        // max. compression
    };
    if (level < 1 or level > 10) return Error.InvalidArgument;
    const sc = swd_config[level - 1];

    var result_buffer: [16]ucl_uint = undefined;
    var c: Compress = .{
        .result = if (result) |res| res else &result_buffer,
        .cb = call_back,
        .conf = .{},
        .ip = in.ptr,
        .in = in.ptr,
        .in_end = in.ptr + in.len,
        .out = out,
    };
    @memset(c.result, 0);
    c.result[0] = std.math.maxInt(ucl_uint);
    c.result[2] = std.math.maxInt(ucl_uint);
    c.result[4] = std.math.maxInt(ucl_uint);
    if (conf) |cfg| {
        c.conf = cfg.*;
    }
    c.bb.config(c.conf.bits);
    c.bb.op = out.ptr;

    var ii = c.ip; // point to start of literal run
    var lit: ucl_uint = 0;

    var the_swd: SlidingWindowDictionary = undefined;
    the_swd.f = @min(SWD_F, c.conf.max_match);
    the_swd.n = @min(SWD_N, sc.max_offset);
    the_swd.hmask = 65535;

    if (c.conf.max_offset != std.math.maxInt(ucl_uint)) {
        the_swd.n = @min(SWD_N, c.conf.max_offset);
    }
    if (in.len < the_swd.n) {
        the_swd.n = @intCast(@max(in.len, 256));
    }
    if (the_swd.f < 8 or the_swd.n < 256) return Error.InvalidArgument;
    try c.init_match(allocator, &the_swd, &.{}, sc.flags);
    defer the_swd.swd_exit(allocator);
    if (SWD_HSIZE - 1 != the_swd.hmask) return Error.Error;

    if (sc.max_chain > 0) {
        the_swd.max_chain = sc.max_chain;
    }
    if (sc.nice_length > 0) {
        the_swd.nice_length = sc.nice_length;
    }
    if (c.conf.max_match < the_swd.nice_length) {
        the_swd.nice_length = c.conf.max_match;
    }

    if (c.cb) |cb| {
        cb.*.callback(0, 0, -1, cb.*.user);
    }

    c.last_m_off = 1;
    c.find_match(allocator, &the_swd, 0, 0);
    while (c.look > 0) {
        lazy_match: {
            var ahead: ucl_uint = undefined;
            var max_ahead: ucl_uint = undefined;
            var l1: c_int = undefined;
            var l2: c_int = undefined;
            c.codesize = @intCast(@intFromPtr(c.bb.op) - @intFromPtr(out.ptr));

            const m_len = c.m_len;
            const m_off = c.m_off;

            std.debug.assert(c.bp == c.ip - c.look);
            std.debug.assert(c.bp >= in.ptr);
            if (lit == 0) {
                ii = c.bp;
            }
            std.debug.assert(ii + lit == c.bp);
            std.debug.assert(the_swd.b_char == c.bp.*);
            if ((m_len < 2 or ((m_len == @as(ucl_uint, 2)) and (m_off > M2_MAX_OFFSET(variant)))) or (m_off > c.conf.max_offset)) {
                // a literal
                lit += 1;
                the_swd.max_chain = sc.max_chain;
                c.find_match(allocator, &the_swd, 1, 0);
                continue;
            }
            // a match
            assert_match(&the_swd, m_len, m_off);
            // shall we try a lazy match ?
            ahead = 0;
            if (sc.try_lazy <= 0 or m_len >= sc.max_lazy or m_off == c.last_m_off) {
                // no
                l1 = 0;
                max_ahead = 0;
            } else {
                // yes, try a lazy match
                l1 = c.len_of_coded_match(variant, m_len, m_off);
                std.debug.assert(l1 > 0);
                max_ahead = @min(@as(ucl_uint, @intCast(sc.try_lazy)), m_len - 1);
            }

            while (ahead < max_ahead and c.look > m_len) {
                if (m_len >= sc.good_length) {
                    the_swd.max_chain = sc.max_chain >> 2;
                } else {
                    the_swd.max_chain = sc.max_chain;
                }
                c.find_match(allocator, &the_swd, 1, 0);
                ahead += 1;

                std.debug.assert(c.look > 0);
                std.debug.assert(@intFromPtr(ii) + lit + ahead == @intFromPtr(c.bp));

                if (c.m_len < 2) continue;
                l2 = c.len_of_coded_match(variant, c.m_len, c.m_off);
                if (l2 < 0) continue;
                if (l1 + (@as(c_int, @bitCast(ahead + c.m_len -% m_len)) * 5) > l2 + (@as(c_int, @intCast(ahead)) * 9)) {
                    c.lazy += 1;
                    assert_match(&the_swd, c.m_len, c.m_off);
                    {
                        lit += ahead;
                        std.debug.assert(ii + lit == c.bp);
                    }
                    break :lazy_match;
                }
            }
            std.debug.assert(ii + lit + ahead == c.bp);

            // 1 - code run
            c.code_run(ii, lit);
            lit = 0;

            // 2 - code match
            c.code_match(variant, m_len, m_off);
            the_swd.max_chain = sc.max_chain;
            c.find_match(allocator, &the_swd, m_len, 1 + ahead);
        }
    }

    // store final run
    c.code_run(ii, lit);

    // EOF
    c.bb.put_bit(0);
    switch (variant) {
        .Nrv2b => c.code_prefix_ss11(0x1000000),
        .Nrv2d, .Nrv2e => c.code_prefix_ss12(0x1000000),
    }
    c.bb.put_byte(0xff);
    c.bb.flush_bits(0);

    std.debug.assert(c.textsize == in.len);
    c.codesize = @as(ucl_uint, @intCast(@intFromPtr(c.bb.op) - @intFromPtr(out.ptr)));
    const out_len = @intFromPtr(c.bb.op) - @intFromPtr(out.ptr);
    if (c.cb) |cb| {
        cb.callback(c.textsize, c.codesize, 4, cb.user);
    }

    std.debug.assert(c.lit_bytes + c.match_bytes == in.len);
    return out[0..out_len];
}

pub fn M2_MAX_OFFSET(variant: NrvVariant) c_int {
    return switch (variant) {
        .Nrv2b => 0xd00,
        .Nrv2e, .Nrv2d => 0x500,
    };
}
pub const Compress = struct {
    const Self = @This();

    init: c_int = @import("std").mem.zeroes(c_int),

    look: ucl_uint = @import("std").mem.zeroes(ucl_uint), // bytes in lookahead buffer

    m_len: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    m_off: ucl_uint = @import("std").mem.zeroes(ucl_uint),

    last_m_len: ucl_uint = @import("std").mem.zeroes(ucl_uint),
    last_m_off: ucl_uint = @import("std").mem.zeroes(ucl_uint),

    bp: [*c]const u8 = @import("std").mem.zeroes([*c]const u8),
    ip: [*c]const u8 = @import("std").mem.zeroes([*c]const u8),
    in: [*c]const u8 = @import("std").mem.zeroes([*c]const u8),
    in_end: [*c]const u8 = @import("std").mem.zeroes([*c]const u8),
    out: []u8,

    bb: BitBuffer = .{},

    conf: struct_ucl_compress_config_t = .{},
    result: *[16]ucl_uint,

    cb: ?*ucl_progress_callback_t = null,

    textsize: ucl_uint = @import("std").mem.zeroes(ucl_uint), // text size counter
    codesize: ucl_uint = @import("std").mem.zeroes(ucl_uint), // code size counter
    printcount: ucl_uint = @import("std").mem.zeroes(ucl_uint), // counter for reporting progress every 1K bytes

    // some stats
    lit_bytes: c_ulong = @import("std").mem.zeroes(c_ulong),
    match_bytes: c_ulong = @import("std").mem.zeroes(c_ulong),
    rep_bytes: c_ulong = @import("std").mem.zeroes(c_ulong),
    lazy: c_ulong = @import("std").mem.zeroes(c_ulong),

    pub fn init_match(self: *Self, allocator: Allocator, s: *SlidingWindowDictionary, dict: []const u8, flags: u32) Error!void {
        std.debug.assert(self.init == 0);
        self.init = 1;

        s.c = self;

        self.last_m_len = 0;
        self.last_m_off = 0;

        self.textsize = 0;
        self.codesize = 0;
        self.printcount = 0;
        self.lit_bytes = 0;
        self.match_bytes = 0;
        self.rep_bytes = 0;
        self.lazy = 0;

        try s.swd_init(allocator, dict);
        s.use_best_off = (flags & 1) != 0;
    }
    pub fn find_match(self: *Self, allocator: Allocator, s: *SlidingWindowDictionary, this_len: ucl_uint, skip: ucl_uint) void {
        std.debug.assert(self.init != 0);

        if (skip > 0) {
            std.debug.assert(this_len >= skip);
            s.swd_accept(this_len - skip);
            self.textsize += (this_len - skip) + 1;
        } else {
            std.debug.assert(this_len <= 1);
            self.textsize += this_len - skip;
        }

        s.m_len = SWD_THRESHOLD;
        s.swd_findbest();
        self.m_len = s.m_len;
        self.m_off = s.m_off;

        s.swd_getbyte();

        if (s.b_char < 0) {
            self.look = 0;
            self.m_len = 0;
            s.swd_exit(allocator);
        } else {
            self.look = s.look + 1;
        }
        self.bp = self.ip - self.look;
        if (self.cb) |cb| {
            if (self.textsize > self.printcount) {
                cb.callback(self.textsize, self.codesize, 3, cb.user);
                self.printcount += 1024;
            }
        }
    }

    //***********************************************************************
    // start-step-stop prefix coding
    //***********************************************************************
    pub fn code_prefix_ss11(self: *Self, arg_i: u32) void {
        var i = arg_i;
        if (i >= 2) {
            var t: u32 = 4;
            i += 2;
            while (true) {
                t <<= 1;
                if (!(i >= t)) break;
            }
            t >>= 1;
            while (true) {
                t >>= 1;
                self.bb.put_bit(if ((i & t) != 0) 1 else 0);
                self.bb.put_bit(0);
                if (!(t > 2)) break;
            }
        }
        self.bb.put_bit(@as(c_uint, @bitCast(i)) & 1);
        self.bb.put_bit(1);
    }
    pub fn code_prefix_ss12(self: *Self, arg_i: u32) void {
        var i = arg_i;
        if (i >= 2) {
            var t: u32 = 2;
            while (true) {
                i -= t;
                t <<= 2;
                if (!(i >= t)) break;
            }
            while (true) {
                t >>= 1;
                self.bb.put_bit(if ((i & t) != 0) 1 else 0);
                self.bb.put_bit(0);
                t >>= 1;
                self.bb.put_bit(if ((i & t) != 0) 1 else 0);
                if (!(t > 2)) break;
            }
        }
        self.bb.put_bit(@as(c_uint, @bitCast(i)) & 1);
        self.bb.put_bit(1);
    }
    pub fn code_match(self: *Self, comptime variant: NrvVariant, arg_m_len: ucl_uint, m_off: ucl_uint) void {
        var m_len = arg_m_len;

        while (m_len > self.conf.max_match) {
            self.code_match(variant, self.conf.max_match - 3, m_off);
            m_len -= self.conf.max_match - 3;
        }

        self.match_bytes += m_len;
        if (m_len > self.result[3]) {
            self.result[3] = m_len;
        }
        if (m_off > self.result[1]) {
            self.result[1] = m_off;
        }

        self.bb.put_bit(0);

        switch (variant) {
            .Nrv2b => {
                if (m_off == self.last_m_off) {
                    self.bb.put_bit(0);
                    self.bb.put_bit(1);
                } else {
                    self.code_prefix_ss11(1 + ((m_off - 1) >> 8));
                    self.bb.put_byte(@as(c_uint, @intCast(m_off)) - 1);
                }
                m_len = m_len - 1 - @intFromBool(m_off > M2_MAX_OFFSET(variant));
                if (m_len >= 4) {
                    self.bb.put_bit(0);
                    self.bb.put_bit(0);
                    self.code_prefix_ss11(m_len - 4);
                } else {
                    self.bb.put_bit(@intFromBool(m_len > 1));
                    self.bb.put_bit(@as(c_uint, @intCast(m_len)) & 1);
                }
            },
            .Nrv2d => {
                m_len = m_len - 1 - @intFromBool(m_off > M2_MAX_OFFSET(variant));
                std.debug.assert(m_len > 0);
                const m_low = if (m_len >= 4) 0 else m_len;
                if (m_off == self.last_m_off) {
                    self.bb.put_bit(0);
                    self.bb.put_bit(1);
                    self.bb.put_bit(@intFromBool(m_low > 1));
                    self.bb.put_bit(m_low & 1);
                } else {
                    self.code_prefix_ss12(1 + ((m_off - 1) >> 7));
                    self.bb.put_byte((((@as(c_uint, @intCast(m_off)) - 1) & 0x7f) << 1) |
                        (if (m_low > 1) @as(c_uint, 0) else 1));
                    self.bb.put_bit(m_low & 1);
                }
                if (m_len >= 4)
                    self.code_prefix_ss11(m_len - 4);
            },
            .Nrv2e => {
                m_len = m_len - 1 - @intFromBool(m_off > M2_MAX_OFFSET(variant));
                std.debug.assert(m_len > 0);
                const m_low = @intFromBool(m_len <= 2);
                if (m_off == self.last_m_off) {
                    self.bb.put_bit(0);
                    self.bb.put_bit(1);
                    self.bb.put_bit(m_low);
                } else {
                    self.code_prefix_ss12(1 + ((m_off - 1) >> 7));
                    self.bb.put_byte((((@as(c_uint, @intCast(m_off)) - 1) & 0x7f) << 1) | (m_low ^ 1));
                }
                if (m_low != 0) {
                    self.bb.put_bit(@as(c_uint, @intCast(m_len)) - 1);
                } else if (m_len <= 4) {
                    self.bb.put_bit(1);
                    self.bb.put_bit(@as(c_uint, @intCast(m_len)) - 3);
                } else {
                    self.bb.put_bit(0);
                    self.code_prefix_ss11(m_len - 5);
                }
            },
        }
        self.last_m_off = m_off;
    }
    pub fn code_run(self: *Self, arg_ii: [*]const u8, arg_lit: ucl_uint) void {
        var ii = arg_ii;
        var lit = arg_lit;
        if (lit == 0) return;
        self.lit_bytes += lit;
        if (lit > self.result[5]) {
            self.result[5] = lit;
        }
        while (true) {
            self.bb.put_bit(1);
            self.bb.put_byte(ii[0]);
            ii += 1;
            lit -= 1;
            if (lit == 0) break;
        }
    }
    pub fn len_of_coded_match(self: *Self, comptime variant: NrvVariant, arg_m_len: ucl_uint, arg_m_off: ucl_uint) c_int {
        var m_len = arg_m_len;
        var m_off = arg_m_off;
        var b: c_int = undefined;
        if (((m_len < 2) or ((m_len == 2) and (m_off > M2_MAX_OFFSET(variant)))) or
            (m_off > self.conf.max_offset)) return -1;
        std.debug.assert(m_off > 0);

        m_len = m_len - 2 - @intFromBool(m_off > M2_MAX_OFFSET(variant));

        if (m_off == self.last_m_off) {
            b = 1 + 2;
        } else {
            switch (variant) {
                .Nrv2b => {
                    b = 1 + 10;
                    m_off = (m_off - 1) >> 8;
                    while (m_off > 0) {
                        b += 2;
                        m_off >>= 1;
                    }
                },
                .Nrv2d, .Nrv2e => {
                    b = 1 + 9;
                    m_off = (m_off - 1) >> 7;
                    while (m_off > 0) {
                        b += 3;
                        m_off >>= 2;
                    }
                },
            }
        }

        b += 2;
        switch (variant) {
            .Nrv2b, .Nrv2d => {
                if (m_len < 3) return b;
                m_len -= 3;
            },
            .Nrv2e => {
                if (m_len < 2) return b;
                if (m_len < 4) return b + 1;
                m_len -= 4;
            },
        }
        while (true) {
            b += 2;
            m_len >>= 1;
            if (!(m_len > 0)) break;
        }

        return b;
    }
};
pub const Error = error{
    Error,
    InvalidArgument,
    OutOfMemory,
    NotCompressible,
    InputOverrun,
    OutputOverrun,
    LookbehindOverrun,
    EofNotFound,
    InputNotConsumed,
    OverlapOverrun,
};
pub fn int_from_ucl_error_return(err: anytype) c_int {
    return if (err) |_| 0 else |e| int_from_ucl_error(e);
}
pub fn int_from_ucl_error(err: Error) c_int {
    return switch (err) {
        Error.Error => -1,
        Error.InvalidArgument => -2,
        Error.OutOfMemory => -3,
        Error.NotCompressible => -101,
        Error.InputOverrun => -201,
        Error.OutputOverrun => -202,
        Error.LookbehindOverrun => -203,
        Error.EofNotFound => -204,
        Error.InputNotConsumed => -205,
        Error.OverlapOverrun => -206,
    };
}
pub fn ucl_error_from_int(err: c_int) Error!void {
    return switch (err) {
        0 => {},
        -1 => Error.Error,
        -2 => Error.InvalidArgument,
        -3 => Error.OutOfMemory,
        -101 => Error.NotCompressible,
        -201 => Error.InputOverrun,
        -202 => Error.OutputOverrun,
        -203 => Error.LookbehindOverrun,
        -204 => Error.EofNotFound,
        -205 => Error.InputNotConsumed,
        -206 => Error.OverlapOverrun,
        else => unreachable,
    };
}
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
const SWD_USE_MALLOC: bool = true;
const SWD_HMASK: u32 = 65535;
// const SWD_N: c_int = 8 * 1024 * 1024;
const SWD_N: c_int = 16 * 1024;
const SWD_F: c_int = 2048;
const SWD_THRESHOLD: c_int = 1;
const ucl_swd_t = SlidingWindowDictionary;
fn getbyte(c: *Compress) c_int {
    if (c.ip < c.in_end) {
        const tmp = c.ip.*;
        c.ip += 1;
        return tmp;
    } else return -1;
}
const SWD_MAX_CHAIN: c_int = 2048;
const SWD_HSIZE = SWD_HMASK + 1;
inline fn HEAD3(b: []const u8, p: ucl_uint) u32 {
    return ((@as(u32, 0x9f5f) *%
        ((((@as(u32, @intCast(b[p])) << 5) ^
            @as(u32, @intCast(b[p + 1]))) << 5) ^
            @as(u32, @intCast(b[p + 2])))) >> 5) & SWD_HMASK;
}
inline fn HEAD2(b: []const u8, p: usize) ucl_uint {
    return unaligned_get(u16, b[p..]);
}
const NIL2 = std.math.maxInt(swd_uint);
inline fn s_get_head3(s: *ucl_swd_t, key: anytype) @TypeOf(s.*.head3[@as(usize, @intCast(key))]) {
    return s.head3[@as(usize, @intCast(key))];
}
inline fn swd_pos2off(s: *ucl_swd_t, pos: ucl_uint) ucl_uint {
    return if (s.bp > pos) s.bp - pos else s.b_size - (pos - s.bp);
}
fn assert_match(swd: *const SlidingWindowDictionary, m_len: ucl_uint, m_off: ucl_uint) void {
    const c: *const Compress = swd.c;
    var d_off: ucl_uint = undefined;

    std.debug.assert(m_len >= 2);
    if (m_off <= @as(ucl_uint, @intCast(@intFromPtr(c.bp) - @intFromPtr(c.in)))) {
        std.debug.assert(c.bp - m_off + m_len < c.ip);
        std.debug.assert(std.mem.eql(u8, c.bp[0..m_len], (c.bp - m_off)[0..m_len]));
    } else {
        d_off = m_off - @as(ucl_uint, @intCast(@intFromPtr(c.bp) - @intFromPtr(c.in)));
        std.debug.assert(d_off <= swd.dict.len);
        if (m_len > d_off) {
            std.debug.assert(std.mem.eql(u8, c.bp[0..d_off], (swd.dict_end - d_off)[0..d_off]));
            std.debug.assert(c.in + m_len - d_off < c.ip);
            std.debug.assert(std.mem.eql(u8, (c.bp + d_off)[0 .. m_len - d_off], c.in[0 .. m_len - d_off]));
        } else {
            std.debug.assert(std.mem.eql(u8, c.bp[0..m_len], (swd.dict_end - d_off)[0..m_len]));
        }
    }
}

pub const ucl_compress_config_t = struct_ucl_compress_config_t;
