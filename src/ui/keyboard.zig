const std = @import("std");
const zgui = @import("zgui");
const app_mod = @import("app.zig");
const engine_mod = @import("../core/engine.zig");

pub const Special = enum { enter, escape, backspace, delete, f2, f3, f4, f5, f6, f7, f8, f9 };
pub const Event = union(enum) {
    char: u8,
    key: Special,
    copy,
    paste,
};

var queue: std.ArrayList(Event) = .empty;
var gpa: std.mem.Allocator = undefined;

pub fn initQueue(allocator: std.mem.Allocator) void {
    gpa = allocator;
}

pub fn deinitQueue() void {
    queue.deinit(gpa);
}

pub fn push(ev: Event) void {
    queue.append(gpa, ev) catch {};
}

/// Apply queued input to the engine. Events are dropped while a text field
/// wants the keyboard so graph input fields are not disturbed.
pub fn handle(app: *app_mod.App) void {
    defer queue.clearRetainingCapacity();
    if (queue.items.len == 0) return;
    // zgui io flag: ImGuiIO.WantCaptureKeyboard.
    if (zgui.io.getWantCaptureKeyboard()) return;

    const e = &app.engine;
    for (queue.items) |ev| {
        switch (ev) {
            .copy => app.copyDisplay(),
            .paste => app.pasteClipboard(),
            .key => |k| switch (k) {
                .enter => e.equals(),
                .escape => e.clearAll(),
                .backspace => e.backspace(),
                .delete => e.clearEntry(),
                .f2 => e.setAngleUnit(.deg),
                .f3 => e.setAngleUnit(.rad),
                .f4 => e.setAngleUnit(.grad),
                .f5 => e.setBase(.hex),
                .f6 => e.setBase(.dec),
                .f7 => e.setBase(.oct),
                .f8 => e.setBase(.bin),
                .f9 => e.negate(),
            },
            .char => |c| handleChar(e, c),
        }
    }
}

fn handleChar(e: *engine_mod.Engine, c: u8) void {
    switch (c) {
        '0'...'9' => e.digit(c - '0'),
        'a'...'f' => {
            // In hex mode these are digits; otherwise 'c' stays the cos shortcut.
            if (e.base == .hex) {
                e.digit(c - 'a' + 10);
            } else if (c == 'c' and e.mode == .scientific) {
                e.unaryOp(.cos);
            }
        },
        'A'...'F' => if (e.base == .hex) e.digit(c - 'A' + 10),
        '.', ',' => e.dot(),
        '+' => e.binaryOp(.add),
        '-' => e.binaryOp(.sub),
        '/' => e.binaryOp(.div),
        '*' => {
            // "**" chord: a second * while multiply is pending upgrades to power.
            if (e.pending == .mul and e.fresh) {
                e.pending = .pow;
            } else {
                e.binaryOp(.mul);
            }
        },
        '^' => e.binaryOp(.pow),
        '%' => e.percent(),
        '=' => e.equals(),
        '(' => e.openParen(),
        ')' => e.closeParen(),
        '!' => if (e.mode == .scientific) e.unaryOp(.fact),
        '@' => if (e.mode == .scientific) e.unaryOp(.x2),
        '#' => if (e.mode == .scientific) e.unaryOp(.x3),
        'r' => if (e.mode == .scientific) e.unaryOp(.sqrt),
        's' => if (e.mode == .scientific) e.unaryOp(.sin),
        't' => if (e.mode == .scientific) e.unaryOp(.tan),
        'l' => if (e.mode == .scientific) e.unaryOp(.ln),
        'n' => if (e.mode == .scientific) e.unaryOp(.log),
        'p' => if (e.mode == .scientific) e.loadConstant(std.math.pi),
        'i' => {
            if (e.mode == .scientific) e.inv = !e.inv;
        },
        'h' => {
            if (e.mode == .scientific) e.hyp = !e.hyp;
        },
        'm' => {
            if (e.mode == .scientific) e.dms_mode = !e.dms_mode;
        },
        'v' => {
            if (e.mode == .scientific) e.fe = !e.fe;
        },
        else => {},
    }
}
