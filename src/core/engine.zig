const std = @import("std");
const fmt = @import("format.zig");
const parser = @import("parser.zig");
const history_mod = @import("history.zig");

pub const History = history_mod.History;
pub const Mode = enum { simple, standard, scientific };
pub const AngleUnit = parser.AngleUnit;
pub const Base = fmt.Base;

pub const BinOp = enum { add, sub, mul, div, pow, mod, bw_and, bw_or, bw_xor, lsh };
pub const UnaryOp = enum { sqrt, recip, fact, x2, x3, sin, cos, tan, ln, log, exp, int, bw_not };
pub const ErrKind = enum { div_zero, overflow, domain, invalid_input };

const max_entry_len = 40;
const max_paren = 16;

const ParenFrame = struct {
    acc: f64,
    pending: ?BinOp,
};

pub const Engine = struct {
    allocator: std.mem.Allocator,
    history: *History,
    entry: std.ArrayList(u8), // canonical typed text: '.' separator, optional leading '-'
    // Exact f64 behind the entry text after setEntryFromValue; avoids
    // precision loss from the 16-digit text round-trip on repeat '='.
    // Cleared by anything that mutates the entry text directly.
    value_override: ?f64 = null,
    acc: f64 = 0,
    pending: ?BinOp = null,
    last_op: ?BinOp = null,
    last_operand: f64 = 0,
    fresh: bool = true, // next digit starts a new entry
    err: ?ErrKind = null,
    mem: f64 = 0,
    has_mem: bool = false,
    mode: Mode = .standard,
    base: Base = .dec,
    angle: AngleUnit = .deg,
    inv: bool = false,
    hyp: bool = false,
    fe: bool = false,
    dms_mode: bool = false,
    decimal_sep: u8 = '.',
    /// Nested parentheses for Simple-mode `()` (and keyboard `(`/`)`).
    paren_stack: [max_paren]ParenFrame = undefined,
    paren_depth: u8 = 0,

    pub fn init(allocator: std.mem.Allocator, history: *History) Engine {
        return .{ .allocator = allocator, .history = history, .entry = .empty };
    }

    pub fn deinit(self: *Engine) void {
        self.entry.deinit(self.allocator);
    }

    // --- entry helpers ---

    fn resetEntry(self: *Engine) void {
        self.value_override = null;
        self.entry.clearRetainingCapacity();
        self.entry.append(self.allocator, '0') catch @panic("OOM");
    }

    fn ensureEntry(self: *Engine) void {
        if (self.entry.items.len == 0) self.resetEntry();
    }

    /// Current value: typed text if entering, else the stored entry value.
    pub fn displayValue(self: *const Engine) f64 {
        if (self.err != null) return 0;
        return self.entryValue();
    }

    fn entryValue(self: *const Engine) f64 {
        if (self.value_override) |v| return v;
        const text = if (self.entry.items.len == 0) "0" else self.entry.items;
        if (self.base == .dec)
            return std.fmt.parseFloat(f64, text) catch 0;
        const neg = text.len > 0 and text[0] == '-';
        const digits = if (neg) text[1..] else text;
        const mag = std.fmt.parseInt(i64, digits, self.base.radix()) catch return 0;
        return @floatFromInt(if (neg) -mag else mag);
    }

    fn setEntryFromValue(self: *Engine, v: f64) void {
        var buf: [128]u8 = undefined;
        const s = if (self.base == .dec)
            fmt.float(&buf, v, .{ .grouping = false })
        else
            fmt.intBase(&buf, @intFromFloat(@trunc(v)), self.base, false);
        self.entry.clearRetainingCapacity();
        self.entry.appendSlice(self.allocator, s) catch @panic("OOM");
        self.value_override = v;
    }

    fn setErr(self: *Engine, e: parser.Error) void {
        self.err = switch (e) {
            error.DivisionByZero => .div_zero,
            error.Overflow => .overflow,
            error.DomainError => .domain,
            else => .invalid_input,
        };
    }

    // --- input ---

    pub fn digit(self: *Engine, d: u8) void {
        if (self.err != null) return;
        std.debug.assert(d < 16);
        if (self.base != .hex and d > 9) return;
        if (self.base == .bin and d > 1) return;
        if (self.base == .oct and d > 7) return;
        self.value_override = null;
        if (self.fresh) {
            self.entry.clearRetainingCapacity();
            self.fresh = false;
        }
        self.ensureEntry();
        if (self.entry.items.len >= max_entry_len) return;
        if (self.entry.items.len == 1 and self.entry.items[0] == '0') {
            self.entry.items[0] = if (d < 10) '0' + d else 'A' + (d - 10);
            return;
        }
        const c: u8 = if (d < 10) '0' + d else 'A' + (d - 10);
        self.entry.append(self.allocator, c) catch @panic("OOM");
    }

    pub fn dot(self: *Engine) void {
        if (self.err != null or self.base != .dec) return;
        self.value_override = null;
        if (self.fresh) {
            self.entry.clearRetainingCapacity();
            self.entry.append(self.allocator, '0') catch @panic("OOM");
            self.fresh = false;
        }
        self.ensureEntry();
        if (std.mem.indexOfScalar(u8, self.entry.items, '.') != null) return;
        if (std.mem.indexOfScalar(u8, self.entry.items, 'e') != null) return; // sci display
        self.entry.append(self.allocator, '.') catch @panic("OOM");
    }

    pub fn backspace(self: *Engine) void {
        if (self.err != null or self.fresh) return;
        self.value_override = null;
        self.ensureEntry();
        if (self.entry.items.len <= 1 or
            (self.entry.items.len == 2 and self.entry.items[0] == '-'))
        {
            self.resetEntry();
            self.fresh = true;
            return;
        }
        _ = self.entry.pop();
    }

    pub fn negate(self: *Engine) void {
        if (self.err != null) return;
        self.value_override = null;
        self.ensureEntry();
        if (self.entry.items.len > 0 and self.entry.items[0] == '-') {
            _ = self.entry.orderedRemove(0);
        } else {
            self.entry.insert(self.allocator, 0, '-') catch @panic("OOM");
        }
    }

    pub fn clearEntry(self: *Engine) void {
        self.err = null;
        self.resetEntry();
        self.fresh = true;
    }

    pub fn clearAll(self: *Engine) void {
        self.clearEntry();
        self.acc = 0;
        self.pending = null;
        self.last_op = null;
        self.paren_depth = 0;
    }

    /// Smart parentheses for Simple mode: opens a nested sub-expression, or
    /// closes the innermost one when a value is ready.
    pub fn paren(self: *Engine) void {
        if (self.err != null) return;
        if (self.paren_depth > 0 and !self.fresh) {
            self.closeParen();
        } else {
            self.openParen();
        }
    }

    pub fn openParen(self: *Engine) void {
        if (self.err != null or self.paren_depth >= max_paren) return;
        // Juxtaposition: `2(3+4)` means `2*(3+4)`.
        if (!self.fresh and self.pending == null) {
            self.acc = self.entryValue();
            self.pending = .mul;
        }
        self.paren_stack[self.paren_depth] = .{ .acc = self.acc, .pending = self.pending };
        self.paren_depth += 1;
        self.acc = 0;
        self.pending = null;
        self.last_op = null;
        self.resetEntry();
        self.fresh = true;
    }

    pub fn closeParen(self: *Engine) void {
        if (self.err != null or self.paren_depth == 0) return;
        // Finish the sub-expression if an operator is still pending.
        if (self.pending) |op| {
            const rhs = self.entryValue();
            const result = self.applyBinary(op, self.acc, rhs) catch |e| {
                self.setErr(e);
                return;
            };
            self.setEntryFromValue(result);
            self.pending = null;
        }
        self.paren_depth -= 1;
        const frame = self.paren_stack[self.paren_depth];
        self.acc = frame.acc;
        self.pending = frame.pending;
        self.fresh = true;
    }

    // --- binary operations ---

    fn applyBinary(self: *Engine, op: BinOp, a: f64, b: f64) parser.Error!f64 {
        _ = self;
        const v: f64 = blk: switch (op) {
            .add => a + b,
            .sub => a - b,
            .mul => a * b,
            .div => {
                if (b == 0) return error.DivisionByZero;
                break :blk a / b;
            },
            .pow => pow_blk: {
                const r = std.math.pow(f64, a, b);
                if (std.math.isNan(r)) return error.DomainError;
                break :pow_blk r;
            },
            .mod => {
                if (b == 0) return error.DivisionByZero;
                break :blk @rem(a, b);
            },
            .bw_and => @floatFromInt(try parser.truncI64(a) & try parser.truncI64(b)),
            .bw_or => @floatFromInt(try parser.truncI64(a) | try parser.truncI64(b)),
            .bw_xor => @floatFromInt(try parser.truncI64(a) ^ try parser.truncI64(b)),
            .lsh => lsh_blk: {
                const n = try parser.truncI64(b);
                if (n < 0 or n > 63) return error.DomainError;
                break :lsh_blk @floatFromInt(try parser.truncI64(a) << @as(u6, @intCast(n)));
            },
        };
        if (std.math.isNan(v)) return error.DomainError;
        if (std.math.isInf(v)) return error.Overflow;
        return v;
    }

    pub fn binaryOp(self: *Engine, op: BinOp) void {
        if (self.err != null) return;
        if (self.pending) |p| {
            if (!self.fresh) {
                const rhs = self.entryValue();
                const result = self.applyBinary(p, self.acc, rhs) catch |e| {
                    self.setErr(e);
                    return;
                };
                self.setEntryFromValue(result);
                self.acc = result;
            }
            // fresh: user is replacing the pending operator
        } else {
            self.acc = self.entryValue();
        }
        self.pending = op;
        self.fresh = true;
    }

    pub fn percent(self: *Engine) void {
        if (self.err != null) return;
        const v = self.entryValue();
        const r: f64 = if (self.pending) |p| switch (p) {
            .add, .sub => self.acc * v / 100,
            .mul, .div => v / 100,
            else => 0,
        } else 0;
        if (std.math.isNan(r) or std.math.isInf(r)) {
            self.err = .overflow;
            return;
        }
        self.setEntryFromValue(r);
        self.fresh = true;
    }

    pub fn equals(self: *Engine) void {
        if (self.err != null) return;
        // Auto-close any open parentheses before evaluating.
        while (self.paren_depth > 0) {
            if (self.fresh and self.pending == null) {
                // Empty group - just pop the frame.
                self.paren_depth -= 1;
                const frame = self.paren_stack[self.paren_depth];
                self.acc = frame.acc;
                self.pending = frame.pending;
            } else {
                self.closeParen();
                if (self.err != null) return;
            }
        }
        if (self.pending) |op| {
            const lhs = self.acc;
            const rhs = self.entryValue();
            const result = self.applyBinary(op, lhs, rhs) catch |e| {
                self.setErr(e);
                return;
            };
            self.recordHistory(lhs, op, rhs, result);
            self.last_op = op;
            self.last_operand = rhs;
            self.pending = null;
            self.setEntryFromValue(result);
            self.fresh = true;
        } else if (self.last_op) |op| {
            const lhs = self.entryValue();
            const result = self.applyBinary(op, lhs, self.last_operand) catch |e| {
                self.setErr(e);
                return;
            };
            self.recordHistory(lhs, op, self.last_operand, result);
            self.setEntryFromValue(result);
            self.fresh = true;
        }
    }

    fn recordHistory(self: *Engine, lhs: f64, op: BinOp, rhs: f64, result: f64) void {
        var lb: [64]u8 = undefined;
        var rb: [64]u8 = undefined;
        const ls = fmt.float(&lb, lhs, .{ .grouping = false, .decimal_sep = self.decimal_sep });
        const rs = fmt.float(&rb, rhs, .{ .grouping = false, .decimal_sep = self.decimal_sep });
        const sym: []const u8 = switch (op) {
            .add => "+",
            .sub => "-",
            .mul => "*",
            .div => "/",
            .pow => "^",
            .mod => "mod",
            .bw_and => "&",
            .bw_or => "|",
            .bw_xor => "xor",
            .lsh => "<<",
        };
        var eb: [160]u8 = undefined;
        const expr = std.fmt.bufPrint(&eb, "{s} {s} {s}", .{ ls, sym, rs }) catch return;
        self.history.add(expr, result) catch {};
    }

    // --- memory ---

    pub fn mc(self: *Engine) void {
        self.mem = 0;
        self.has_mem = false;
    }

    pub fn ms(self: *Engine) void {
        if (self.err != null) return;
        self.mem = self.entryValue();
        self.has_mem = true;
    }

    pub fn mr(self: *Engine) void {
        if (self.err != null) return;
        self.setEntryFromValue(self.mem);
        self.fresh = true;
    }

    /// Insert a named constant (pi, e) as the current entry, preserving any
    /// pending operation and recording no history (unlike paste).
    pub fn loadConstant(self: *Engine, v: f64) void {
        if (self.err != null) return;
        self.setEntryFromValue(v);
        self.fresh = true;
    }

    /// Load a value into the display (used by the history panel).
    pub fn loadValue(self: *Engine, v: f64) void {
        if (self.err != null) return;
        self.pending = null;
        self.setEntryFromValue(v);
        self.fresh = true;
    }

    pub fn mPlus(self: *Engine) void {
        if (self.err != null) return;
        self.mem += self.entryValue();
        self.has_mem = true;
        self.fresh = true;
    }

    // --- display ---

    pub fn display(self: *Engine, buf: []u8) []const u8 {
        if (self.err != null) return "Error";
        const main: []const u8 = if (!self.fresh)
            self.displayTyped(buf)
        else blk: {
            const v = self.entryValue();
            if (self.base != .dec)
                break :blk fmt.intBase(buf, @intFromFloat(@trunc(v)), self.base, true);
            if (self.dms_mode) break :blk self.displayDms(buf, v);
            break :blk fmt.float(buf, v, .{
                .decimal_sep = self.decimal_sep,
                .grouping = true,
                .scientific = self.fe,
            });
        };
        // Pending-operator indicator: "100÷" right after an operator key.
        if (self.fresh) {
            if (self.pending) |op| {
                const sym = opSymbol(op);
                if (main.len + sym.len <= buf.len) {
                    @memcpy(buf[main.len .. main.len + sym.len], sym);
                    return buf[0 .. main.len + sym.len];
                }
            }
        }
        return main;
    }

    /// Display symbol for a pending binary operator (Latin-1 safe glyphs).
    fn opSymbol(op: BinOp) []const u8 {
        return switch (op) {
            .add => "+",
            .sub => "-",
            .mul => "\xc3\x97", // ×
            .div => "\xc3\xb7", // ÷
            .pow => "^",
            .mod => " mod",
            .bw_and => " &",
            .bw_or => " |",
            .bw_xor => " xor",
            .lsh => " <<",
        };
    }

    /// Typed text with live digit grouping: typing 1000 shows "1,000".
    /// The fraction and scientific-notation text stay verbatim.
    fn displayTyped(self: *Engine, buf: []u8) []const u8 {
        const text = self.entry.items;
        if (std.mem.indexOfScalar(u8, text, 'e') != null) {
            // Scientific-notation text: only swap the separator.
            var i: usize = 0;
            for (text) |c| {
                if (i >= buf.len) break;
                buf[i] = if (c == '.') self.decimal_sep else c;
                i += 1;
            }
            return buf[0..i];
        }
        var rest = text;
        var neg = false;
        if (rest.len > 0 and rest[0] == '-') {
            neg = true;
            rest = rest[1..];
        }
        const dot_pos = std.mem.indexOfScalar(u8, rest, '.');
        const int_part = if (dot_pos) |p| rest[0..p] else rest;
        const group: usize = switch (self.base) {
            .hex, .bin => 4,
            .oct, .dec => 3,
        };
        const gsep: u8 = if (self.base == .dec and self.decimal_sep == ',') '.' else ',';
        var pos: usize = 0;
        if (neg) {
            buf[pos] = '-';
            pos += 1;
        }
        const grouped = fmt.groupDigits(buf[pos..], int_part, group, gsep);
        pos += grouped.len;
        if (dot_pos) |p| {
            buf[pos] = self.decimal_sep;
            pos += 1;
            const frac = rest[p + 1 ..];
            @memcpy(buf[pos .. pos + frac.len], frac);
            pos += frac.len;
        }
        return buf[0..pos];
    }

    /// Canonical UNgrouped text for the clipboard: pasting this string back
    /// always parses, unlike the grouped display text (e.g. "1,234.5").
    pub fn copyText(self: *Engine, buf: []u8) []const u8 {
        if (self.err != null) return "Error";
        if (!self.fresh) {
            // Typed text, as-is (with separator swapped for display).
            var i: usize = 0;
            for (self.entry.items) |c| {
                if (i >= buf.len) break;
                buf[i] = if (c == '.') self.decimal_sep else c;
                i += 1;
            }
            return buf[0..i];
        }
        const v = self.entryValue();
        if (self.base != .dec)
            return fmt.intBase(buf, @intFromFloat(@trunc(v)), self.base, false);
        return fmt.float(buf, v, .{ .grouping = false, .decimal_sep = self.decimal_sep });
    }

    fn displayDms(self: *Engine, buf: []u8, v: f64) []const u8 {
        _ = self;
        const neg = v < 0;
        const a = @abs(v);
        // Round to whole seconds first so 59.99996" carries into minutes
        // (and minutes into degrees) instead of displaying as "60".
        const total: u64 = @intFromFloat(@round(a * 3600));
        const d = total / 3600;
        const m = (total % 3600) / 60;
        const s = total % 60;
        return std.fmt.bufPrint(buf, "{s}{d}.{d:0>2}{d:0>2}", .{
            if (neg) "-" else "",
            d,
            m,
            s,
        }) catch "Error";
    }

    // --- scientific mode, bases, paste ---

    pub fn unaryOp(self: *Engine, op: UnaryOp) void {
        if (self.err != null) return;
        const v = self.entryValue();
        const r = self.applyUnary(op, v) catch |e| {
            self.setErr(e);
            return;
        };
        self.setEntryFromValue(r);
        self.fresh = true;
    }

    fn toRad(self: *const Engine, x: f64) f64 {
        return switch (self.angle) {
            .deg => x * std.math.pi / 180,
            .grad => x * std.math.pi / 200,
            .rad => x,
        };
    }

    fn fromRad(self: *const Engine, x: f64) f64 {
        return switch (self.angle) {
            .deg => x * 180 / std.math.pi,
            .grad => x * 200 / std.math.pi,
            .rad => x,
        };
    }

    fn applyUnary(self: *Engine, op: UnaryOp, v: f64) parser.Error!f64 {
        const r: f64 = blk: switch (op) {
            .sqrt => {
                if (v < 0) return error.DomainError;
                break :blk @sqrt(v);
            },
            .recip => {
                if (v == 0) return error.DivisionByZero;
                break :blk 1 / v;
            },
            .fact => return parser.factorial(v),
            .x2 => v * v,
            .x3 => v * v * v,
            .sin => {
                if (self.hyp) break :blk if (self.inv) std.math.asinh(v) else std.math.sinh(v);
                if (self.inv) {
                    if (v < -1 or v > 1) return error.DomainError;
                    break :blk self.fromRad(std.math.asin(v));
                }
                break :blk @sin(self.toRad(v));
            },
            .cos => {
                if (self.hyp) break :blk if (self.inv) std.math.acosh(v) else std.math.cosh(v);
                if (self.inv) {
                    if (v < -1 or v > 1) return error.DomainError;
                    break :blk self.fromRad(std.math.acos(v));
                }
                break :blk @cos(self.toRad(v));
            },
            .tan => {
                if (self.hyp) break :blk if (self.inv) std.math.atanh(v) else std.math.tanh(v);
                if (self.inv) break :blk self.fromRad(std.math.atan(v));
                break :blk @tan(self.toRad(v));
            },
            .ln => {
                if (v <= 0) return error.DomainError;
                break :blk @log(v);
            },
            .log => {
                if (v <= 0) return error.DomainError;
                break :blk @log10(v);
            },
            .exp => @exp(v),
            .int => @trunc(v),
            .bw_not => @floatFromInt(~try parser.truncI64(v)),
        };
        if (std.math.isNan(r)) return error.DomainError;
        if (std.math.isInf(r)) return error.Overflow;
        return r;
    }

    pub fn paste(self: *Engine, text: []const u8) void {
        if (self.err != null) return;
        const trimmed = std.mem.trim(u8, text, " \n\r\t");
        if (trimmed.len == 0) return;
        var translated: ?[]u8 = null;
        defer if (translated) |buf| self.allocator.free(buf);
        var input: []const u8 = trimmed;
        if (self.decimal_sep == ',') {
            const buf = self.allocator.dupe(u8, trimmed) catch return;
            std.mem.replaceScalar(u8, buf, ',', '.');
            translated = buf;
            input = buf;
        }
        const result = parser.eval(self.allocator, input, self.angle) catch |e| {
            self.setErr(e); // previous entry preserved
            return;
        };
        self.pending = null;
        self.setEntryFromValue(result);
        self.fresh = true;
        self.history.add(trimmed, result) catch {};
    }

    pub fn setBase(self: *Engine, base: Base) void {
        if (self.err != null) return;
        if (base == self.base) return;
        const v = self.entryValue();
        self.base = base;
        self.setEntryFromValue(@trunc(v));
        self.fresh = true;
    }

    pub fn setAngleUnit(self: *Engine, unit: AngleUnit) void {
        self.angle = unit;
    }

    pub fn setMode(self: *Engine, mode: Mode) void {
        self.mode = mode;
        if (mode != .scientific) {
            // Simple/Standard stay decimal; drop scientific-only toggles.
            if (self.base != .dec) self.setBase(.dec);
            self.inv = false;
            self.hyp = false;
            self.fe = false;
            self.dms_mode = false;
        }
        if (mode == .simple) self.paren_depth = 0;
    }
};

