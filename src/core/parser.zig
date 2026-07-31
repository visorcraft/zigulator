const std = @import("std");

pub const Error = error{
    OutOfMemory,
    UnexpectedToken,
    ExpectedClosingParen,
    UndefinedName,
    InvalidNumber,
    DivisionByZero,
    Overflow,
    DomainError,
};

pub const AngleUnit = enum { deg, rad, grad };

pub const TokenKind = enum {
    num,
    ident,
    plus,
    minus,
    star,
    slash,
    caret, // ^
    pow, // **
    lparen,
    rparen,
    bang, // !
    percent, // %
    amp, // &
    pipe, // |
    shl, // <<
    shr, // >>
    eof,
};

pub const Token = struct {
    kind: TokenKind,
    lexeme: []const u8,
    value: f64 = 0,
};

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAlpha(c: u8) bool {
    return (c | 32) >= 'a' and (c | 32) <= 'z';
}

fn baseDigitValue(c: u8) ?u8 {
    if (c >= '0' and c <= '9') return c - '0';
    const l = c | 32;
    if (l >= 'a' and l <= 'f') return l - 'a' + 10;
    return null;
}

fn isValidBaseDigit(c: u8, radix: u8) bool {
    const v = baseDigitValue(c) orelse return false;
    return v < radix;
}

pub fn tokenize(allocator: std.mem.Allocator, input: []const u8) Error![]Token {
    var list: std.ArrayList(Token) = .empty;
    errdefer list.deinit(allocator);
    var tz: Tokenizer = .{ .input = input };
    while (true) {
        const t = try tz.next();
        try list.append(allocator, t);
        if (t.kind == .eof) break;
    }
    return list.toOwnedSlice(allocator);
}

pub const Tokenizer = struct {
    input: []const u8,
    pos: usize = 0,

    pub fn next(self: *Tokenizer) Error!Token {
        while (self.pos < self.input.len and self.input[self.pos] == ' ') self.pos += 1;
        if (self.pos >= self.input.len)
            return .{ .kind = .eof, .lexeme = self.input[self.pos..] };
        const start = self.pos;
        const c = self.input[self.pos];

        if (isDigit(c) or c == '.') return self.lexNumber();
        if (isAlpha(c)) {
            while (self.pos < self.input.len and isAlpha(self.input[self.pos])) self.pos += 1;
            return .{ .kind = .ident, .lexeme = self.input[start..self.pos] };
        }

        self.pos += 1;
        switch (c) {
            '+' => return .{ .kind = .plus, .lexeme = self.input[start..self.pos] },
            '-' => return .{ .kind = .minus, .lexeme = self.input[start..self.pos] },
            '*' => {
                if (self.pos < self.input.len and self.input[self.pos] == '*') {
                    self.pos += 1;
                    return .{ .kind = .pow, .lexeme = self.input[start..self.pos] };
                }
                return .{ .kind = .star, .lexeme = self.input[start..self.pos] };
            },
            '/' => return .{ .kind = .slash, .lexeme = self.input[start..self.pos] },
            '^' => return .{ .kind = .caret, .lexeme = self.input[start..self.pos] },
            '(' => return .{ .kind = .lparen, .lexeme = self.input[start..self.pos] },
            ')' => return .{ .kind = .rparen, .lexeme = self.input[start..self.pos] },
            '!' => return .{ .kind = .bang, .lexeme = self.input[start..self.pos] },
            '%' => return .{ .kind = .percent, .lexeme = self.input[start..self.pos] },
            '&' => return .{ .kind = .amp, .lexeme = self.input[start..self.pos] },
            '|' => return .{ .kind = .pipe, .lexeme = self.input[start..self.pos] },
            '<' => {
                if (self.pos < self.input.len and self.input[self.pos] == '<') {
                    self.pos += 1;
                    return .{ .kind = .shl, .lexeme = self.input[start..self.pos] };
                }
                return error.UnexpectedToken;
            },
            '>' => {
                if (self.pos < self.input.len and self.input[self.pos] == '>') {
                    self.pos += 1;
                    return .{ .kind = .shr, .lexeme = self.input[start..self.pos] };
                }
                return error.UnexpectedToken;
            },
            else => return error.UnexpectedToken,
        }
    }

    fn lexNumber(self: *Tokenizer) Error!Token {
        const start = self.pos;
        // Base-prefixed literal: 0x / 0o / 0b, only when a valid digit follows.
        if (self.input[self.pos] == '0' and self.pos + 2 < self.input.len) {
            const p = self.input[self.pos + 1] | 32;
            const radix: u8 = switch (p) {
                'x' => 16,
                'o' => 8,
                'b' => 2,
                else => 0,
            };
            if (radix != 0 and isValidBaseDigit(self.input[self.pos + 2], radix)) {
                self.pos += 2;
                const dstart = self.pos;
                while (self.pos < self.input.len and isValidBaseDigit(self.input[self.pos], radix)) self.pos += 1;
                const mag = std.fmt.parseInt(u64, self.input[dstart..self.pos], radix) catch return error.Overflow;
                return .{ .kind = .num, .lexeme = self.input[start..self.pos], .value = @floatFromInt(mag) };
            }
        }
        // Decimal number with optional fraction and exponent.
        while (self.pos < self.input.len and isDigit(self.input[self.pos])) self.pos += 1;
        if (self.pos < self.input.len and self.input[self.pos] == '.') {
            self.pos += 1;
            while (self.pos < self.input.len and isDigit(self.input[self.pos])) self.pos += 1;
        }
        if (self.pos < self.input.len and (self.input[self.pos] | 32) == 'e') {
            var look = self.pos + 1;
            if (look < self.input.len and (self.input[look] == '+' or self.input[look] == '-')) look += 1;
            if (look < self.input.len and isDigit(self.input[look])) {
                self.pos = look;
                while (self.pos < self.input.len and isDigit(self.input[self.pos])) self.pos += 1;
            }
        }
        const text = self.input[start..self.pos];
        const value = std.fmt.parseFloat(f64, text) catch return error.InvalidNumber;
        return .{ .kind = .num, .lexeme = text, .value = value };
    }
};

