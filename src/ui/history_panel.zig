const std = @import("std");
const zgui = @import("zgui");
const app_mod = @import("app.zig");
const fmt = @import("../core/format.zig");

const App = app_mod.App;

pub fn draw(app: *App) void {
    zgui.setNextWindowSize(.{ .w = 280, .h = 420, .cond = .first_use_ever });
    if (!zgui.begin(app.t(.history), .{ .popen = &app.show_history })) {
        zgui.end();
        return;
    }
    defer zgui.end();

    if (zgui.button(app.t(.clear_all), .{})) app.history.clear();
    zgui.separator();

    var i = app.history.items.items.len;
    while (i > 0) {
        i -= 1;
        const entry = app.history.items.items[i];
        var rbuf: [64]u8 = undefined;
        const result = fmt.float(&rbuf, entry.result, .{
            .decimal_sep = app.engine.decimal_sep,
        });
        // Truncate long expressions so every entry always renders (the
        // label buffer would otherwise overflow and drop the entry).
        const expr = entry.expression;
        var tbuf: [64]u8 = undefined;
        const shown = if (expr.len > 60) blk: {
            @memcpy(tbuf[0..60], expr[0..60]);
            @memcpy(tbuf[60..63], "...");
            break :blk tbuf[0..63];
        } else expr;
        var lbuf: [256]u8 = undefined;
        const label = std.fmt.bufPrintZ(&lbuf, "{s} = {s}##{d}", .{ shown, result, i }) catch continue;
        if (zgui.selectable(label, .{})) app.engine.loadValue(entry.result);
    }
}
