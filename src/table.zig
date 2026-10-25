const std = @import("std");

const assert = std.debug.assert;

pub const CapacityError = error{EntriesExhausted};
pub const WeightError = error{ WeightsEmpty, WeightsZero };
pub const Error = CapacityError || WeightError;
pub const entry_count_max: u32 = 65536;

pub fn TableType(comptime capacity: u32) type {
    comptime assert(capacity > 0);
    comptime assert(capacity <= entry_count_max);

    return struct {
        entries: [capacity]Entry,
        count: u32,
        total: u64,

        const Table = @This();

        pub const Entry = struct {
            threshold: u64,
            alternate: u32,
        };

        pub const Draw = struct {
            column: u32,
            threshold: u64,
        };

        pub fn init(table: *Table, weights: []const u32) Error!void {
            @setEvalBranchQuota(capacity * 32 + 1024);

            table.count = 0;
            table.total = 0;

            if (weights.len == 0) return error.WeightsEmpty;
            if (weights.len > capacity) return error.EntriesExhausted;

            for (weights) |weight| table.total += weight;

            if (table.total == 0) return error.WeightsZero;

            table.build(weights);
            table.count = @intCast(weights.len);

            assert(table.count > 0);
            assert(table.total <= @as(u64, std.math.maxInt(u32)) * table.count);
        }

        pub fn pick(table: *const Table, draw: Draw) u32 {
            assert(table.count > 0);
            assert(draw.column < table.count);
            assert(draw.threshold < table.total);

            const entry = table.entries[draw.column];
            const result = if (draw.threshold < entry.threshold) draw.column else entry.alternate;

            assert(result < table.count);

            return result;
        }

        pub fn sample(table: *const Table, random: std.Random) u32 {
            assert(table.count > 0);
            assert(table.total > 0);

            return table.pick(.{
                .column = random.uintLessThan(u32, table.count),
                .threshold = random.uintLessThan(u64, table.total),
            });
        }

        fn build(table: *Table, weights: []const u32) void {
            assert(weights.len > 0);
            assert(weights.len <= capacity);

            var scaled: [capacity]u64 = undefined;
            var small: [capacity]u32 = undefined;
            var large: [capacity]u32 = undefined;
            var small_count: u32 = 0;
            var large_count: u32 = 0;

            for (weights, 0..) |weight, index| {
                scaled[index] = @as(u64, weight) * weights.len;
                table.entries[index] = .{ .threshold = table.total, .alternate = @intCast(index) };

                if (scaled[index] < table.total) {
                    small[small_count] = @intCast(index);
                    small_count += 1;
                } else {
                    large[large_count] = @intCast(index);
                    large_count += 1;
                }
            }

            for (0..weights.len) |_| {
                if (small_count == 0) break;
                if (large_count == 0) break;

                small_count -= 1;
                large_count -= 1;

                const under = small[small_count];
                const over = large[large_count];

                table.entries[under] = .{ .threshold = scaled[under], .alternate = over };
                scaled[over] -= table.total - scaled[under];

                if (scaled[over] < table.total) {
                    small[small_count] = over;
                    small_count += 1;
                } else {
                    large[large_count] = over;
                    large_count += 1;
                }
            }

            assert(small_count == 0);
        }
    };
}

test TableType {
    const Table = TableType(3);
    const table = comptime block: {
        var result: Table = undefined;

        result.init(&.{ 1, 0, 3 }) catch @compileError("invalid test weights");

        break :block result;
    };

    var counts: [3]u32 = @splat(0);

    for (0..table.count) |column| {
        for (0..table.total) |threshold| {
            counts[table.pick(.{ .column = @intCast(column), .threshold = threshold })] += 1;
        }
    }

    try std.testing.expectEqualSlices(u32, &.{ 3, 0, 9 }, &counts);
}

test "invalid weights leave the table empty" {
    var table: TableType(2) = undefined;

    try std.testing.expectError(error.WeightsEmpty, table.init(&.{}));
    try std.testing.expectEqual(@as(u32, 0), table.count);
    try std.testing.expectError(error.WeightsZero, table.init(&.{ 0, 0 }));
    try std.testing.expectError(error.EntriesExhausted, table.init(&.{ 1, 2, 3 }));
}

test "maximum weights conserve exact integer mass" {
    const weights = [_]u32{ std.math.maxInt(u32), 0, 1, std.math.maxInt(u32) };
    var table: TableType(weights.len) = undefined;
    var mass: [weights.len]u128 = @splat(0);

    try table.init(&weights);

    for (table.entries[0..table.count], 0..) |entry, column| {
        mass[column] += entry.threshold;
        mass[entry.alternate] += table.total - entry.threshold;
    }

    for (weights, mass) |weight, actual| {
        try std.testing.expectEqual(@as(u128, weight) * weights.len, actual);
    }
}

test "large tables initialize at compile time" {
    const table = comptime block: {
        const weights: [1024]u32 = @splat(1);
        var result: TableType(weights.len) = undefined;

        result.init(&weights) catch @compileError("invalid test weights");

        break :block result;
    };

    try std.testing.expectEqual(@as(u32, 1024), table.count);
    try std.testing.expectEqual(@as(u64, 1024), table.total);
    try std.testing.expectEqual(@as(u32, 1023), table.pick(.{ .column = 1023, .threshold = 0 }));
}
