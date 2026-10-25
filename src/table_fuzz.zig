const std = @import("std");

const alias = @import("alias.zig");

const assert = std.debug.assert;
const testing = std.testing;

pub const Campaign = struct {
    events_max: u32,
    seed: u64,
};

const Table = alias.TableType(weight_count_max);

const weight_count_max: u32 = 8;
const weight_max: u32 = 8;

pub fn run(campaign: *const Campaign) !void {
    assert(campaign.events_max > 0);
    assert(campaign.events_max <= 1_000_000);

    var prng = std.Random.DefaultPrng.init(campaign.seed);
    const random = prng.random();
    var table: Table = undefined;
    var weights: [weight_count_max]u32 = undefined;

    for (0..campaign.events_max) |_| {
        const count = random.uintLessThan(u32, weight_count_max) + 1;
        var total: u32 = 0;

        for (weights[0..count]) |*weight| {
            weight.* = random.uintLessThan(u32, weight_max);
            total += weight.*;
        }

        if (total == 0) {
            try testing.expectError(error.WeightsZero, table.init(weights[0..count]));

            continue;
        }

        try table.init(weights[0..count]);
        try mass_check(&table, weights[0..count], total);
        try testing.expect(weights[table.sample(random)] > 0);
    }
}

fn mass_check(table: *const Table, weights: []const u32, total: u32) !void {
    assert(weights.len == table.count);
    assert(total == table.total);

    var observed: [weight_count_max]u32 = @splat(0);

    for (0..weights.len) |column| {
        for (0..total) |threshold| {
            const result = table.pick(.{ .column = @intCast(column), .threshold = threshold });

            observed[result] += 1;
        }
    }

    for (weights, observed[0..weights.len]) |weight, actual| {
        try testing.expectEqual(weight * table.count, actual);
    }
}

test "table model smoke" {
    try run(&.{ .events_max = 256, .seed = 123 });
}
