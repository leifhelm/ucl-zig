const ucl = @import("ucl");
pub fn forall_level_variant_bits(ctx: anytype, f: fn (@TypeOf(ctx), u8, comptime ucl.NrvVariant, comptime ucl.Bits) anyerror!void) anyerror!void {
    try forall_variant_bits(ctx, f, 1);
    try forall_variant_bits(ctx, f, 2);
    try forall_variant_bits(ctx, f, 3);
    try forall_variant_bits(ctx, f, 4);
    try forall_variant_bits(ctx, f, 5);
    try forall_variant_bits(ctx, f, 6);
    try forall_variant_bits(ctx, f, 7);
    try forall_variant_bits(ctx, f, 8);
    try forall_variant_bits(ctx, f, 9);
}
pub fn forall_variant_bits(ctx: anytype, f: fn (@TypeOf(ctx), u8, comptime ucl.NrvVariant, comptime ucl.Bits) anyerror!void, level: u8) anyerror!void {
    try forall_bits(ctx, f, level, .Nrv2b);
    try forall_bits(ctx, f, level, .Nrv2d);
    try forall_bits(ctx, f, level, .Nrv2e);
}
pub fn forall_bits(ctx: anytype, f: fn (@TypeOf(ctx), u8, comptime ucl.NrvVariant, comptime ucl.Bits) anyerror!void, level: u8, comptime variant: ucl.NrvVariant) anyerror!void {
    try f(ctx, level, variant, .bits8);
    try f(ctx, level, variant, .bits16);
    try f(ctx, level, variant, .bits32);
}
