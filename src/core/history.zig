const std = @import("std");

pub const Entry = struct {
    expression: []u8,
    result: f64,
};

pub const History = struct {
    allocator: std.mem.Allocator,
    items: std.ArrayList(Entry),

    pub fn init(allocator: std.mem.Allocator) History {
        return .{ .allocator = allocator, .items = .empty };
    }

    pub fn deinit(self: *History) void {
        self.clear();
        self.items.deinit(self.allocator);
    }

    pub fn add(self: *History, expression: []const u8, result: f64) !void {
        const copy = try self.allocator.dupe(u8, expression);
        errdefer self.allocator.free(copy);
        try self.items.append(self.allocator, .{ .expression = copy, .result = result });
    }

    pub fn clear(self: *History) void {
        for (self.items.items) |e| self.allocator.free(e.expression);
        self.items.clearRetainingCapacity();
    }
};

test "history add, ownership, clear" {
    var h = History.init(std.testing.allocator);
    defer h.deinit();
    try h.add("2 + 3", 5);
    try h.add("4 * 5", 20);
    try std.testing.expectEqual(@as(usize, 2), h.items.items.len);
    try std.testing.expectEqualStrings("2 + 3", h.items.items[0].expression);
    try std.testing.expectEqual(@as(f64, 20), h.items.items[1].result);
    h.clear();
    try std.testing.expectEqual(@as(usize, 0), h.items.items.len);
    try h.add("1", 1); // still usable after clear
    try std.testing.expectEqual(@as(usize, 1), h.items.items.len);
}