fn setup() struct { h: *History, e: *Engine } {
    const h = std.testing.allocator.create(History) catch unreachable;
    h.* = History.init(std.testing.allocator);
    const e = std.testing.allocator.create(Engine) catch unreachable;
    e.* = Engine.init(std.testing.allocator, h);
    return .{ .h = h, .e = e };
}

fn teardown(t: anytype) void {
    t.e.deinit();
    t.h.deinit();
    std.testing.allocator.destroy(t.e);
    std.testing.allocator.destroy(t.h);
}

test "digit entry and display" {
    const t = setup();
    defer teardown(t);
    t.e.digit(1);
    t.e.digit(2);
    t.e.digit(3);
    try std.testing.expectEqual(@as(f64, 123), t.e.displayValue());
    t.e.dot();
    t.e.digit(5);
    try std.testing.expectEqual(@as(f64, 123.5), t.e.displayValue());
    t.e.backspace();
    try std.testing.expectEqual(@as(f64, 123), t.e.displayValue());
}

test "basic arithmetic and history" {
    const t = setup();
    defer teardown(t);
    t.e.digit(2);
    t.e.binaryOp(.add);
    t.e.digit(3);
    t.e.equals();
    try std.testing.expectEqual(@as(f64, 5), t.e.displayValue());
    try std.testing.expectEqual(@as(usize, 1), t.h.items.items.len);
    try std.testing.expectEqual(@as(f64, 5), t.h.items.items[0].result);
}