// --- evaluator ---

pub fn eval(allocator: std.mem.Allocator, input: []const u8, angle: AngleUnit) Error!f64 {
    // The parser is strict/canonical ('.' separator only). Callers
    // that know the active locale (engine.paste, graph window) normalize ','
    // to '.' themselves before calling.
    const toks = try tokenize(allocator, input);
    defer allocator.free(toks);
    var p: Parser = .{ .toks = toks, .angle = angle };
    const v = try p.parseExpr();
    if (p.peek().kind != .eof) return error.UnexpectedToken;
    if (std.math.isNan(v)) return error.DomainError;
    if (std.math.isInf(v)) return error.Overflow;
    return v;
}

/// Graph mode: binds variable `x`, always evaluates trig in radians.
pub fn evalX(allocator: std.mem.Allocator, input: []const u8, x: f64) Error!f64 {
    const toks = try tokenize(allocator, input);
    defer allocator.free(toks);
    var p: Parser = .{ .toks = toks, .angle = .rad, .var_name = "x", .var_value = x };
    const v = try p.parseExpr();
    if (p.peek().kind != .eof) return error.UnexpectedToken;
    return v; // NaN/Inf are legitimate plot gaps; caller skips them
}

const Parser = struct {
    toks: []const Token,
    i: usize = 0,
    angle: AngleUnit,
    var_name: ?[]const u8 = null,
    var_value: f64 = 0,

    fn peek(self: *const Parser) Token {
        return self.toks[self.i];
    }

    fn advance(self: *Parser) Token {
        const t = self.toks[self.i];
        if (t.kind != .eof) self.i += 1;
        return t;
    }

    fn peekWord(self: *const Parser, word: []const u8) bool {
        const t = self.peek();
        return t.kind == .ident and std.ascii.eqlIgnoreCase(t.lexeme, word);
    }

    fn parseExpr(self: *Parser) Error!f64 {
        return self.parseBitor();
    }

    fn parseBitor(self: *Parser) Error!f64 {
        var lhs = try self.parseBitand();
        while (true) {
            if (self.peek().kind == .pipe) {
                _ = self.advance();
                lhs = @floatFromInt(try truncI64(lhs) | try truncI64(try self.parseBitand()));
            } else if (self.peekWord("xor")) {
                _ = self.advance();
                lhs = @floatFromInt(try truncI64(lhs) ^ try truncI64(try self.parseBitand()));
            } else return lhs;
        }
    }

    fn parseBitand(self: *Parser) Error!f64 {
        var lhs = try self.parseShift();
        while (self.peek().kind == .amp) {
            _ = self.advance();
            lhs = @floatFromInt(try truncI64(lhs) & try truncI64(try self.parseShift()));
        }
        return lhs;
    }

    fn parseShift(self: *Parser) Error!f64 {
        var lhs = try self.parseAdd();
        while (true) {
            const kind = self.peek().kind;
            if (kind != .shl and kind != .shr) return lhs;
            _ = self.advance();
            const n = try truncI64(try self.parseAdd());
            if (n < 0 or n > 63) return error.DomainError;
            const a = try truncI64(lhs);
            const shift: u6 = @intCast(n);
            lhs = @floatFromInt(if (kind == .shl) a << shift else a >> shift);
        }
    }

    fn parseAdd(self: *Parser) Error!f64 {
        var lhs = try self.parseMul();
        while (true) {
            switch (self.peek().kind) {
                .plus => {
                    _ = self.advance();
                    lhs += try self.parseMul();
                },
                .minus => {
                    _ = self.advance();
                    lhs -= try self.parseMul();
                },
                else => return lhs,
            }
        }
    }

    fn parseMul(self: *Parser) Error!f64 {
        var lhs = try self.parseUnary();
        while (true) {
            switch (self.peek().kind) {
                .star => {
                    _ = self.advance();
                    lhs *= try self.parseUnary();
                },
                .slash => {
                    _ = self.advance();
                    const rhs = try self.parseUnary();
                    if (rhs == 0) return error.DivisionByZero;
                    lhs /= rhs;
                },
                else => {
                    if (self.peekWord("mod")) {
                        _ = self.advance();
                        const rhs = try self.parseUnary();
                        if (rhs == 0) return error.DivisionByZero;
                        lhs = @rem(lhs, rhs);
                    } else return lhs;
                },
            }
        }
    }

    fn parseUnary(self: *Parser) Error!f64 {
        switch (self.peek().kind) {
            .plus => {
                _ = self.advance();
                return self.parseUnary();
            },
            .minus => {
                _ = self.advance();
                return -(try self.parseUnary());
            },
            else => return self.parsePower(),
        }
    }

    fn parsePower(self: *Parser) Error!f64 {
        const base = try self.parsePostfix();
        const kind = self.peek().kind;
        if (kind != .caret and kind != .pow) return base;
        _ = self.advance();
        const exp = try self.parseUnary(); // right-assoc; allows 2^-3
        const v = std.math.pow(f64, base, exp);
        if (std.math.isNan(v)) return error.DomainError;
        if (std.math.isInf(v)) return error.Overflow;
        return v;
    }

    fn parsePostfix(self: *Parser) Error!f64 {
        var v = try self.parsePrimary();
        while (true) {
            switch (self.peek().kind) {
                .bang => {
                    _ = self.advance();
                    v = try factorial(v);
                },
                .percent => {
                    _ = self.advance();
                    v /= 100;
                },
                else => return v,
            }
        }
    }

    fn parsePrimary(self: *Parser) Error!f64 {
        const t = self.peek();
        switch (t.kind) {
            .num => {
                _ = self.advance();
                return t.value;
            },
            .lparen => {
                _ = self.advance();
                const v = try self.parseExpr();
                if (self.peek().kind != .rparen) return error.ExpectedClosingParen;
                _ = self.advance();
                return v;
            },
            .ident => {
                _ = self.advance();
                const name = t.lexeme;
                if (std.ascii.eqlIgnoreCase(name, "pi")) return std.math.pi;
                if (std.ascii.eqlIgnoreCase(name, "e")) return std.math.e;
                if (self.var_name) |vn| {
                    if (std.ascii.eqlIgnoreCase(name, vn)) return self.var_value;
                }
                if (self.peek().kind != .lparen) return error.UndefinedName;
                _ = self.advance();
                const arg = try self.parseExpr();
                if (self.peek().kind != .rparen) return error.ExpectedClosingParen;
                _ = self.advance();
                return self.applyFunc(name, arg);
            },
            else => return error.UnexpectedToken,
        }
    }

    fn toRad(self: *const Parser, x: f64) f64 {
        return switch (self.angle) {
            .deg => x * std.math.pi / 180,
            .grad => x * std.math.pi / 200,
            .rad => x,
        };
    }

    fn fromRad(self: *const Parser, x: f64) f64 {
        return switch (self.angle) {
            .deg => x * 180 / std.math.pi,
            .grad => x * 200 / std.math.pi,
            .rad => x,
        };
    }

    fn applyFunc(self: *Parser, name: []const u8, arg: f64) Error!f64 {
        const eq = std.ascii.eqlIgnoreCase;
        if (eq(name, "sqrt")) {
            if (arg < 0) return error.DomainError;
            return @sqrt(arg);
        }
        if (eq(name, "sin")) return @sin(self.toRad(arg));
        if (eq(name, "cos")) return @cos(self.toRad(arg));
        if (eq(name, "tan")) return @tan(self.toRad(arg));
        if (eq(name, "asin")) {
            if (arg < -1 or arg > 1) return error.DomainError;
            return self.fromRad(std.math.asin(arg));
        }
        if (eq(name, "acos")) {
            if (arg < -1 or arg > 1) return error.DomainError;
            return self.fromRad(std.math.acos(arg));
        }
        if (eq(name, "atan")) return self.fromRad(std.math.atan(arg));
        if (eq(name, "ln")) {
            if (arg <= 0) return error.DomainError;
            return @log(arg);
        }
        if (eq(name, "log")) {
            if (arg <= 0) return error.DomainError;
            return @log10(arg);
        }
        if (eq(name, "exp")) return @exp(arg);
        if (eq(name, "abs")) return @abs(arg);
        return error.UndefinedName;
    }
};

