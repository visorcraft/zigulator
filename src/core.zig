// Re-exports of the GUI-independent calculator core.
// Tests live in the individual core files; the block below pulls them in.

test {
    _ = @import("core/format.zig");
    _ = @import("core/parser.zig");
    _ = @import("core/history.zig");
    _ = @import("core/stats.zig");
    _ = @import("core/engine.zig");
    _ = @import("core/i18n.zig");
    _ = @import("core/prefs.zig");
}
