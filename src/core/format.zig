const std = @import("std");

pub const Base = enum(u8) {
    bin = 2,
    oct = 8,
    dec = 10,
    hex = 16,

    pub fn radix(self: Base) u8 {
        return @intFromEnum(self);
    }
};

pub const Options = struct {
    decimal_sep: u8 = '.',
    grouping: bool = true,
    scientific: bool = false, // F-E mode: always scientific notation
};

const max_sig = 16;

/// Format `value` for the calculator display in decimal mode.
/// NaN/Inf produce "Error" (the engine never passes those; it shows a
/// localized message itself - this is a safety net).
/// `buf` must hold at least 38 bytes: sign (1) + 16 integer digits +
/// 5 group separators + decimal separator (1) + 15 fraction digits.
pub fn float(buf: []u8, value: f64, opts: Options) []const u8 {
    if (std.math.isNan(value) or std.math.isInf(value)) return "Error";
    if (value == 0) return "0";

    var sci_buf: [64]u8 = undefined;
    var sci = std.fmt.bufPrint(&sci_buf, "{e}", .{value}) catch return "Error";

    const e_pos = std.mem.indexOfScalar(u8, sci, 'e') orelse return "Error";
    const exp10 = std.fmt.parseInt(i32, sci[e_pos + 1 ..], 10) catch return "Error";
    var mant = sci[0..e_pos];

    var neg = false;
    if (mant.len > 0 and mant[0] == '-') {
        neg = true;
        mant = mant[1..];
    }

    var digit_buf: [32]u8 = undefined;
    var digit_count: usize = 0;
    for (mant) |c| {
        if (c != '.') {
            digit_buf[digit_count] = c;
            digit_count += 1;
        }
    }
    if (digit_count > max_sig) {
        // Re-format with rounding to 16 significant digits, then re-parse
        // so the recursion terminates on the now-16-digit value.
        var round_buf: [64]u8 = undefined;
        const rounded = std.fmt.bufPrint(&round_buf, "{e:.15}", .{value}) catch return "Error";
        const v2 = std.fmt.parseFloat(f64, rounded) catch return "Error";
        if (!std.math.isInf(v2)) return float(buf, v2, opts);
        // Rounding up overflowed to infinity (value at the very top of the
        // f64 range, e.g. floatMax); truncate to 16 digits instead and
        // format them directly.
        digit_count = max_sig;
    }
    // Trim trailing zeros (keep at least one digit).
    var digits = digit_buf[0..digit_count];
    while (digits.len > 1 and digits[digits.len - 1] == '0') digits = digits[0 .. digits.len - 1];

    const use_sci = opts.scientific or exp10 >= max_sig or exp10 < -5;
    if (use_sci) return formatScientific(buf, neg, digits, exp10, opts.decimal_sep);
    return formatFixed(buf, neg, digits, exp10, opts);
}

fn formatFixed(buf: []u8, neg: bool, digits: []const u8, exp10: i32, opts: Options) []const u8 {
    var int_buf: [48]u8 = undefined;
    var int_part: []const u8 = undefined;
    var frac_buf: [64]u8 = undefined;
    var frac_part: []const u8 = "";

    if (exp10 >= 0) {
        const int_len: usize = @intCast(exp10 + 1);
        if (digits.len <= int_len) {
            @memcpy(int_buf[0..digits.len], digits);
            @memset(int_buf[digits.len..int_len], '0');
            int_part = int_buf[0..int_len];
        } else {
            int_part = digits[0..int_len];
            frac_part = digits[int_len..];
        }
    } else {
        int_part = "0";
        const zeros: usize = @intCast(-exp10 - 1);
        @memset(frac_buf[0..zeros], '0');
        @memcpy(frac_buf[zeros .. zeros + digits.len], digits);
        frac_part = frac_buf[0 .. zeros + digits.len];
    }

    // pt-BR convention: when the decimal separator is a comma, groups are
    // separated by dots so the two never collide (e.g. "1.234,5").
    const group_sep: u8 = if (opts.decimal_sep == ',') '.' else ',';
    var pos: usize = 0;
    if (neg) {
        buf[pos] = '-';
        pos += 1;
    }
    for (int_part, 0..) |c, i| {
        if (opts.grouping and i > 0 and (int_part.len - i) % 3 == 0) {
            buf[pos] = group_sep;
            pos += 1;
        }
        buf[pos] = c;
        pos += 1;
    }
    if (frac_part.len > 0) {
        buf[pos] = opts.decimal_sep;
        pos += 1;
        @memcpy(buf[pos .. pos + frac_part.len], frac_part);
        pos += frac_part.len;
    }
    return buf[0..pos];
}

fn formatScientific(buf: []u8, neg: bool, digits: []const u8, exp10: i32, sep: u8) []const u8 {
    var pos: usize = 0;
    if (neg) {
        buf[pos] = '-';
        pos += 1;
    }
    buf[pos] = digits[0];
    pos += 1;
    if (digits.len > 1) {
        buf[pos] = sep;
        pos += 1;
        @memcpy(buf[pos .. pos + digits.len - 1], digits[1..]);
        pos += digits.len - 1;
    }
    buf[pos] = 'e';
    pos += 1;
    if (exp10 >= 0) {
        buf[pos] = '+';
        pos += 1;
    }
    const exp_str = std.fmt.bufPrint(buf[pos..], "{d}", .{exp10}) catch unreachable;
    pos += exp_str.len;
    return buf[0..pos];
}

