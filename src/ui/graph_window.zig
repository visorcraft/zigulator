const std = @import("std");
const zgui = @import("zgui");
const app_mod = @import("app.zig");
const parser = @import("../core/parser.zig");

const App = app_mod.App;

const n_samples = 400;
const max_functions = 8;

const palette = [8][4]f32{
    .{ 0.231, 0.612, 1.0, 1.0 }, // accent blue
    .{ 0.95, 0.55, 0.25, 1.0 },
    .{ 0.40, 0.85, 0.45, 1.0 },
    .{ 0.90, 0.35, 0.45, 1.0 },
    .{ 0.75, 0.55, 0.95, 1.0 },
    .{ 0.95, 0.85, 0.30, 1.0 },
    .{ 0.35, 0.85, 0.85, 1.0 },
    .{ 0.95, 0.55, 0.75, 1.0 },
};

const Function = struct {
    buf: [96:0]u8 = std.mem.zeroes([96:0]u8),
    color: [4]f32,
    err: bool = false,

    fn text(self: *const Function) []const u8 {
        return std.mem.sliceTo(&self.buf, 0);
    }
};

pub const State = struct {
    allocator: std.mem.Allocator,
    functions: std.ArrayList(Function),
    x_min: f64 = -10,
    x_max: f64 = 10,
    // Last range pushed to ImPlot, so drag changes can be re-applied
    // (.cond = .once would otherwise ignore them) without breaking
    // mouse pan/zoom.
    applied_min: f64 = -10,
    applied_max: f64 = 10,
    // Sample buffers allocated once at init; draw skips plotting if empty (OOM).
    xs: []f64,
    ys: []f64,

    pub fn init(allocator: std.mem.Allocator) State {
        var st: State = .{
            .allocator = allocator,
            .functions = .empty,
            .xs = allocator.alloc(f64, n_samples) catch &.{},
            .ys = allocator.alloc(f64, n_samples) catch &.{},
        };
        st.functions.append(allocator, .{ .color = palette[0] }) catch return st;
        const f = &st.functions.items[0];
        const initial = "sin(x)";
        @memcpy(f.buf[0..initial.len], initial);
        return st;
    }

    pub fn deinit(self: *State) void {
        // OOM fallbacks use empty slices (&.{}), which must not be freed.
        if (self.xs.len != 0) self.allocator.free(self.xs);
        if (self.ys.len != 0) self.allocator.free(self.ys);
        self.functions.deinit(self.allocator);
    }
};

pub fn draw(app: *App) void {
    const st = &app.graph;
    zgui.setNextWindowSize(.{ .w = 600, .h = 500, .cond = .first_use_ever });
    if (!zgui.begin(app.t(.graph), .{ .popen = &app.show_graph })) {
        zgui.end();
        return;
    }
    defer zgui.end();

    // --- function list ---
    var remove_at: ?usize = null;
    for (st.functions.items, 0..) |*f, i| {
        zgui.pushIntId(@intCast(i));
        defer zgui.popId();
        if (zgui.smallButton("x")) remove_at = i;
        zgui.sameLine(.{});
        var lbuf: [16]u8 = undefined;
        const label = std.fmt.bufPrintZ(&lbuf, "y{d}=", .{i + 1}) catch "y=";
        zgui.textUnformatted(label);
        zgui.sameLine(.{});
        zgui.pushStyleColor4f(.{ .idx = .text, .c = f.color });
        _ = zgui.inputText("##expr", .{ .buf = f.buf[0..] });
        zgui.popStyleColor(.{});
        if (f.err) {
            zgui.sameLine(.{});
            zgui.textColored(.{ 0.9, 0.3, 0.3, 1.0 }, "{s}", .{app.t(.error_invalid)});
        }
    }
    if (remove_at) |i| _ = st.functions.orderedRemove(i);
    if (st.functions.items.len < max_functions) {
        if (zgui.button(app.t(.add_function), .{})) {
            st.functions.append(st.allocator, .{
                .color = palette[st.functions.items.len % palette.len],
            }) catch {};
        }
    }

    // --- x range ---
    _ = zgui.dragScalar(app.t(.x_min), f64, .{ .v = &st.x_min, .speed = 0.1 });
    zgui.sameLine(.{});
    _ = zgui.dragScalar(app.t(.x_max), f64, .{ .v = &st.x_max, .speed = 0.1 });

    // --- plot ---
    if (st.x_max <= st.x_min) return;
    if (zgui.plot.beginPlot("##graph", .{ .w = -1, .h = -1 })) {
        defer zgui.plot.endPlot();
        zgui.plot.setupAxis(.x1, .{ .label = "x" });
        zgui.plot.setupAxis(.y1, .{ .label = "y" });
        if (st.x_min != st.applied_min or st.x_max != st.applied_max) {
            // Range edited via the drags: force the new limits once.
            zgui.plot.setupAxisLimits(.x1, .{ .min = st.x_min, .max = st.x_max, .cond = .always });
            st.applied_min = st.x_min;
            st.applied_max = st.x_max;
        } else {
            zgui.plot.setupAxisLimits(.x1, .{ .min = st.x_min, .max = st.x_max, .cond = .once });
        }
        zgui.plot.setupFinish();

        const xs = st.xs;
        const ys = st.ys;
        if (xs.len < n_samples or ys.len < n_samples) return;

        for (xs, 0..) |*x, i| {
            x.* = st.x_min + (st.x_max - st.x_min) * @as(f64, @floatFromInt(i)) / (n_samples - 1);
        }

        for (st.functions.items, 0..) |*f, i| {
            // The parser is strict ('.' only); translate ',' here when the
            // comma decimal separator is active.
            var translated: ?[]u8 = null;
            defer if (translated) |buf| st.allocator.free(buf);
            var text: []const u8 = f.text();
            if (app.engine.decimal_sep == ',' and std.mem.indexOfScalar(u8, text, ',') != null) {
                const buf = st.allocator.dupe(u8, text) catch continue;
                std.mem.replaceScalar(u8, buf, ',', '.');
                translated = buf;
                text = buf;
            }
            f.err = false;
            if (text.len == 0) continue;
            // First sample: distinguish syntax errors (mark row red) from
            // domain gaps like sqrt(x) at x<0 (plottable, just NaN there).
            ys[0] = parser.evalX(st.allocator, text, xs[0]) catch |e| switch (e) {
                // OOM is not a syntax error: skip plotting, don't mark red.
                error.DomainError, error.DivisionByZero, error.Overflow, error.OutOfMemory => std.math.nan(f64),
                else => {
                    f.err = true;
                    continue;
                },
            };
            for (ys[1..], xs[1..]) |*y, x| {
                y.* = parser.evalX(st.allocator, text, x) catch std.math.nan(f64);
            }
            var lbuf: [16]u8 = undefined;
            const label = std.fmt.bufPrintZ(&lbuf, "y{d}", .{i + 1}) catch "y";
            zgui.plot.setNextLineStyle(.{ .col = f.color });
            zgui.plot.plotLine(label, f64, .{ .xv = xs, .yv = ys });
        }
    }
}
