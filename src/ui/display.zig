const std = @import("std");
const zgui = @import("zgui");
const app_mod = @import("app.zig");
const engine_mod = @import("../core/engine.zig");
const i18n = @import("../core/i18n.zig");

const App = app_mod.App;

fn errorKey(kind: engine_mod.ErrKind) i18n.Key {
    return switch (kind) {
        .div_zero => .error_div_zero,
        .overflow => .error_overflow,
        .domain => .error_domain,
        .invalid_input => .error_invalid,
    };
}

pub fn draw(app: *App) void {
    const e = &app.engine;

    // Status line: memory / angle / base indicators (minimal in Simple mode).
    var sbuf: [64]u8 = undefined;
    const status = if (e.mode == .simple)
        std.fmt.bufPrintZ(&sbuf, "{s}", .{if (e.has_mem) "M" else ""}) catch ""
    else
        std.fmt.bufPrintZ(&sbuf, "{s}{s}{s}", .{
            if (e.has_mem) "M  " else "",
            switch (e.angle) {
                .deg => "DEG ",
                .rad => "RAD ",
                .grad => "GRAD ",
            },
            switch (e.base) {
                .dec => "",
                .hex => "HEX",
                .oct => "OCT",
                .bin => "BIN",
            },
        }) catch "";
    zgui.textDisabled("{s}", .{status});

    // Main readout, right-aligned, double-size.
    var buf: [128]u8 = undefined;
    const text: []const u8 = if (e.err) |kind| app.t(errorKey(kind)) else e.display(&buf);
    var zbuf: [160]u8 = undefined;
    const ztext = std.fmt.bufPrintZ(&zbuf, "{s}", .{text}) catch "Error";

    // Readout font: monospace display font when available, otherwise the
    // default font at double size. ImGui 1.92.1 replaced SetWindowFontScale
    // with pushFont(null, size).
    if (app.display_font) |font| {
        // Loaded at 28px in main.zig; push at its native size.
        zgui.pushFont(font, 28.0);
    } else {
        zgui.pushFont(null, zgui.getFontSize() * 2.0);
    }
    const avail = zgui.getContentRegionAvail();
    const tsize = zgui.calcTextSize(ztext, .{});
    if (avail[0] > tsize[0]) zgui.setCursorPosX(zgui.getCursorPosX() + avail[0] - tsize[0]);
    zgui.textUnformatted(ztext);
    zgui.popFont();
    zgui.separator();
}