test "simple-mode parentheses: 2*(3+4)" {
    const t = setup();
    defer teardown(t);
    t.e.setMode(.simple);
    t.e.digit(2);
    t.e.binaryOp(.mul);
    t.e.paren(); // open
    t.e.digit(3);
    t.e.binaryOp(.add);
    t.e.digit(4);
    t.e.paren(); // close
    t.e.equals();
    try std.testing.expectEqual(@as(f64, 14), t.e.displayValue());
}

test "simple-mode juxtaposition: 2(3+4)" {
    const t = setup();
    defer teardown(t);
    t.e.setMode(.simple);
    t.e.digit(2);
    t.e.paren(); // open with implicit *
    t.e.digit(3);
    t.e.binaryOp(.add);
    t.e.digit(4);
    t.e.equals(); // auto-closes paren
    try std.testing.expectEqual(@as(f64, 14), t.e.displayValue());
}

test "immediate execution chains left to right" {
    const t = setup();
    defer teardown(t);
    t.e.digit(2);
    t.e.binaryOp(.add);
    t.e.digit(3);
    t.e.binaryOp(.mul); // evaluates 2+3 first
    t.e.digit(4);
    t.e.equals();
    try std.testing.expectEqual(@as(f64, 20), t.e.displayValue());
}

test "repeat equals" {
    const t = setup();
    defer teardown(t);
    t.e.digit(2);
    t.e.binaryOp(.add);
    t.e.digit(3);
    t.e.equals();
    t.e.equals();
    try std.testing.expectEqual(@as(f64, 8), t.e.displayValue());
}