pub fn truncI64(v: f64) Error!i64 {
    if (std.math.isNan(v)) return error.DomainError;
    if (v >= 9223372036854775808.0 or v < -9223372036854775808.0) return error.Overflow;
    return @intFromFloat(@trunc(v));
}

pub fn factorial(v: f64) Error!f64 {
    if (std.math.isNan(v) or v < 0 or @trunc(v) != v) return error.DomainError;
    if (v > 170) return error.Overflow;
    var r: f64 = 1;
    var i: f64 = 2;
    while (i <= v) : (i += 1) r *= i;
    return r;
}

test "tokenize numbers and operators" {
    const toks = try tokenize(std.testing.allocator, "2 * -3");
    defer std.testing.allocator.free(toks);
    try std.testing.expectEqual(@as(usize, 5), toks.len); // 2, *, -, 3, eof
    try std.testing.expectEqual(TokenKind.num, toks[0].kind);
    try std.testing.expectEqual(@as(f64, 2), toks[0].value);
    try std.testing.expectEqual(TokenKind.star, toks[1].kind);
    try std.testing.expectEqual(TokenKind.minus, toks[2].kind);
    try std.testing.expectEqual(@as(f64, 3), toks[3].value);
    try std.testing.expectEqual(TokenKind.eof, toks[4].kind);
}

