const std = @import("std");
const zgui = @import("zgui");
const app_mod = @import("app.zig");
const engine_mod = @import("../core/engine.zig");
const theme = @import("theme.zig");

const App = app_mod.App;

pub const bw = 68.0; // button width (fixed-size UI: hex row, function rail)
pub const bh = 44.0; // button height (fixed-size UI: function rail)

fn buttonAt(label: [:0]const u8, col: usize, width: f32, height: f32) bool {
    if (col > 0) zgui.sameLine(.{});
    return zgui.button(label, .{ .w = width, .h = height });
}

fn opButtonAt(label: [:0]const u8, col: usize, width: f32, height: f32, engaged: bool) bool {
    // Engaged (pending) operators get the active color as their resting
    // color so the user can see the operator is in effect.
    zgui.pushStyleColor4f(.{ .idx = .button, .c = if (engaged) theme.accent_hover else theme.accent });
    zgui.pushStyleColor4f(.{ .idx = .button_hovered, .c = theme.accent_hover });
    zgui.pushStyleColor4f(.{ .idx = .button_active, .c = theme.accent_active });
    defer zgui.popStyleColor(.{ .count = 3 });
    return buttonAt(label, col, width, height);
}

pub fn digitButton(app: *App, label: [:0]const u8, d: u8, col: usize, width: f32, height: f32) void {
    if (buttonAt(label, col, width, height)) app.engine.digit(d);
}

/// Phone-style Simple keypad: 4×5, pill buttons, coral C, teal =.
/// Layout:
///   C   <-   %   /
///   7   8    9   *
///   4   5    6   -
///   1   2    3   +
///   ()  0    .   =
pub fn drawSimple(app: *App) void {
    const e = &app.engine;

    const cols = 4;
    const rows = 5;
    const avail = zgui.getContentRegionAvail();
    const spacing = zgui.getStyle().item_spacing;
    const w = @max(48.0, (avail[0] - spacing[0] * (cols - 1)) / cols);
    const h = @max(36.0, (avail[1] - spacing[1] * (rows - 1)) / rows);

    // Pill-shaped buttons.
    zgui.pushStyleVar1f(.{ .idx = .frame_rounding, .v = h * 0.5 });
    defer zgui.popStyleVar(.{});

    // Row 1: C (coral label), backspace, %, /
    {
        zgui.pushStyleColor4f(.{ .idx = .text, .c = theme.danger_text });
        if (buttonAt("C", 0, w, h)) e.clearAll();
        zgui.popStyleColor(.{});
    }
    if (buttonAt("<-", 1, w, h)) e.backspace();
    if (buttonAt("%", 2, w, h)) e.percent();
    if (buttonAt("/", 3, w, h)) e.binaryOp(.div);

    digitButton(app, "7", 7, 0, w, h);
    digitButton(app, "8", 8, 1, w, h);
    digitButton(app, "9", 9, 2, w, h);
    if (buttonAt("*", 3, w, h)) e.binaryOp(.mul);

    digitButton(app, "4", 4, 0, w, h);
    digitButton(app, "5", 5, 1, w, h);
    digitButton(app, "6", 6, 2, w, h);
    if (buttonAt("-", 3, w, h)) e.binaryOp(.sub);

    digitButton(app, "1", 1, 0, w, h);
    digitButton(app, "2", 2, 1, w, h);
    digitButton(app, "3", 3, 2, w, h);
    if (buttonAt("+", 3, w, h)) e.binaryOp(.add);

    if (buttonAt("()", 0, w, h)) e.paren();
    digitButton(app, "0", 0, 1, w, h);
    if (buttonAt(".", 2, w, h)) e.dot();
    {
        zgui.pushStyleColor4f(.{ .idx = .button, .c = theme.equals });
        zgui.pushStyleColor4f(.{ .idx = .button_hovered, .c = theme.equals_hover });
        zgui.pushStyleColor4f(.{ .idx = .button_active, .c = theme.equals_active });
        defer zgui.popStyleColor(.{ .count = 3 });
        if (buttonAt("=", 3, w, h)) e.equals();
    }
}

pub fn drawStandard(app: *App) void {
    const e = &app.engine;

    // Stretch the 5x6 grid to fill the available content region like a
    // real calculator, with a sensible minimum for tiny windows.
    const cols = 5;
    const rows = 6;
    const avail = zgui.getContentRegionAvail();
    const spacing = zgui.getStyle().item_spacing;
    const w = @max(40.0, (avail[0] - spacing[0] * (cols - 1)) / cols);
    const h = @max(28.0, (avail[1] - spacing[1] * (rows - 1)) / rows);

    if (buttonAt("MC", 0, w, h)) e.mc();
    if (buttonAt("MR", 1, w, h)) e.mr();
    if (buttonAt("MS", 2, w, h)) e.ms();
    if (buttonAt("M+", 3, w, h)) e.mPlus();
    if (buttonAt("Back", 4, w, h)) e.backspace();

    if (buttonAt("CE", 0, w, h)) e.clearEntry();
    if (buttonAt("C", 1, w, h)) e.clearAll();
    if (buttonAt("+/-", 2, w, h)) e.negate();
    if (buttonAt("sqrt", 3, w, h)) e.unaryOp(.sqrt);
    if (opButtonAt("%", 4, w, h, false)) e.percent();

    digitButton(app, "7", 7, 0, w, h);
    digitButton(app, "8", 8, 1, w, h);
    digitButton(app, "9", 9, 2, w, h);
    if (opButtonAt("/", 3, w, h, e.pending == .div)) e.binaryOp(.div);
    if (buttonAt("1/x", 4, w, h)) e.unaryOp(.recip);

    digitButton(app, "4", 4, 0, w, h);
    digitButton(app, "5", 5, 1, w, h);
    digitButton(app, "6", 6, 2, w, h);
    if (opButtonAt("*", 3, w, h, e.pending == .mul)) e.binaryOp(.mul);
    if (buttonAt("x^2", 4, w, h)) e.unaryOp(.x2);

    digitButton(app, "1", 1, 0, w, h);
    digitButton(app, "2", 2, 1, w, h);
    digitButton(app, "3", 3, 2, w, h);
    if (opButtonAt("-", 3, w, h, e.pending == .sub)) e.binaryOp(.sub);
    if (opButtonAt("^", 4, w, h, e.pending == .pow)) e.binaryOp(.pow);

    // Double-wide zero spans two columns plus the spacing between them.
    if (buttonAt("0", 0, w * 2 + spacing[0], h)) e.digit(0);
    if (buttonAt(".", 2, w, h)) e.dot();
    if (opButtonAt("+", 3, w, h, e.pending == .add)) e.binaryOp(.add);
    if (opButtonAt("=", 4, w, h, false)) e.equals();
}