test "negate and clear" {
    const t = setup();
    defer teardown(t);
    t.e.digit(5);
    t.e.negate();
    try std.testing.expectEqual(@as(f64, -5), t.e.displayValue());
    t.e.clearEntry();
    try std.testing.expectEqual(@as(f64, 0), t.e.displayValue());
    t.e.digit(9);
    t.e.binaryOp(.add);
    t.e.digit(1);
    t.e.clearAll();
    t.e.equals(); // nothing pending after C
    try std.testing.expectEqual(@as(f64, 0), t.e.displayValue());
}

test "memory operations" {
    const t = setup();
    defer teardown(t);
    t.e.digit(5);
    t.e.ms();
    try std.testing.expect(t.e.has_mem);
    t.e.clearAll();
    t.e.mr();
    try std.testing.expectEqual(@as(f64, 5), t.e.displayValue());
    t.e.digit(2);
    t.e.mPlus();
    t.e.mc();
    try std.testing.expect(!t.e.has_mem);
}

test "percent semantics" {
    const t = setup();
    defer teardown(t);
    t.e.digit(2);
    t.e.digit(0);
    t.e.digit(0);
    t.e.binaryOp(.mul);
    t.e.digit(1);
    t.e.digit(0);
    t.e.percent();
    t.e.equals();
    try std.testing.expectEqual(@as(f64, 20), t.e.displayValue());

    t.e.clearAll();
    t.e.digit(2);
    t.e.digit(0);
    t.e.digit(0);
    t.e.binaryOp(.add);
    t.e.digit(1);
    t.e.digit(0);
    t.e.percent();
    t.e.equals();
    try std.testing.expectEqual(@as(f64, 220), t.e.displayValue());
}