test "tokenize base literals" {
    const toks = try tokenize(std.testing.allocator, "0x10 + 0b101 + 0o17");
    defer std.testing.allocator.free(toks);
    try std.testing.expectEqual(@as(f64, 16), toks[0].value);
    try std.testing.expectEqual(@as(f64, 5), toks[2].value);
    try std.testing.expectEqual(@as(f64, 15), toks[4].value);
}

test "tokenize 0x without hex digit is zero then ident" {
    const toks = try tokenize(std.testing.allocator, "0x");
    defer std.testing.allocator.free(toks);
    try std.testing.expectEqual(TokenKind.num, toks[0].kind);
    try std.testing.expectEqual(@as(f64, 0), toks[0].value);
    try std.testing.expectEqual(TokenKind.ident, toks[1].kind);
    try std.testing.expectEqualStrings("x", toks[1].lexeme);
}

test "tokenize scientific notation and e constant" {
    const toks = try tokenize(std.testing.allocator, "1.5e3 2E-4 2e");
    defer std.testing.allocator.free(toks);
    try std.testing.expectEqual(@as(f64, 1500), toks[0].value);
    try std.testing.expectEqual(@as(f64, 2e-4), toks[1].value);
    try std.testing.expectEqual(@as(f64, 2), toks[2].value);
    try std.testing.expectEqual(TokenKind.ident, toks[3].kind); // bare e
}

