const zgui = @import("zgui");

pub const accent = [4]f32{ 0.231, 0.612, 1.0, 1.0 }; // #3B9CFF
pub const accent_hover = [4]f32{ 0.35, 0.69, 1.0, 1.0 };
pub const accent_active = [4]f32{ 0.15, 0.5, 0.9, 1.0 };

/// Coral label for Simple-mode C (clear).
pub const danger_text = [4]f32{ 0.91, 0.47, 0.47, 1.0 }; // #E87878
/// Teal fill for Simple-mode =.
pub const equals = [4]f32{ 0.0, 0.55, 0.51, 1.0 }; // #008C82
pub const equals_hover = [4]f32{ 0.05, 0.65, 0.60, 1.0 };
pub const equals_active = [4]f32{ 0.0, 0.45, 0.42, 1.0 };

const bg = [4]f32{ 0.10, 0.10, 0.12, 1.0 }; // app chrome
const surface = [4]f32{ 0.14, 0.14, 0.17, 1.0 }; // panels / menu bar
const surface_raised = [4]f32{ 0.17, 0.17, 0.21, 1.0 }; // popups
const hover = [4]f32{ 0.24, 0.26, 0.32, 1.0 };
const active = [4]f32{ 0.18, 0.32, 0.48, 1.0 }; // selected row (soft accent wash)
const border = [4]f32{ 1.0, 1.0, 1.0, 0.08 };
const text = [4]f32{ 0.93, 0.93, 0.95, 1.0 };
const text_dim = [4]f32{ 0.55, 0.56, 0.60, 1.0 };

/// Modern dark theme - full palette so menus don't fall back to Classic Blue.
pub fn apply() void {
    const style = zgui.getStyle();

    // Geometry: soft, contemporary chrome (not Win95 hard corners).
    style.window_rounding = 10.0;
    style.child_rounding = 8.0;
    style.popup_rounding = 10.0;
    style.frame_rounding = 8.0;
    style.scrollbar_rounding = 8.0;
    style.grab_rounding = 6.0;
    style.tab_rounding = 6.0;

    style.window_border_size = 0.0;
    style.child_border_size = 0.0;
    style.popup_border_size = 1.0;
    style.frame_border_size = 0.0;

    style.window_padding = .{ 12.0, 10.0 };
    style.frame_padding = .{ 10.0, 7.0 };
    style.item_spacing = .{ 10.0, 7.0 };
    style.item_inner_spacing = .{ 8.0, 5.0 };
    style.cell_padding = .{ 6.0, 4.0 };
    style.indent_spacing = 16.0;
    style.scrollbar_size = 12.0;
    style.grab_min_size = 10.0;

    // Surfaces
    style.setColor(.window_bg, bg);
    style.setColor(.child_bg, bg);
    style.setColor(.popup_bg, surface_raised);
    style.setColor(.menu_bar_bg, surface);
    style.setColor(.title_bg, surface);
    style.setColor(.title_bg_active, surface);
    style.setColor(.title_bg_collapsed, surface);
    style.setColor(.border, border);
    style.setColor(.border_shadow, .{ 0, 0, 0, 0 });

    // Text
    style.setColor(.text, text);
    style.setColor(.text_disabled, text_dim);
    style.setColor(.text_selected_bg, .{ accent[0], accent[1], accent[2], 0.35 });
    style.setColor(.text_link, accent);

    // Frames / inputs
    style.setColor(.frame_bg, .{ 0.16, 0.16, 0.20, 1.0 });
    style.setColor(.frame_bg_hovered, hover);
    style.setColor(.frame_bg_active, .{ 0.22, 0.24, 0.30, 1.0 });

    // Buttons
    style.setColor(.button, .{ 0.20, 0.21, 0.25, 1.0 });
    style.setColor(.button_hovered, hover);
    style.setColor(.button_active, .{ 0.32, 0.35, 0.42, 1.0 });

    // Headers = menu items, collapsibles, selectable rows
    style.setColor(.header, .{ 0, 0, 0, 0 }); // idle: transparent
    style.setColor(.header_hovered, hover);
    style.setColor(.header_active, active);

    // Checkmarks / sliders use accent (not classic ImGui blue)
    style.setColor(.check_mark, accent);
    style.setColor(.slider_grab, accent);
    style.setColor(.slider_grab_active, accent_hover);

    // Separators
    style.setColor(.separator, border);
    style.setColor(.separator_hovered, .{ accent[0], accent[1], accent[2], 0.5 });
    style.setColor(.separator_active, accent);

    // Scrollbars
    style.setColor(.scrollbar_bg, .{ 0, 0, 0, 0 });
    style.setColor(.scrollbar_grab, .{ 0.35, 0.36, 0.40, 1.0 });
    style.setColor(.scrollbar_grab_hovered, .{ 0.45, 0.46, 0.50, 1.0 });
    style.setColor(.scrollbar_grab_active, .{ 0.55, 0.56, 0.60, 1.0 });

    // Tabs / docking
    style.setColor(.tab, surface);
    style.setColor(.tab_hovered, hover);
    style.setColor(.tab_selected, bg);
    style.setColor(.tab_selected_overline, accent);
    style.setColor(.tab_dimmed, surface);
    style.setColor(.tab_dimmed_selected, bg);
    style.setColor(.docking_preview, .{ accent[0], accent[1], accent[2], 0.35 });
    style.setColor(.docking_empty_bg, bg);

    // Tables
    style.setColor(.table_header_bg, surface);
    style.setColor(.table_border_strong, border);
    style.setColor(.table_border_light, .{ 1, 1, 1, 0.04 });
    style.setColor(.table_row_bg, .{ 0, 0, 0, 0 });
    style.setColor(.table_row_bg_alt, .{ 1, 1, 1, 0.02 });

    // Resize / nav
    style.setColor(.resize_grip, .{ 1, 1, 1, 0.10 });
    style.setColor(.resize_grip_hovered, .{ accent[0], accent[1], accent[2], 0.5 });
    style.setColor(.resize_grip_active, accent);
    style.setColor(.nav_cursor, accent);
    style.setColor(.nav_windowing_highlight, .{ 1, 1, 1, 0.15 });
    style.setColor(.nav_windowing_dim_bg, .{ 0, 0, 0, 0.45 });
    style.setColor(.modal_window_dim_bg, .{ 0, 0, 0, 0.55 });
    style.setColor(.drag_drop_target, accent);
    style.setColor(.plot_lines, accent);
    style.setColor(.plot_lines_hovered, accent_hover);
    style.setColor(.plot_histogram, accent);
    style.setColor(.plot_histogram_hovered, accent_hover);
}
