const std = @import("std");
const zgui = @import("zgui");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const theme = @import("ui/theme.zig");
const app_mod = @import("ui/app.zig");
const engine_mod = @import("core/engine.zig");
const keyboard = @import("ui/keyboard.zig");
const window_icon = @import("ui/window_icon.zig");

fn charCallback(window: *glfw.Window, codepoint: u32) callconv(.c) void {
    _ = window;
    if (codepoint < 128) keyboard.push(.{ .char = @intCast(codepoint) });
}

fn keyCallback(window: *glfw.Window, key: glfw.Key, scancode: c_int, action: glfw.Action, mods: glfw.Mods) callconv(.c) void {
    _ = window;
    _ = scancode;
    if (action != .press and action != .repeat) return;
    if (mods.control) {
        switch (key) {
            .c => keyboard.push(.copy),
            .v => keyboard.push(.paste),
            else => {},
        }
        return;
    }
    const special: ?keyboard.Special = switch (key) {
        .enter, .kp_enter => .enter,
        .escape => .escape,
        .backspace => .backspace,
        .delete => .delete,
        .F2 => .f2,
        .F3 => .f3,
        .F4 => .f4,
        .F5 => .f5,
        .F6 => .f6,
        .F7 => .f7,
        .F8 => .f8,
        .F9 => .f9,
        else => null,
    };
    if (special) |s| keyboard.push(.{ .key = s });
}

fn fontFileExists(path: [:0]const u8) bool {
    // std.fs is gutted in 0.16; raw openat is the lightest existence probe.
    const fd = std.posix.openat(std.posix.AT.FDCWD, path, .{}, 0) catch return false;
    _ = std.os.linux.close(fd); // std.posix.close was removed in 0.16
    return true;
}

fn loadFirstFont(candidates: []const [:0]const u8, size: f32) ?zgui.Font {
    for (candidates) |path| {
        if (!fontFileExists(path)) continue;
        return zgui.io.addFontFromFile(path, size);
    }
    return null;
}

/// Modern UI sans for menus/labels - never ProggyClean if we can help it.
fn loadUiFont() zgui.Font {
    // Prefer Inter when present; otherwise Noto/DejaVu (widely packaged).
    const system = [_][:0]const u8{
        "/usr/share/fonts/inter/Inter-Regular.ttf",
        "/usr/share/fonts/truetype/inter/Inter-Regular.ttf",
        "/usr/share/fonts/opentype/inter/Inter-Regular.ttf",
        "/usr/share/fonts/noto/NotoSans-Regular.ttf",
        "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf",
        "/usr/share/fonts/TTF/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/liberation/LiberationSans-Regular.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    };
    if (loadFirstFont(&system, 17.0)) |f| return f;

    // User-local install (e.g. ~/.local/share/fonts/.../Inter-Regular.ttf).
    if (std.c.getenv("HOME")) |home| {
        const home_s = std.mem.span(home);
        const suffixes = [_][]const u8{
            "/.local/share/fonts/Inter-Regular.ttf",
            "/.local/share/fonts/inter/Inter-Regular.ttf",
            "/.local/share/fonts/inter-tmp/Inter-Regular.ttf",
            "/.fonts/Inter-Regular.ttf",
        };
        for (suffixes) |suf| {
            var buf: [512]u8 = undefined;
            const path = std.fmt.bufPrintZ(&buf, "{s}{s}", .{ home_s, suf }) catch continue;
            if (!fontFileExists(path)) continue;
            return zgui.io.addFontFromFile(path, 17.0);
        }
    }

    // Last resort: ImGui's built-in ProggyClean (the 1990s look).
    return zgui.io.addFontDefault(null);
}

/// Monospace font for the calculator readout.
fn loadDisplayFont() ?zgui.Font {
    const candidates = [_][:0]const u8{
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/TTF/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
        "/usr/share/fonts/liberation/LiberationMono-Regular.ttf",
        "/usr/share/fonts/noto/NotoSansMono-Regular.ttf",
    };
    return loadFirstFont(&candidates, 28.0);
}

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    glfw.windowHint(.context_version_major, 4);
    glfw.windowHint(.context_version_minor, 0);
    glfw.windowHint(.opengl_profile, .opengl_core_profile);
    glfw.windowHint(.opengl_forward_compat, true);
    // Wayland: compositor looks up the FreeDesktop icon via this app_id
    // (must match packaging/zigulator.desktop basename / Icon= name).
    glfw.windowHint(.wayland_app_id, window_icon.app_id);

    // Debug aid: ZIGULATOR_SHOT=/tmp/frame.ppm renders hidden and dumps frame 10.
    const shot_path: ?[]const u8 = if (std.c.getenv("ZIGULATOR_SHOT")) |p| std.mem.span(p) else null;
    if (shot_path != null) glfw.windowHint(.visible, false);

    const window = try glfw.Window.create(900, 620, "Zigulator", null, null);
    defer window.destroy();
    window_icon.apply(window);

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    try zopengl.loadCoreProfile(glfw.getProcAddress, 4, 0);
    const gl = zopengl.bindings;

    var dbg: std.heap.DebugAllocator(.{}) = .init;
    defer {
        if (dbg.deinit() == .leak)
            std.debug.print("warning: memory leaks detected\n", .{});
    }
    const gpa = dbg.allocator();

    zgui.init(gpa);
    defer zgui.deinit();
    // Enable ImGui docking (zgui ships the 1.92.1-docking branch).
    zgui.io.setConfigFlags(.{ .dock_enable = true });
    // First font loaded becomes the UI default - use a modern sans, not ProggyClean.
    const ui_font = loadUiFont();
    zgui.io.setDefaultFont(ui_font);
    const display_font = loadDisplayFont();

    zgui.plot.init();
    defer zgui.plot.deinit();

    keyboard.initQueue(gpa);
    defer keyboard.deinitQueue();
    // Install before zgui.backend.init so ImGui chains to these callbacks.
    _ = glfw.setCharCallback(window, charCallback);
    _ = glfw.setKeyCallback(window, keyCallback);

    zgui.backend.init(window);
    defer zgui.backend.deinit();

    theme.apply();

    var app = app_mod.App.init(gpa);
    app.engine = engine_mod.Engine.init(gpa, &app.history); // see App.init note
    app.display_font = display_font;
    app.loadPrefs(); // View mode, language, decimal separator
    // Optional shot/demo overrides (used by docs screenshot capture).
    applyShotSetup(&app);
    defer app.deinit();

    while (!window.shouldClose() and !app.quit) {
        glfw.pollEvents();
        gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0.11, 0.11, 0.13, 1.0 });

        const fb = window.getFramebufferSize();
        zgui.backend.newFrame(@intCast(fb[0]), @intCast(fb[1]));

        app.frame();

        zgui.backend.draw();
        window.swapBuffers();

        if (shot_path) |path| {
            frame_count += 1;
            // Extra frames so docked panels (graph/history) finish laying out.
            if (frame_count == 30) {
                try dumpFramePpm(gl, path, @intCast(fb[0]), @intCast(fb[1]));
                return;
            }
        }
    }
}