test "divide by zero locks until cleared" {
    const t = setup();
    defer teardown(t);
    t.e.digit(1);
    t.e.binaryOp(.div);
    t.e.digit(0);
    t.e.equals();
    try std.testing.expectEqual(ErrKind.div_zero, t.e.err.?);
    var buf: [128]u8 = undefined;
    try std.testing.expectEqualStrings("Error", t.e.display(&buf));
    t.e.digit(5); // ignored while in error state
    try std.testing.expect(t.e.err != null);
    t.e.clearAll();
    try std.testing.expect(t.e.err == null);
}

test "scientific unary ops" {
    const t = setup();
    defer teardown(t);
    t.e.digit(9);
    t.e.unaryOp(.sqrt);
    try std.testing.expectEqual(@as(f64, 3), t.e.displayValue());
    t.e.unaryOp(.x2);
    try std.testing.expectEqual(@as(f64, 9), t.e.displayValue());
    t.e.unaryOp(.recip);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0 / 9.0), t.e.displayValue(), 1e-12);
    t.e.clearAll();
    t.e.digit(5);
    t.e.unaryOp(.fact);
    try std.testing.expectEqual(@as(f64, 120), t.e.displayValue());
    t.e.clearAll();
    t.e.digit(1);
    t.e.unaryOp(.ln);
    try std.testing.expectEqual(@as(f64, 0), t.e.displayValue());
}

