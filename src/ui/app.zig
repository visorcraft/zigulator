const std = @import("std");
const zgui = @import("zgui");
const engine_mod = @import("../core/engine.zig");
const history_mod = @import("../core/history.zig");
const stats_mod = @import("../core/stats.zig");
const i18n = @import("../core/i18n.zig");
const prefs_mod = @import("../core/prefs.zig");
const display = @import("display.zig");
const keypad = @import("keypad.zig");
const history_panel = @import("history_panel.zig");
const graph_window = @import("graph_window.zig");
const stats_window = @import("stats_window.zig");
const keyboard = @import("keyboard.zig");
const theme = @import("theme.zig");

pub const App = struct {
    allocator: std.mem.Allocator,
    history: history_mod.History,
    stats: stats_mod.Stats,
    graph: graph_window.State,
    engine: engine_mod.Engine,
    lang: i18n.Lang = .en,
    show_history: bool = false,
    show_graph: bool = false,
    show_stats: bool = false,
    show_about: bool = false,
    quit: bool = false,
    /// Monospace font for the readout; null keeps the scaled default font.
    display_font: ?zgui.Font = null,

    pub fn init(allocator: std.mem.Allocator) App {
        // NOTE: `engine` is left undefined here on purpose - Engine.init
        // stores a pointer to `history`, so it must be initialized only
        // after the App value is at its final address (see main.zig).
        return .{
            .allocator = allocator,
            .history = history_mod.History.init(allocator),
            .stats = stats_mod.Stats.init(allocator),
            .graph = graph_window.State.init(allocator),
            .engine = undefined,
        };
    }

    pub fn deinit(self: *App) void {
        self.savePrefs();
        self.engine.deinit();
        self.stats.deinit();
        self.graph.deinit();
        self.history.deinit();
    }

    pub fn loadPrefs(self: *App) void {
        const p = prefs_mod.load();
        self.lang = p.lang;
        self.engine.decimal_sep = p.decimal_sep;
        self.engine.setMode(p.mode);
    }

    pub fn savePrefs(self: *const App) void {
        prefs_mod.save(.{
            .mode = self.engine.mode,
            .lang = self.lang,
            .decimal_sep = self.engine.decimal_sep,
        });
    }

    pub fn t(self: *const App, key: i18n.Key) [:0]const u8 {
        return i18n.tr(self.lang, key);
    }

    pub fn copyDisplay(self: *App) void {
        var buf: [128]u8 = undefined;
        // Ungrouped canonical text so copy→paste round-trips through the parser.
        const s = self.engine.copyText(&buf);
        var zbuf: [160]u8 = undefined;
        const z = std.fmt.bufPrintZ(&zbuf, "{s}", .{s}) catch return;
        zgui.setClipboardText(z);
    }

    pub fn pasteClipboard(self: *App) void {
        // zgui.getClipboardText() returns [:0]const u8 (non-optional).
        const text = zgui.getClipboardText();
        if (text.len == 0) return;
        self.engine.paste(text);
    }

    pub fn frame(self: *App) void {
        keyboard.handle(self);
        // Full-viewport dockspace so history/graph/stats can dock next to
        // the calculator. This zgui exposes no defaults on the wrapper.
        // Passthru central node: the dockspace background stays transparent in
        // the center so the full-window calculator (no_docking) shows through,
        // while panels can still dock at the edges.
        _ = zgui.dockSpaceOverViewport(0, zgui.getMainViewport(), .{ .passthru_central_node = true });
        self.drawMenuBar();
        self.drawMainWindow();
        if (self.show_history) history_panel.draw(self);
        if (self.show_graph) graph_window.draw(self);
        if (self.show_stats) stats_window.draw(self);
        self.drawAbout();
    }

    fn drawMenuBar(self: *App) void {
        if (!zgui.beginMainMenuBar()) return;
        defer zgui.endMainMenuBar();

        if (zgui.beginMenu(self.t(.menu_file), true)) {
            defer zgui.endMenu();
            if (zgui.menuItem(self.t(.exit), .{})) self.quit = true;
        }
        if (zgui.beginMenu(self.t(.menu_edit), true)) {
            defer zgui.endMenu();
            if (zgui.menuItem(self.t(.copy), .{})) self.copyDisplay();
            if (zgui.menuItem(self.t(.paste), .{})) self.pasteClipboard();
        }
        if (zgui.beginMenu(self.t(.menu_view), true)) {
            defer zgui.endMenu();
            if (zgui.menuItem(self.t(.simple), .{ .selected = self.engine.mode == .simple }))
                self.setMode(.simple);
            if (zgui.menuItem(self.t(.standard), .{ .selected = self.engine.mode == .standard }))
                self.setMode(.standard);
            if (zgui.menuItem(self.t(.scientific), .{ .selected = self.engine.mode == .scientific }))
                self.setMode(.scientific);
            zgui.separator();
            if (zgui.menuItem(self.t(.history), .{ .selected = self.show_history }))
                self.show_history = !self.show_history;
            if (zgui.menuItem(self.t(.graph), .{ .selected = self.show_graph }))
                self.show_graph = !self.show_graph;
            if (zgui.menuItem(self.t(.statistics), .{ .selected = self.show_stats }))
                self.show_stats = !self.show_stats;
            zgui.separator();
            if (zgui.beginMenu(self.t(.language), true)) {
                defer zgui.endMenu();
                if (zgui.menuItem("English", .{ .selected = self.lang == .en }))
                    self.setLang(.en);
                if (zgui.menuItem("Português (BR)", .{ .selected = self.lang == .pt_br }))
                    self.setLang(.pt_br);
            }
            if (zgui.beginMenu(self.t(.decimal_sep), true)) {
                defer zgui.endMenu();
                if (zgui.menuItem(".", .{ .selected = self.engine.decimal_sep == '.' }))
                    self.setDecimalSep('.');
                if (zgui.menuItem(",", .{ .selected = self.engine.decimal_sep == ',' }))
                    self.setDecimalSep(',');
            }
        }
        if (zgui.beginMenu(self.t(.menu_help), true)) {
            defer zgui.endMenu();
            if (zgui.menuItem(self.t(.about), .{})) self.show_about = true;
        }
    }

    fn setMode(self: *App, mode: engine_mod.Mode) void {
        if (self.engine.mode == mode) return;
        self.engine.setMode(mode);
        self.savePrefs();
    }

    fn setLang(self: *App, lang: i18n.Lang) void {
        if (self.lang == lang) return;
        self.lang = lang;
        self.savePrefs();
    }

    fn setDecimalSep(self: *App, sep: u8) void {
        if (self.engine.decimal_sep == sep) return;
        self.engine.decimal_sep = sep;
        self.savePrefs();
    }

    fn drawMainWindow(self: *App) void {
        // The calculator IS the window: fill the viewport work area (the
        // region below the main menu bar) every frame and pin it in place.
        const viewport = zgui.getMainViewport();
        const work_pos = viewport.getWorkPos();
        const work_size = viewport.getWorkSize();
        zgui.setNextWindowPos(.{ .x = work_pos[0], .y = work_pos[1], .cond = .always });
        zgui.setNextWindowSize(.{ .w = work_size[0], .h = work_size[1], .cond = .always });
        if (zgui.begin(self.t(.app_title), .{ .flags = .{
            .no_title_bar = true,
            .no_resize = true,
            .no_move = true,
            .no_collapse = true,
            .no_docking = true,
            .no_saved_settings = true,
            .no_bring_to_front_on_focus = true,
        } })) {
            display.draw(self);
            switch (self.engine.mode) {
                .simple => keypad.drawSimple(self),
                .standard => keypad.drawStandard(self),
                .scientific => keypad.drawScientific(self),
            }
        }
        zgui.end();
    }

    fn drawAbout(self: *App) void {
        // Plain window (not PopupModal): OpenPopup + BeginPopupModal ID matching
        // is fragile with ### labels and ID stacks; a regular window always works.
        if (!self.show_about) return;

        const center = zgui.getMainViewport().getWorkCenter();
        zgui.setNextWindowPos(.{
            .x = center[0],
            .y = center[1],
            .pivot_x = 0.5,
            .pivot_y = 0.5,
            .cond = .appearing,
        });
        zgui.setNextWindowSize(.{ .w = 420, .h = 0, .cond = .appearing });
        zgui.setNextWindowFocus();

        // Stable id so language switches don't recreate the window.
        var title_buf: [64]u8 = undefined;
        const title = std.fmt.bufPrintZ(&title_buf, "{s}###about", .{self.t(.about)}) catch "About###about";

        if (!zgui.begin(title, .{
            .popen = &self.show_about,
            .flags = .{
                .always_auto_resize = true,
                .no_resize = true,
                .no_collapse = true,
                .no_docking = true,
                .no_saved_settings = true,
            },
        })) {
            zgui.end();
            return;
        }
        defer zgui.end();

        const pad: f32 = 8.0;
        zgui.dummy(.{ .w = 0, .h = pad });

        // App name, centered, accent-colored.
        // Measure after pushFont so width matches the rendered size.
        {
            const name = self.t(.app_title);
            if (self.display_font) |font| zgui.pushFont(font, 22.0);
            const name_sz = zgui.calcTextSize(name, .{});
            const avail = zgui.getContentRegionAvail();
            if (avail[0] > name_sz[0])
                zgui.setCursorPosX(zgui.getCursorPosX() + (avail[0] - name_sz[0]) * 0.5);
            zgui.pushStyleColor4f(.{ .idx = .text, .c = theme.accent });
            zgui.textUnformatted(name);
            zgui.popStyleColor(.{});
            if (self.display_font != null) zgui.popFont();
        }

        zgui.dummy(.{ .w = 0, .h = 6.0 });

        // Description, soft secondary text, wrapped.
        zgui.pushStyleColor4f(.{ .idx = .text, .c = .{ 0.72, 0.73, 0.76, 1.0 } });
        zgui.pushTextWrapPos(zgui.getCursorPosX() + 380);
        zgui.textWrapped("{s}", .{self.t(.about_text)});
        zgui.popTextWrapPos();
        zgui.popStyleColor(.{});

        zgui.dummy(.{ .w = 0, .h = 12.0 });
        zgui.separator();
        zgui.dummy(.{ .w = 0, .h = 10.0 });

        // Accent Close button, right-aligned.
        const btn_w: f32 = 120.0;
        const btn_h: f32 = 34.0;
        const avail = zgui.getContentRegionAvail();
        if (avail[0] > btn_w)
            zgui.setCursorPosX(zgui.getCursorPosX() + avail[0] - btn_w);
        zgui.pushStyleColor4f(.{ .idx = .button, .c = theme.accent });
        zgui.pushStyleColor4f(.{ .idx = .button_hovered, .c = theme.accent_hover });
        zgui.pushStyleColor4f(.{ .idx = .button_active, .c = theme.accent_active });
        zgui.pushStyleColor4f(.{ .idx = .text, .c = .{ 1, 1, 1, 1 } });
        if (zgui.button(self.t(.close), .{ .w = btn_w, .h = btn_h }))
            self.show_about = false;
        zgui.popStyleColor(.{ .count = 4 });

        zgui.dummy(.{ .w = 0, .h = pad });
    }
};
