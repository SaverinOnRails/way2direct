const std = @import("std");
const NetworkManager = @import("NetworkManager.zig");
const utils = @import("utils.zig");
const App = @This();
const GMainLoop = opaque {};
stream: bool = false,
client: ?*NetworkManager.NMClient = null,
target_hw_address: ?[]const u8 = null,
extern fn g_main_loop_new(_: ?*anyopaque, _: c_int) callconv(.c) *GMainLoop;
extern fn g_main_loop_run(_: ?*GMainLoop) callconv(.c) void;

pub fn main(init: std.process.Init.Minimal) !void {
    const args = try init.args.toSlice(utils.gpa);

    var app = App{};
    if (args.len < 2) utils.die("{s}", .{"Not enough arguments supplied"});
    if (std.mem.order(u8, args[1], "--discover") == .eq) {} else if (std.mem.order(u8, args[1], "--stream") == .eq) {
        if (args.len < 3) utils.die("{s}", .{"Must provide target hardware address"});
        app.stream = true;
        app.target_hw_address = args[2];
        const target_len = std.mem.trim(u8, app.target_hw_address.?, " ").len;
        std.log.info("{d}", .{target_len});
        if (target_len == 0) {
            utils.die("{s}", .{"Must provide target hardware address"});
        }
    } else {}
    const loop = g_main_loop_new(null, 0);
    configureNetwork(&app);

    g_main_loop_run(loop);
}

fn configureNetwork(self: *App) void {
    NetworkManager.configure(self);
}