test "tokenize punctuation and word idents" {
    const toks = try tokenize(std.testing.allocator, "(2 + 5)^3 ! sqrt(3) % & | xor << >> mod");
    defer std.testing.allocator.free(toks);
    const kinds = [_]TokenKind{ .lparen, .num, .plus, .num, .rparen, .caret, .num, .bang, .ident, .lparen, .num, .rparen, .percent, .amp, .pipe, .ident, .shl, .shr, .ident, .eof };
    try std.testing.expectEqual(kinds.len, toks.len);
    for (kinds, 0..) |k, i| try std.testing.expectEqual(k, toks[i].kind);
    try std.testing.expectEqualStrings("sqrt", toks[8].lexeme);
    try std.testing.expectEqualStrings("xor", toks[15].lexeme);
    try std.testing.expectEqualStrings("mod", toks[18].lexeme);
}

test "tokenize double star is pow" {
    const toks = try tokenize(std.testing.allocator, "2**8");
    defer std.testing.allocator.free(toks);
    try std.testing.expectEqual(TokenKind.pow, toks[1].kind);
}

fn expectEval(expected: f64, input: []const u8) !void {
    const v = try eval(std.testing.allocator, input, .deg);
    try std.testing.expectApproxEqAbs(expected, v, 1e-9);
}

test "regression: unary signs" {
    try expectEval(-6, "2 * -3");
    try expectEval(-2.0 / 3.0, "2 / -3");
    try expectEval(5, "2 - -3");
    try expectEval(5, "2--3");
    try expectEval(6, "2 * +3");
}

test "regression: precedence and power" {
    try expectEval(27, "3 * (4 + 5)");
    try expectEval(256, "2**8");
    try expectEval(0.125, "2 ** -3");
    try expectEval(-4, "-2^2");
    try expectEval(343, "(2 + 5)^3");
    try expectEval(512, "2^3^2"); // right-associative
}

test "functions with degrees" {
    try expectEval(1.7320508075688772, "sqrt(3)");
    try expectEval(@sin(std.math.pi / 2.0 * std.math.pi / 180.0), "sin(pi / 2)");
    try expectEval(3, "abs(-3)");
    try expectEval(0, "ln(1)");
    try expectEval(2, "log(100)");
    try expectEval(1, "cos(0)");
    try expectEval(1, "tan(45)");
    try expectEval(90, "asin(1)");
    try expectEval(0, "acos(1)");
    try expectEval(45, "atan(1)");
    try expectEval(std.math.e, "exp(1)");
}

test "angle units" {
    try expectEval(1, "sin(90)"); // eval defaults to .deg in expectEval
    const v_rad = try eval(std.testing.allocator, "sin(pi / 2)", .rad);
    try std.testing.expectApproxEqAbs(@as(f64, 1), v_rad, 1e-9);
    const v_grad = try eval(std.testing.allocator, "sin(100)", .grad);
    try std.testing.expectApproxEqAbs(@as(f64, 1), v_grad, 1e-9);
}

