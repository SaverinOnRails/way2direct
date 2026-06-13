const std = @import("std");
pub const gpa= std.heap.page_allocator;

pub fn die(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    std.process.exit(0);
}
