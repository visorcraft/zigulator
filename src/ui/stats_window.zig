const zgui = @import("zgui");
const app_mod = @import("app.zig");
const fmt = @import("../core/format.zig");

const App = app_mod.App;

pub fn draw(app: *App) void {
    zgui.setNextWindowSize(.{ .w = 320, .h = 380, .cond = .first_use_ever });
    if (!zgui.begin(app.t(.statistics), .{ .popen = &app.show_stats })) {
        zgui.end();
        return;
    }
    defer zgui.end();

    const st = &app.stats;

    if (zgui.button("Dat", .{})) st.add(app.engine.displayValue()) catch {};
    zgui.sameLine(.{});
    if (zgui.button("CAD", .{})) st.clear();
    zgui.separator();

    zgui.textUnformatted(app.t(.dataset));
    var remove_at: ?usize = null;
    for (st.data.items, 0..) |v, i| {
        zgui.pushIntId(@intCast(i));
        defer zgui.popId();
        if (zgui.smallButton("x")) remove_at = i;
        zgui.sameLine(.{});
        var vbuf: [64]u8 = undefined;
        const text = fmt.float(&vbuf, v, .{
            .decimal_sep = app.engine.decimal_sep,
        });
        zgui.textUnformatted(text);
    }
    if (remove_at) |i| st.removeAt(i);
    zgui.separator();

    row(app.t(.count), statBuf(app, @floatFromInt(st.count())));
    row(app.t(.sum), statBuf(app, st.sum()));
    row(app.t(.mean), if (st.mean()) |m| statBuf(app, m) else "-");
    row(app.t(.stddev), if (st.stddevSample()) |s| statBuf(app, s) else "-");
}

var stat_buf: [64]u8 = undefined;

fn statBuf(app: *App, v: f64) []const u8 {
    return fmt.float(&stat_buf, v, .{
        .decimal_sep = app.engine.decimal_sep,
    });
}

fn row(label: []const u8, value: []const u8) void {
    zgui.textUnformatted(label);
    zgui.sameLine(.{ .offset_from_start_x = 140 });
    zgui.textUnformatted(value);
}