/// Format an integer in the given base, signed-magnitude (Win95-style
/// two's-complement display for negatives is intentionally not done).
/// `buf` must hold at least 80 bytes: sign (1) + 64 binary digits +
/// 15 group separators (groups of 4).
pub fn intBase(buf: []u8, value: i64, base: Base, grouping: bool) []const u8 {
    const mag: u64 = if (value < 0) @as(u64, @intCast(-(value + 1))) + 1 else @intCast(value);
    var tmp: [66]u8 = undefined;
    const s = switch (base) {
        .hex => std.fmt.bufPrint(&tmp, "{X}", .{mag}) catch unreachable,
        .dec => std.fmt.bufPrint(&tmp, "{d}", .{mag}) catch unreachable,
        .oct => std.fmt.bufPrint(&tmp, "{o}", .{mag}) catch unreachable,
        .bin => std.fmt.bufPrint(&tmp, "{b}", .{mag}) catch unreachable,
    };
    const group: usize = switch (base) {
        .hex, .bin => 4,
        .oct, .dec => 3,
    };
    var pos: usize = 0;
    if (value < 0) {
        buf[pos] = '-';
        pos += 1;
    }
    for (s, 0..) |c, i| {
        if (grouping and i > 0 and (s.len - i) % group == 0) {
            buf[pos] = ',';
            pos += 1;
        }
        buf[pos] = c;
        pos += 1;
    }
    return buf[0..pos];
}

/// Insert grouping separators into a raw digit string (e.g. "12345" with
/// group 3 and sep ',' → "12,345"). Used for live grouping of typed input.
/// `buf` must hold at least digits.len + digits.len / group bytes.
pub fn groupDigits(buf: []u8, digits: []const u8, group: usize, sep: u8) []const u8 {
    var pos: usize = 0;
    for (digits, 0..) |c, i| {
        if (group > 0 and i > 0 and (digits.len - i) % group == 0) {
            buf[pos] = sep;
            pos += 1;
        }
        buf[pos] = c;
        pos += 1;
    }
    return buf[0..pos];
}

test "groupDigits" {
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings("0", groupDigits(&buf, "0", 3, ','));
    try std.testing.expectEqualStrings("1,000", groupDigits(&buf, "1000", 3, ','));
    try std.testing.expectEqualStrings("100,000", groupDigits(&buf, "100000", 3, ','));
    try std.testing.expectEqualStrings("1.000.000", groupDigits(&buf, "1000000", 3, '.'));
    try std.testing.expectEqualStrings("A,BCDE", groupDigits(&buf, "ABCDE", 4, ','));
}

test "float basic values" {
    var buf: [128]u8 = undefined;
    const o: Options = .{};
    try std.testing.expectEqualStrings("0", float(&buf, 0, o));
    try std.testing.expectEqualStrings("0.5", float(&buf, 0.5, o));
    try std.testing.expectEqualStrings("-2.5", float(&buf, -2.5, o));
    try std.testing.expectEqualStrings("100", float(&buf, 100, o));
}

test "float grouping and separators" {
    var buf: [128]u8 = undefined;
    try std.testing.expectEqualStrings("123,456", float(&buf, 123456, .{}));
    try std.testing.expectEqualStrings("123456", float(&buf, 123456, .{ .grouping = false }));
    try std.testing.expectEqualStrings("2,5", float(&buf, 2.5, .{ .decimal_sep = ',' }));
    try std.testing.expectEqualStrings("1.234,5", float(&buf, 1234.5, .{ .decimal_sep = ',' }));
    try std.testing.expectEqualStrings("1,234,567.25", float(&buf, 1234567.25, .{}));
}

test "float precision round-trips" {
    var buf: [128]u8 = undefined;
    const s = float(&buf, 1.0 / 3.0, .{});
    // at most 16 significant digits, parses back to the same value
    const parsed = try std.fmt.parseFloat(f64, s);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0 / 3.0), parsed, 1e-15);
}

test "float scientific notation" {
    var buf: [128]u8 = undefined;
    try std.testing.expectEqualStrings("1e+20", float(&buf, 1e20, .{}));
    try std.testing.expectEqualStrings("5e-7", float(&buf, 5e-7, .{}));
    try std.testing.expectEqualStrings("1.5e+2", float(&buf, 150, .{ .scientific = true }));
}

test "float error values" {
    var buf: [128]u8 = undefined;
    try std.testing.expectEqualStrings("Error", float(&buf, std.math.nan(f64), .{}));
    try std.testing.expectEqualStrings("Error", float(&buf, std.math.inf(f64), .{}));
}

test "float 17-digit round-trip values terminate" {
    var buf: [128]u8 = undefined;
    // floatMax's shortest round-trip needs 17 significant digits; the
    // re-rounding branch must not recurse forever. Rounding up to 16 digits
    // would overflow to infinity, so the value is truncated instead.
    const s = float(&buf, std.math.floatMax(f64), .{});
    try std.testing.expectEqualStrings("1.797693134862315e+308", s);
    const parsed = try std.fmt.parseFloat(f64, s);
    try std.testing.expect(std.math.isFinite(parsed));
    try std.testing.expectApproxEqAbs(std.math.floatMax(f64), parsed, 1e293);
}

test "intBase" {
    var buf: [128]u8 = undefined;
    try std.testing.expectEqualStrings("FF", intBase(&buf, 255, .hex, false));
    try std.testing.expectEqualStrings("-FF", intBase(&buf, -255, .hex, false));
    try std.testing.expectEqualStrings("10", intBase(&buf, 8, .oct, false));
    try std.testing.expectEqualStrings("101", intBase(&buf, 5, .bin, false));
    // Hex groups are 4 digits; 0xFFFF is a single group, so no separator.
    try std.testing.expectEqualStrings("FFFF", intBase(&buf, 65535, .hex, true));
    try std.testing.expectEqualStrings("F,FFFF", intBase(&buf, 1048575, .hex, true));
    try std.testing.expectEqualStrings("1111,1111", intBase(&buf, 255, .bin, true));
}
