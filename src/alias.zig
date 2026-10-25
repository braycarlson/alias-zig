const table = @import("table.zig");

pub const CapacityError = table.CapacityError;
pub const Error = table.Error;
pub const TableType = table.TableType;
pub const WeightError = table.WeightError;

pub const limits = struct {
    pub const entry_count_max: u32 = table.entry_count_max;
};