var frame_count: u32 = 0;

/// Env overrides for screenshot / demo captures. No-ops when unset.
fn applyShotSetup(app: *app_mod.App) void {
    if (std.c.getenv("ZIGULATOR_MODE")) |raw| {
        const mode = std.mem.span(raw);
        if (std.mem.eql(u8, mode, "simple")) app.engine.setMode(.simple);
        if (std.mem.eql(u8, mode, "standard")) app.engine.setMode(.standard);
        if (std.mem.eql(u8, mode, "scientific")) app.engine.setMode(.scientific);
    }
    if (std.c.getenv("ZIGULATOR_SHOW_GRAPH")) |_| app.show_graph = true;
    if (std.c.getenv("ZIGULATOR_SHOW_HISTORY")) |_| app.show_history = true;
    if (std.c.getenv("ZIGULATOR_SHOW_STATS")) |_| app.show_stats = true;
    if (std.c.getenv("ZIGULATOR_SEED")) |raw| {
        const seed = std.mem.span(raw);
        if (seed.len > 0) app.engine.paste(seed);
    }
}

fn dumpFramePpm(gl: anytype, path: []const u8, w: u32, h: u32) !void {
    const n: usize = @intCast(w * h * 3);
    const pixels = try std.heap.page_allocator.alloc(u8, n);
    defer std.heap.page_allocator.free(pixels);
    gl.readPixels(0, 0, @intCast(w), @intCast(h), gl.RGB, gl.UNSIGNED_BYTE, pixels.ptr);

    var path_buf: [512]u8 = undefined;
    const zpath = try std.fmt.bufPrintZ(&path_buf, "{s}", .{path});
    const fd = try std.posix.openat(std.posix.AT.FDCWD, zpath, .{ .ACCMODE = .WRONLY, .CREAT = true, .TRUNC = true }, 0o644);
    defer _ = std.os.linux.close(fd);

    var header_buf: [64]u8 = undefined;
    const header = try std.fmt.bufPrint(&header_buf, "P6\n{d} {d}\n255\n", .{ w, h });
    try writeAll(fd, header);
    // glReadPixels is bottom-up; flip rows.
    const row_bytes: usize = @intCast(w * 3);
    var y: usize = h;
    while (y > 0) {
        y -= 1;
        try writeAll(fd, pixels[y * row_bytes ..][0..row_bytes]);
    }
}

fn writeAll(fd: std.posix.fd_t, bytes: []const u8) !void {
    var off: usize = 0;
    while (off < bytes.len) off += std.os.linux.write(fd, bytes.ptr + off, bytes.len - off);
}