test "trig with angle units and inv/hyp" {
    const t = setup();
    defer teardown(t);
    t.e.digit(9);
    t.e.digit(0);
    t.e.unaryOp(.sin);
    try std.testing.expectApproxEqAbs(@as(f64, 1), t.e.displayValue(), 1e-12);
    t.e.inv = true;
    t.e.unaryOp(.sin); // asin(1) in degrees
    try std.testing.expectApproxEqAbs(@as(f64, 90), t.e.displayValue(), 1e-9);
    t.e.inv = false;
    t.e.setAngleUnit(.rad);
    t.e.clearAll();
    t.e.digit(1);
    t.e.unaryOp(.cos);
    try std.testing.expectApproxEqAbs(@as(f64, @cos(1.0)), t.e.displayValue(), 1e-12);
    t.e.hyp = true;
    t.e.clearAll();
    t.e.digit(1);
    t.e.unaryOp(.sin); // sinh(1)
    try std.testing.expectApproxEqAbs(@as(f64, std.math.sinh(@as(f64, 1.0))), t.e.displayValue(), 1e-12);
}

test "domain errors" {
    const t = setup();
    defer teardown(t);
    t.e.digit(5);
    t.e.negate();
    t.e.unaryOp(.sqrt);
    try std.testing.expectEqual(ErrKind.domain, t.e.err.?);
    t.e.clearAll();
    t.e.digit(0);
    t.e.unaryOp(.recip);
    try std.testing.expectEqual(ErrKind.div_zero, t.e.err.?);
}

test "paste expression" {
    const t = setup();
    defer teardown(t);
    t.e.paste("2 * -3");
    try std.testing.expect(t.e.err == null);
    try std.testing.expectEqual(@as(f64, -6), t.e.displayValue());
    try std.testing.expectEqual(@as(usize, 1), t.h.items.items.len);
    try std.testing.expectEqualStrings("2 * -3", t.h.items.items[0].expression);

    t.e.paste("3 * (4 + 5)");
    try std.testing.expectEqual(@as(f64, 27), t.e.displayValue());

    t.e.paste("garbage("); // failure sets err and preserves the previous entry
    try std.testing.expect(t.e.err != null);
    var buf: [128]u8 = undefined;
    try std.testing.expectEqualStrings("Error", t.e.display(&buf));
}

test "base conversion" {
    const t = setup();
    defer teardown(t);
    var buf: [128]u8 = undefined;
    t.e.digit(2);
    t.e.digit(5);
    t.e.digit(5);
    t.e.setBase(.hex);
    try std.testing.expectEqualStrings("FF", t.e.display(&buf));
    t.e.setBase(.bin);
    try std.testing.expectEqualStrings("1111,1111", t.e.display(&buf));
    t.e.setBase(.dec);
    try std.testing.expectEqual(@as(f64, 255), t.e.displayValue());
}

