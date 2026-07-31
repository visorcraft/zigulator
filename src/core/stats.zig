const std = @import("std");

pub const Stats = struct {
    allocator: std.mem.Allocator,
    data: std.ArrayList(f64),

    pub fn init(allocator: std.mem.Allocator) Stats {
        return .{ .allocator = allocator, .data = .empty };
    }

    pub fn deinit(self: *Stats) void {
        self.data.deinit(self.allocator);
    }

    pub fn add(self: *Stats, v: f64) !void {
        try self.data.append(self.allocator, v);
    }

    pub fn removeAt(self: *Stats, index: usize) void {
        _ = self.data.orderedRemove(index);
    }

    pub fn clear(self: *Stats) void {
        self.data.clearRetainingCapacity();
    }

    pub fn count(self: *const Stats) usize {
        return self.data.items.len;
    }

    pub fn sum(self: *const Stats) f64 {
        var s: f64 = 0;
        for (self.data.items) |v| s += v;
        return s;
    }

    pub fn mean(self: *const Stats) ?f64 {
        if (self.data.items.len == 0) return null;
        return self.sum() / @as(f64, @floatFromInt(self.data.items.len));
    }

    /// Sample standard deviation (n-1 denominator), like the Win95 `s` button.
    pub fn stddevSample(self: *const Stats) ?f64 {
        const n = self.data.items.len;
        if (n < 2) return null;
        const m = self.mean().?;
        var acc: f64 = 0;
        for (self.data.items) |v| acc += (v - m) * (v - m);
        return @sqrt(acc / @as(f64, @floatFromInt(n - 1)));
    }
};

test "stats aggregations" {
    var st = Stats.init(std.testing.allocator);
    defer st.deinit();
    try std.testing.expectEqual(@as(?f64, null), st.mean());
    try std.testing.expectEqual(@as(?f64, null), st.stddevSample());
    try st.add(2);
    try st.add(4);
    try st.add(6);
    try std.testing.expectEqual(@as(usize, 3), st.count());
    try std.testing.expectEqual(@as(f64, 12), st.sum());
    try std.testing.expectEqual(@as(f64, 4), st.mean().?);
    try std.testing.expectApproxEqAbs(@as(f64, 2), st.stddevSample().?, 1e-12);
    st.removeAt(0);
    try std.testing.expectEqual(@as(usize, 2), st.count());
    try std.testing.expectEqual(@as(f64, 5), st.mean().?);
    st.clear();
    try std.testing.expectEqual(@as(usize, 0), st.count());
}
