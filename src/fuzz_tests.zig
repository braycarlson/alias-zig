const std = @import("std");

const table_fuzz = @import("table_fuzz.zig");

const assert = std.debug.assert;

const Fuzzer = enum {
    smoke,
    table,
};

const Campaign = struct {
    events_max: u32,
    seed: u64,
};

const arguments_bytes_max: u32 = 4096;
const events_max_default: u32 = 20_000;
const events_max_smoke: u32 = 256;
const seed_smoke: u64 = 0x5eed;
const usage_text = "usage: fuzz <table|smoke> [seed]\n";

comptime {
    assert(events_max_smoke < events_max_default);
    assert(usage_text.len > 0);
}

pub fn main(init: std.process.Init) !void {
    assert(init.minimal.args.vector.len < std.math.maxInt(u32));
    assert(arguments_bytes_max > 0);

    const arguments = try init.minimal.args.toSlice(init.arena.allocator());
    if (arguments.len < 2) return usage();
    if (arguments.len > 3) return usage();

    const fuzzer = std.meta.stringToEnum(Fuzzer, arguments[1]) orelse return usage();
    const seed_text = if (arguments.len == 3) arguments[2] else "";

    if (fuzzer == .smoke) {
        if (seed_text.len > 0) return usage();

        for (std.enums.values(Fuzzer)) |each| {
            if (each == .smoke) continue;

            try run(each, &.{ .events_max = events_max_smoke, .seed = seed_smoke });
        }

        return;
    }

    const seed = if (seed_text.len == 0) seed_random(init.io) else try seed_parse(seed_text);

    try run(fuzzer, &.{ .events_max = events_max_default, .seed = seed });
}

fn usage() error{ArgumentsInvalid} {
    assert(usage_text.len > 0);
    assert(arguments_bytes_max > 0);

    std.debug.print("{s}", .{usage_text});

    return error.ArgumentsInvalid;
}

fn seed_parse(text: []const u8) error{ArgumentsInvalid}!u64 {
    assert(text.len > 0);
    assert(text.len <= arguments_bytes_max);

    const result = std.fmt.parseInt(u64, text, 10) catch return usage();
    return result;
}

fn seed_random(io: std.Io) u64 {
    var result: u64 = 0;

    io.random(std.mem.asBytes(&result));

    assert(@sizeOf(u64) == 8);

    return result;
}

fn run(fuzzer: Fuzzer, campaign: *const Campaign) !void {
    assert(fuzzer != .smoke);
    assert(campaign.events_max > 0);

    std.debug.print("fuzz {t}: seed={d} events_max={d}\n", .{
        fuzzer,
        campaign.seed,
        campaign.events_max,
    });

    switch (fuzzer) {
        .smoke => unreachable,
        .table => try table_fuzz.run(&.{
            .events_max = campaign.events_max,
            .seed = campaign.seed,
        }),
    }
}
