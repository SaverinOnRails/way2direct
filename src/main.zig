const std = @import("std");
const NetworkManager = @import("NetworkManager.zig");
const utils = @import("utils.zig");
const App = @This();
const GMainLoop = opaque {};
discover: bool = false, //false if we're looking to stream instead of just browsing
target_hw_address: ?[]const u8 = null,
extern fn g_main_loop_new(_: ?*anyopaque, _: c_int) callconv(.c) *GMainLoop;
extern fn g_main_loop_run(_: ?*GMainLoop) callconv(.c) void;

pub fn main(init: std.process.Init.Minimal) !void {
    const args = try init.args.toSlice(utils.gpa);

    var app = App{};
    if (args.len < 2) utils.die("{s}", .{"Not enough arguments supplied"});
    if (std.mem.order(u8, args[1], "--discover") == .eq) {
        app.discover = true;
    } else if (std.mem.order(u8, args[1], "--stream") == .eq and args.len > 2) {
        app.discover = false;
        app.target_hw_address = args[2];
    }
    const loop = g_main_loop_new(null, 0);
    configureNetwork(&app);

    g_main_loop_run(loop);
}

fn configureNetwork(self: *App) void {
    NetworkManager.configure(self);
}
