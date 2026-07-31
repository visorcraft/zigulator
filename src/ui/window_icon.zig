const glfw = @import("zglfw");

// Pre-baked RGBA pixels (from logo.png) for glfwSetWindowIcon on X11.
// Wayland ignores this and uses the desktop-file / app_id icon instead.
const icon_16 = @embedFile("../assets/icon_16.rgba");
const icon_32 = @embedFile("../assets/icon_32.rgba");
const icon_48 = @embedFile("../assets/icon_48.rgba");
const icon_64 = @embedFile("../assets/icon_64.rgba");
const icon_128 = @embedFile("../assets/icon_128.rgba");

/// App id / desktop-file base name. Must match packaging/zigulator.desktop
/// and the FreeDesktop icon name for Wayland/taskbar integration.
pub const app_id = "zigulator";

pub fn apply(window: *glfw.Window) void {
    // GLFW copies pixel data before return; cast away const for the API.
    var images = [_]glfw.Image{
        .{ .width = 16, .height = 16, .pixels = @constCast(icon_16.ptr) },
        .{ .width = 32, .height = 32, .pixels = @constCast(icon_32.ptr) },
        .{ .width = 48, .height = 48, .pixels = @constCast(icon_48.ptr) },
        .{ .width = 64, .height = 64, .pixels = @constCast(icon_64.ptr) },
        .{ .width = 128, .height = 128, .pixels = @constCast(icon_128.ptr) },
    };
    window.setIcon(&images);
}