test "hex entry and bitwise ops" {
    const t = setup();
    defer teardown(t);
    t.e.setBase(.hex);
    t.e.digit(0xA);
    t.e.digit(0xF);
    t.e.setBase(.dec);
    try std.testing.expectEqual(@as(f64, 175), t.e.displayValue());
    t.e.binaryOp(.bw_and);
    t.e.digit(1);
    t.e.digit(5);
    t.e.equals();
    try std.testing.expectEqual(@as(f64, 175 & 15), t.e.displayValue());
    t.e.clearAll();
    t.e.digit(5);
    t.e.unaryOp(.bw_not);
    try std.testing.expectEqual(@as(f64, @floatFromInt(~@as(i64, 5))), t.e.displayValue());
}

test "lsh and mod binary ops" {
    const t = setup();
    defer teardown(t);
    t.e.digit(1);
    t.e.binaryOp(.lsh);
    t.e.digit(4);
    t.e.equals();
    try std.testing.expectEqual(@as(f64, 16), t.e.displayValue());
    t.e.clearAll();
    t.e.digit(1);
    t.e.digit(0);
    t.e.binaryOp(.mod);
    t.e.digit(3);
    t.e.equals();
    try std.testing.expectEqual(@as(f64, 1), t.e.displayValue());
}

test "loadValue recalls a result" {
    const t = setup();
    defer teardown(t);
    t.e.loadValue(42.5);
    try std.testing.expectEqual(@as(f64, 42.5), t.e.displayValue());
    t.e.binaryOp(.add);
    t.e.digit(1);
    t.e.equals();
    try std.testing.expectEqual(@as(f64, 43.5), t.e.displayValue());
}

test "loadConstant preserves pending op and records no history" {
    const t = setup();
    defer teardown(t);
    t.e.digit(2);
    t.e.binaryOp(.mul);
    t.e.loadConstant(std.math.pi);
    try std.testing.expectEqual(@as(usize, 0), t.h.items.items.len); // no history spam
    t.e.equals();
    try std.testing.expectApproxEqAbs(@as(f64, 2 * std.math.pi), t.e.displayValue(), 1e-12);
    try std.testing.expectEqual(@as(usize, 1), t.h.items.items.len); // only the equals entry
}

test "percent result is fresh: next digit starts a new entry" {
    const t = setup();
    defer teardown(t);
    t.e.digit(2);
    t.e.digit(0);
    t.e.digit(0);
    t.e.binaryOp(.mul);
    t.e.digit(1);
    t.e.digit(0);
    t.e.percent();
    t.e.digit(5); // must replace the percent result, not append to it
    t.e.equals();
    try std.testing.expectEqual(@as(f64, 1000), t.e.displayValue());
}

test "paste accepts comma decimal separator" {
    const t = setup();
    defer teardown(t);
    t.e.decimal_sep = ',';
    t.e.paste("2,5 + 1");
    try std.testing.expect(t.e.err == null);
    try std.testing.expectEqual(@as(f64, 3.5), t.e.displayValue());
    try std.testing.expectEqualStrings("2,5 + 1", t.h.items.items[0].expression);
}

test "percent overflow sets error state" {
    const t = setup();
    defer teardown(t);
    t.e.loadConstant(1e200);
    t.e.binaryOp(.add);
    t.e.loadConstant(1e200);
    t.e.percent();
    try std.testing.expectEqual(ErrKind.overflow, t.e.err.?);
    var buf: [128]u8 = undefined;
    try std.testing.expectEqualStrings("Error", t.e.display(&buf));
}

test "setBase ignored while in error state" {
    const t = setup();
    defer teardown(t);
    t.e.digit(1);
    t.e.binaryOp(.div);
    t.e.digit(0);
    t.e.equals();
    try std.testing.expect(t.e.err != null);
    t.e.setBase(.hex);
    try std.testing.expectEqual(fmt.Base.dec, t.e.base);
}

test "regression: hex entry leading zero replacement applies to A-F" {
    const t = setup();
    defer teardown(t);
    t.e.setBase(.hex);
    t.e.digit(0xA);
    t.e.digit(0xF);
    var buf: [128]u8 = undefined;
    try std.testing.expectEqualStrings("AF", t.e.display(&buf));
}

test "regression: dms display zero-pads minutes and seconds" {
    const t = setup();
    defer teardown(t);
    t.e.dms_mode = true;
    t.e.loadConstant(5.0 + 3.0 / 60.0 + 4.0 / 3600.0);
    var buf: [128]u8 = undefined;
    try std.testing.expectEqualStrings("5.0304", t.e.display(&buf));
}

test "regression: dms seconds rounding to 60 carries into minutes" {
    const t = setup();
    defer teardown(t);
    t.e.dms_mode = true;
    t.e.loadConstant(5.0 + 3.0 / 60.0 + 59.99996 / 3600.0);
    var buf: [128]u8 = undefined;
    try std.testing.expectEqualStrings("5.0400", t.e.display(&buf));
}

test "int truncates toward zero" {
    const t = setup();
    defer teardown(t);
    t.e.digit(5);
    t.e.dot();
    t.e.digit(7);
    t.e.unaryOp(.int);
    try std.testing.expectEqual(@as(f64, 5), t.e.displayValue());
}