fn baseButton(app: *App, label: [:0]const u8, base: engine_mod.Base, col: usize) void {
    const e = &app.engine;
    if (col > 0) zgui.sameLine(.{});
    const active = e.base == base;
    if (active) zgui.pushStyleColor4f(.{ .idx = .button, .c = theme.accent });
    if (zgui.button(label, .{ .w = 52, .h = 30 })) e.setBase(base);
    if (active) zgui.popStyleColor(.{});
}

fn angleButton(app: *App, label: [:0]const u8, unit: engine_mod.AngleUnit, col: usize) void {
    const e = &app.engine;
    if (col > 0) zgui.sameLine(.{});
    const active = e.angle == unit;
    if (active) zgui.pushStyleColor4f(.{ .idx = .button, .c = theme.accent });
    if (zgui.button(label, .{ .w = 52, .h = 30 })) e.setAngleUnit(unit);
    if (active) zgui.popStyleColor(.{});
}

fn fnButton(app: *App, label: [:0]const u8, op: engine_mod.UnaryOp) void {
    if (zgui.button(label, .{ .w = -1, .h = bh })) app.engine.unaryOp(op);
}

pub fn drawScientific(app: *App) void {
    const e = &app.engine;

    // Base + angle selectors, Inv/Hyp toggles.
    baseButton(app, "Hex", .hex, 0);
    baseButton(app, "Dec", .dec, 1);
    baseButton(app, "Oct", .oct, 2);
    baseButton(app, "Bin", .bin, 3);
    zgui.sameLine(.{});
    _ = zgui.checkbox("Inv", .{ .v = &e.inv });
    zgui.sameLine(.{});
    _ = zgui.checkbox("Hyp", .{ .v = &e.hyp });

    angleButton(app, "Deg", .deg, 0);
    angleButton(app, "Rad", .rad, 1);
    angleButton(app, "Grad", .grad, 2);
    zgui.sameLine(.{});
    _ = zgui.checkbox("F-E", .{ .v = &e.fe });
    zgui.sameLine(.{});
    _ = zgui.checkbox("dms", .{ .v = &e.dms_mode });
    zgui.separator();

    // Hex digits (enabled only in hex mode).
    const hex_labels = [_][:0]const u8{ "A", "B", "C", "D", "E", "F" };
    for (hex_labels, 0..) |label, i| {
        if (i > 0) zgui.sameLine(.{});
        if (e.base == .hex) {
            if (zgui.button(label, .{ .w = bw - 8, .h = bh * 0.7 })) e.digit(@intCast(10 + i));
        } else {
            zgui.textDisabled("{s}", .{label});
        }
    }
    zgui.separator();

    // Function rail + standard grid side by side.
    if (zgui.beginChild("fn_rail", .{ .w = 150, .h = 0, .child_flags = .{ .border = true } })) {
        fnButton(app, "sin", .sin);
        fnButton(app, "cos", .cos);
        fnButton(app, "tan", .tan);
        fnButton(app, "ln", .ln);
        fnButton(app, "log", .log);
        fnButton(app, "exp", .exp);
        fnButton(app, "x^3", .x3);
        fnButton(app, "n!", .fact);
        fnButton(app, "Int", .int);
        if (zgui.button("Mod", .{ .w = -1, .h = bh })) e.binaryOp(.mod);
        if (zgui.button("And", .{ .w = -1, .h = bh })) e.binaryOp(.bw_and);
        if (zgui.button("Or", .{ .w = -1, .h = bh })) e.binaryOp(.bw_or);
        if (zgui.button("Xor", .{ .w = -1, .h = bh })) e.binaryOp(.bw_xor);
        if (zgui.button("Not", .{ .w = -1, .h = bh })) e.unaryOp(.bw_not);
        if (zgui.button("Lsh", .{ .w = -1, .h = bh })) e.binaryOp(.lsh);
        if (zgui.button("pi", .{ .w = -1, .h = bh })) e.loadConstant(std.math.pi);
        if (zgui.button("e", .{ .w = -1, .h = bh })) e.loadConstant(std.math.e);
        if (zgui.button("Sta", .{ .w = -1, .h = bh })) app.show_stats = true;
    }
    zgui.endChild();
    zgui.sameLine(.{});
    if (zgui.beginChild("std_grid", .{ .w = 0, .h = 0 })) {
        drawStandard(app);
    }
    zgui.endChild();
}
