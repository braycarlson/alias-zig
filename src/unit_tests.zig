const std = @import("std");

const assert = std.debug.assert;

comptime {
    _ = @import("alias.zig");
    _ = @import("fuzz_tests.zig");
    _ = @import("table.zig");
    _ = @import("table_fuzz.zig");
    _ = @import("tidy.zig");
}

test "every public declaration compiles" {
    const alias = @import("alias.zig");

    const Table = alias.TableType(4);

    comptime assert(@hasDecl(alias, "TableType"));
    comptime assert(@hasDecl(Table, "Entry"));

    std.testing.refAllDecls(alias);
    std.testing.refAllDecls(alias.limits);
    std.testing.refAllDecls(Table);
}