test "exp, log, x3 unary ops" {
    const t = setup();
    defer teardown(t);
    t.e.digit(1);
    t.e.unaryOp(.exp);
    try std.testing.expectApproxEqAbs(@as(f64, std.math.e), t.e.displayValue(), 1e-12);
    t.e.clearAll();
    t.e.digit(1);
    t.e.digit(0);
    t.e.digit(0);
    t.e.unaryOp(.log);
    try std.testing.expectEqual(@as(f64, 2), t.e.displayValue());
    t.e.clearAll();
    t.e.digit(3);
    t.e.unaryOp(.x3);
    try std.testing.expectEqual(@as(f64, 27), t.e.displayValue());
}

test "plain tan in degrees" {
    const t = setup();
    defer teardown(t);
    t.e.digit(4);
    t.e.digit(5);
    t.e.unaryOp(.tan);
    try std.testing.expectApproxEqAbs(@as(f64, 1), t.e.displayValue(), 1e-12);
}

test "repeat equals is bit-identical (no text round-trip drift)" {
    const t = setup();
    defer teardown(t);
    // 0.1+0.2 needs 17 significant digits; a 16-digit text round-trip
    // would drift ~1 ulp per repeat '=' press. The f64-typed literals keep
    // the expected chain on the same rounding path as the engine.
    t.e.paste("0.1 + 0.2");
    t.e.binaryOp(.div);
    t.e.digit(3);
    var expected: f64 = (@as(f64, 0.1) + @as(f64, 0.2)) / @as(f64, 3.0);
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        t.e.equals();
        try std.testing.expectEqual(expected, t.e.displayValue());
        expected /= 3.0;
    }
}

test "copyText is ungrouped and paste-able" {
    const t = setup();
    defer teardown(t);
    var buf: [128]u8 = undefined;
    // Fresh decimal result: no group separators, local decimal separator.
    t.e.loadConstant(1234.5);
    try std.testing.expectEqualStrings("1234.5", t.e.copyText(&buf));
    t.e.decimal_sep = ',';
    try std.testing.expectEqualStrings("1234,5", t.e.copyText(&buf));
    // Typed entry is copied as-is (separator swapped for display).
    t.e.clearAll();
    t.e.digit(1);
    t.e.digit(2);
    t.e.dot();
    t.e.digit(5);
    try std.testing.expectEqualStrings("12,5", t.e.copyText(&buf));
    // Other bases: ungrouped digits.
    t.e.clearAll();
    t.e.decimal_sep = '.';
    t.e.paste("255");
    t.e.setBase(.hex);
    try std.testing.expectEqualStrings("FF", t.e.copyText(&buf));
    // Error state.
    t.e.setBase(.dec);
    t.e.digit(1);
    t.e.binaryOp(.div);
    t.e.digit(0);
    t.e.equals();
    try std.testing.expectEqualStrings("Error", t.e.copyText(&buf));
}

test "live digit grouping while typing" {
    const t = setup();
    defer teardown(t);
    var buf: [128]u8 = undefined;
    t.e.digit(1);
    t.e.digit(0);
    t.e.digit(0);
    t.e.digit(0);
    try std.testing.expectEqualStrings("1,000", t.e.display(&buf));
    t.e.digit(0);
    t.e.digit(0);
    try std.testing.expectEqualStrings("100,000", t.e.display(&buf));
    t.e.backspace();
    t.e.backspace();
    t.e.backspace();
    try std.testing.expectEqualStrings("100", t.e.display(&buf));
    // fraction groups only the integer part
    t.e.digit(0);
    t.e.digit(0);
    t.e.digit(0);
    t.e.dot();
    t.e.digit(5);
    try std.testing.expectEqualStrings("100,000.5", t.e.display(&buf));
    // negative
    t.e.clearAll();
    t.e.digit(2);
    t.e.digit(5);
    t.e.digit(0);
    t.e.digit(0);
    t.e.negate();
    try std.testing.expectEqualStrings("-2,500", t.e.display(&buf));
    // comma locale groups with '.'
    t.e.clearAll();
    t.e.decimal_sep = ',';
    t.e.digit(1);
    t.e.digit(0);
    t.e.digit(0);
    t.e.digit(0);
    try std.testing.expectEqualStrings("1.000", t.e.display(&buf));
    // hex groups by 4
    t.e.decimal_sep = '.';
    t.e.setBase(.hex);
    t.e.digit(0xA);
    t.e.digit(0xB);
    t.e.digit(0xC);
    t.e.digit(0xD);
    t.e.digit(0xE);
    try std.testing.expectEqualStrings("A,BCDE", t.e.display(&buf));
}

test "pending operator indicator" {
    const t = setup();
    defer teardown(t);
    var buf: [128]u8 = undefined;
    t.e.digit(1);
    t.e.digit(0);
    t.e.digit(0);
    t.e.binaryOp(.div);
    try std.testing.expectEqualStrings("100\xc3\xb7", t.e.display(&buf));
    t.e.digit(5); // indicator gone once the next operand is being typed
    try std.testing.expectEqualStrings("5", t.e.display(&buf));
    t.e.clearAll();
    t.e.digit(2);
    t.e.binaryOp(.mul);
    try std.testing.expectEqualStrings("2\xc3\x97", t.e.display(&buf));
    t.e.clearAll();
    t.e.digit(3);
    t.e.binaryOp(.add);
    try std.testing.expectEqualStrings("3+", t.e.display(&buf));
    t.e.equals(); // 3 + (empty) = 6; no pending op afterwards
    try std.testing.expectEqualStrings("6", t.e.display(&buf));
}
