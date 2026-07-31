const std = @import("std");
const engine_mod = @import("engine.zig");
const i18n = @import("i18n.zig");

/// Session preferences that survive restarts.
/// Stored as simple key=value lines under the XDG config home.
pub const Prefs = struct {
    mode: engine_mod.Mode = .standard,
    lang: i18n.Lang = .en,
    decimal_sep: u8 = '.',
};

/// Parse a prefs file body. Unknown keys and bad values are ignored so an
/// older or hand-edited file never prevents startup.
pub fn parse(text: []const u8) Prefs {
    var prefs: Prefs = .{};
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = std.mem.trim(u8, line[0..eq], " \t");
        const val = std.mem.trim(u8, line[eq + 1 ..], " \t");
        if (std.mem.eql(u8, key, "mode")) {
            if (std.mem.eql(u8, val, "simple")) prefs.mode = .simple;
            if (std.mem.eql(u8, val, "standard")) prefs.mode = .standard;
            if (std.mem.eql(u8, val, "scientific")) prefs.mode = .scientific;
        } else if (std.mem.eql(u8, key, "lang")) {
            if (std.mem.eql(u8, val, "en")) prefs.lang = .en;
            if (std.mem.eql(u8, val, "pt_br")) prefs.lang = .pt_br;
        } else if (std.mem.eql(u8, key, "decimal_sep")) {
            if (val.len == 1 and (val[0] == '.' or val[0] == ','))
                prefs.decimal_sep = val[0];
        }
    }
    return prefs;
}

pub fn format(prefs: Prefs, buf: []u8) []const u8 {
    const mode = switch (prefs.mode) {
        .simple => "simple",
        .standard => "standard",
        .scientific => "scientific",
    };
    const lang = switch (prefs.lang) {
        .en => "en",
        .pt_br => "pt_br",
    };
    return std.fmt.bufPrint(buf, "mode={s}\nlang={s}\ndecimal_sep={c}\n", .{
        mode,
        lang,
        prefs.decimal_sep,
    }) catch buf[0..0];
}

/// Resolve `~/.config/zigulator/prefs` (or `$XDG_CONFIG_HOME/zigulator/prefs`).
/// Returns null if no suitable home/config path is available.
pub fn configPath(buf: []u8) ?[:0]const u8 {
    if (std.c.getenv("XDG_CONFIG_HOME")) |xdg| {
        const base = std.mem.span(xdg);
        if (base.len > 0)
            return std.fmt.bufPrintZ(buf, "{s}/zigulator/prefs", .{base}) catch null;
    }
    if (std.c.getenv("HOME")) |home| {
        const base = std.mem.span(home);
        if (base.len > 0)
            return std.fmt.bufPrintZ(buf, "{s}/.config/zigulator/prefs", .{base}) catch null;
    }
    return null;
}

pub fn load() Prefs {
    var path_buf: [512]u8 = undefined;
    const path = configPath(&path_buf) orelse return .{};
    const fd = std.posix.openat(std.posix.AT.FDCWD, path, .{}, 0) catch return .{};
    defer _ = std.os.linux.close(fd);

    var data: [1024]u8 = undefined;
    const n = std.os.linux.read(fd, &data, data.len);
    if (@as(isize, @bitCast(n)) < 0) return .{};
    return parse(data[0..n]);
}

pub fn save(prefs: Prefs) void {
    var path_buf: [512]u8 = undefined;
    const path = configPath(&path_buf) orelse return;
    ensureParentDir(path);

    const fd = std.posix.openat(
        std.posix.AT.FDCWD,
        path,
        .{ .ACCMODE = .WRONLY, .CREAT = true, .TRUNC = true },
        0o644,
    ) catch return;
    defer _ = std.os.linux.close(fd);

    var body_buf: [128]u8 = undefined;
    const body = format(prefs, &body_buf);
    writeAll(fd, body);
}

fn ensureParentDir(path: [:0]const u8) void {
    // path is ".../zigulator/prefs" - mkdir the "zigulator" directory.
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return;
    if (slash == 0) return;
    var dir_buf: [512]u8 = undefined;
    if (slash >= dir_buf.len) return;
    @memcpy(dir_buf[0..slash], path[0..slash]);
    dir_buf[slash] = 0;
    const dir_z: [:0]const u8 = dir_buf[0..slash :0];
    // Also ensure ~/.config exists.
    if (std.mem.lastIndexOfScalar(u8, dir_z, '/')) |p| {
        if (p > 0 and p < dir_buf.len) {
            var parent_buf: [512]u8 = undefined;
            @memcpy(parent_buf[0..p], dir_z[0..p]);
            parent_buf[p] = 0;
            _ = std.os.linux.mkdir(@as([*:0]const u8, @ptrCast(&parent_buf)), 0o755);
        }
    }
    _ = std.os.linux.mkdir(dir_z.ptr, 0o755);
}

fn writeAll(fd: std.posix.fd_t, bytes: []const u8) void {
    var off: usize = 0;
    while (off < bytes.len) {
        const n = std.os.linux.write(fd, bytes.ptr + off, bytes.len - off);
        if (@as(isize, @bitCast(n)) <= 0) return;
        off += n;
    }
}

test "prefs parse and format round-trip" {
    const text =
        \\# zigulator preferences
        \\mode=simple
        \\lang=pt_br
        \\decimal_sep=,
        \\
    ;
    const p = parse(text);
    try std.testing.expect(p.mode == .simple);
    try std.testing.expect(p.lang == .pt_br);
    try std.testing.expect(p.decimal_sep == ',');

    var buf: [128]u8 = undefined;
    const out = format(p, &buf);
    const again = parse(out);
    try std.testing.expect(again.mode == .simple);
    try std.testing.expect(again.lang == .pt_br);
    try std.testing.expect(again.decimal_sep == ',');
}

test "prefs parse ignores garbage and defaults" {
    const p = parse("mode=nope\nlang=xx\ndecimal_sep=!\nfoo=bar\n");
    try std.testing.expect(p.mode == .standard);
    try std.testing.expect(p.lang == .en);
    try std.testing.expect(p.decimal_sep == '.');
}

test "prefs parse accepts scientific and en" {
    const p = parse("mode=scientific\nlang=en\ndecimal_sep=.\n");
    try std.testing.expect(p.mode == .scientific);
    try std.testing.expect(p.lang == .en);
    try std.testing.expect(p.decimal_sep == '.');
}
