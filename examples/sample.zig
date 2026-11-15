const std = @import("std");

const alias = @import("alias");

const assert = std.debug.assert;

const Table = alias.TableType(3);

const names = [_][]const u8{ "common", "never", "rare" };
const weights = [_]u32{ 9, 0, 1 };
const draw_count: u32 = 1000;

pub fn main() !void {
    assert(names.len == weights.len);
    assert(weights.len <= alias.limits.entry_count_max);

    var table: Table = undefined;
    var prng = std.Random.DefaultPrng.init(0x5eed);
    var counts: [names.len]u32 = @splat(0);

    try table.init(&weights);

    for (0..draw_count) |_| {
        counts[table.sample(prng.random())] += 1;
    }

    for (names, counts) |name, count| {
        std.debug.print("{s}: {d} of {d}\n", .{ name, count, draw_count });
    }

    assert(counts[1] == 0);
}