test "postfix operators" {
    try expectEval(120, "5!");
    try expectEval(0.5, "50%");
    try expectEval(1, "10 mod 3");
    try std.testing.expectError(error.Overflow, eval(std.testing.allocator, "171!", .deg));
    try std.testing.expectError(error.DomainError, eval(std.testing.allocator, "2.5!", .deg));
}

test "literals and bitwise" {
    try expectEval(16, "0x10");
    try expectEval(5, "0b101");
    try expectEval(15, "0o17");
    try expectEval(1500, "1.5e3");
    try expectEval(1, "5 & 3");
    try expectEval(7, "5 | 3");
    try expectEval(6, "5 xor 3");
    try expectEval(16, "1 << 4");
    try expectEval(4, "16 >> 2");
    try expectEval(2, "2.5 & 3"); // truncation toward zero
}

test "errors" {
    try std.testing.expectError(error.DivisionByZero, eval(std.testing.allocator, "1/0", .deg));
    try std.testing.expectError(error.DivisionByZero, eval(std.testing.allocator, "1 mod 0", .deg));
    try std.testing.expectError(error.DomainError, eval(std.testing.allocator, "sqrt(-1)", .deg));
    try std.testing.expectError(error.UndefinedName, eval(std.testing.allocator, "foo(1)", .deg));
    try std.testing.expectError(error.ExpectedClosingParen, eval(std.testing.allocator, "(1+2", .deg));
    try std.testing.expectError(error.UnexpectedToken, eval(std.testing.allocator, "2 +", .deg));
    try std.testing.expectError(error.UnexpectedToken, eval(std.testing.allocator, "2 3", .deg));
}

test "case-insensitive names" {
    try expectEval(1, "SIN(90)");
    try expectEval(std.math.pi, "Pi");
}

test "graph mode: evalX uses radians and binds x" {
    const v = try evalX(std.testing.allocator, "x^2 + 1", 3);
    try std.testing.expectApproxEqAbs(@as(f64, 10), v, 1e-9);
    const s = try evalX(std.testing.allocator, "sin(x)", std.math.pi / 2.0);
    try std.testing.expectApproxEqAbs(@as(f64, 1), s, 1e-9);
}

test "regression: parser is strict about the decimal separator" {
    // US-locale input like "1,234" must error, not misparse as 1.234;
    // comma normalization happens at locale-aware callers, not the parser.
    try std.testing.expectError(error.UnexpectedToken, eval(std.testing.allocator, "2,5 + 1", .deg));
}

test "regression: mod is multiplicative (Python convention)" {
    try expectEval(2, "2 + 3 mod 1"); // 2 + (3 mod 1), not (2 + 3) mod 1
}

test "factorial of zero" {
    try expectEval(1, "0!");
}

test "shift edge cases" {
    try expectEval(1, "1 << 0");
    // 1 shifted into the sign bit: i64 min bit pattern, negative as f64.
    try expectEval(@as(f64, @floatFromInt(@as(i64, 1) << 63)), "1 << 63");
    try std.testing.expectEqual(@as(f64, -9223372036854775808), try eval(std.testing.allocator, "1 << 63", .deg));
    try std.testing.expectError(error.DomainError, eval(std.testing.allocator, "1 << 64", .deg));
}

test "regression: C-style bitwise precedence" {
    try expectEval(3, "5 & 3 | 2"); // (5 & 3) | 2: bitand tighter than bitor
    try expectEval(8, "1 << 2 + 1"); // 1 << (2 + 1): additive tighter than shift
}

test "contract: eval maps Inf to Overflow, evalX returns Inf as plot gap" {
    try std.testing.expectError(error.Overflow, eval(std.testing.allocator, "1e308 * 10", .deg));
    const v = try evalX(std.testing.allocator, "1e308 * 10", 0);
    try std.testing.expect(std.math.isPositiveInf(v));
}
