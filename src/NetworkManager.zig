const std = @import("std");
pub const NMClient = opaque {};
const utils = @import("utils.zig");
const GError = struct { quark: c_uint, code: c_int, message: [*:0]const u8 };
const GCancellable = opaque {};
const NMWifiP2PPeer = opaque {};
const NMSetting = opaque {};
const NMActiveConnection = opaque {};
pub const NMDevice = opaque {};
const GBytes = opaque {};
const GPtrArray = extern struct {
    pdata: [*]?*anyopaque,
    len: u32,
};
const App = @import("main.zig");
const NM_DEVICE_TYPE_WIFI_P2P = 30;
const NM_DEVICE_STATE_UNAVAILABLE = 20;

pub const GAsyncReadyCallback = ?*const fn (
    source_object: ?*anyopaque,
    res: ?*anyopaque,
    data: ?*anyopaque,
) callconv(.c) void;

extern fn g_signal_connect_data(
    instance: ?*anyopaque,
    detailed_signal: [*:0]const u8,
    c_handler: ?*const fn (?*NMDevice, ?*NMWifiP2PPeer, ?*anyopaque) callconv(.c) void,
    data: ?*anyopaque,
    destroy_data: ?*anyopaque,
    connect_flags: u32,
) c_long;
extern fn nm_client_new(_: ?*GCancellable, _: ?**GError) callconv(.c) ?*NMClient;
extern fn nm_client_get_devices(_: ?*NMClient) callconv(.c) *GPtrArray;
extern fn nm_device_get_iface(_: ?*NMDevice) [*:0]const u8;
extern fn nm_device_get_device_type(_: ?*NMDevice) u32;
extern fn nm_device_get_state(_: ?*NMDevice) u32;
extern fn nm_device_wifi_p2p_get_peers(_: ?*NMDevice) *GPtrArray;
extern fn nm_device_wifi_p2p_start_find(_: ?*NMDevice, _: ?*anyopaque, _: ?*GCancellable, _: GAsyncReadyCallback, _: ?*anyopaque) callconv(.c) void;
extern fn nm_wifi_p2p_peer_get_wfd_ies(_: ?*NMWifiP2PPeer) callconv(.c) ?*GBytes;
extern fn nm_wifi_p2p_peer_get_name(_: ?*NMWifiP2PPeer) callconv(.c) [*:0]const u8;
extern fn g_timeout_add_seconds(_: c_uint, _: ?*const fn (?*anyopaque) callconv(.c) c_int, _: ?*anyopaque) callconv(.c) c_uint;
extern fn nm_wifi_p2p_peer_get_hw_address(_: ?*NMWifiP2PPeer) callconv(.c) [*:0]const u8;
extern fn nm_setting_connection_new() callconv(.c) ?*NMSetting;
extern fn nm_setting_connection_add_permission(_: ?*anyopaque, _: ?[*:0]const u8, _: ?[*:0]const u8, _: ?[*:0]const u8) callconv(.c) c_int;
extern fn nm_setting_wifi_p2p_new() callconv(.c) ?*NMSetting;
extern fn nm_setting_ip4_config_new() callconv(.c) ?*NMSetting;
extern fn nm_setting_ip6_config_new() callconv(.c) ?*NMSetting;
extern fn nm_simple_connection_new() callconv(.c) ?*anyopaque;
extern fn nm_connection_add_setting(_: ?*anyopaque, _: ?*NMSetting) callconv(.c) void;
extern fn g_bytes_new_static(_: ?[*:0]const u8, _: c_ulong) callconv(.c) ?*GBytes;
extern fn nm_client_add_and_activate_connection2(_: ?*NMClient, _: ?*anyopaque, _: ?*NMDevice, _: ?[*:0]const u8, _: ?*anyopaque, _: ?*GCancellable, _: GAsyncReadyCallback, _: ?*anyopaque) callconv(.c) void;
extern fn g_object_set(object: ?*anyopaque, first_property_name: [*:0]const u8, ...) callconv(.c) void;
extern fn nm_object_get_path(_: ?*anyopaque) callconv(.c) [*:0]const u8;
extern fn nm_client_add_and_activate_connection2_finish(_: ?*NMClient, _: ?*anyopaque, _: ?**anyopaque, _: *?*GError) callconv(.c) ?*anyopaque;

pub fn configure(app: *App) void {
    var _gerror: *GError = undefined;
    const client = nm_client_new(null, &_gerror);
    if (client == null) {
        std.log.err("{s}", .{"Could not create NetworkManager client"});
    }
    app.client = client;
    const devices = nm_client_get_devices(client);
    for (0..devices.len) |i| {
        const device: *NMDevice = @ptrCast(devices.pdata[i]);
        const name = nm_device_get_iface(device);
        const _type = nm_device_get_device_type(device);
        if (_type == NM_DEVICE_TYPE_WIFI_P2P) {
            std.log.debug("located p2p device with iface {s}", .{name});
            handleP2PDevice(device, app);
        }
    }
}

fn handleP2PDevice(device: *NMDevice, app: *App) void {
    const state = nm_device_get_state(device);
    if (state <= NM_DEVICE_STATE_UNAVAILABLE) {
        utils.die("{s}", .{"The p2p device is not available. Exiting..."});
    }
    std.log.debug("{s}", .{"P2P device is available"});

    getPeers(device, app);
}

fn getPeers(device: *NMDevice, app: *App) void {
    _ = g_signal_connect_data(
        device,
        "peer-added",
        peer_added_cb,
        app,
        null,
        0,
    );

    _ = g_signal_connect_data(
        device,
        "peer-removed",
        peer_removed_cb,
        app,
        null,
        0,
    );
    if (app.stream) {
        std.log.info("Searching for a peer with hardware address {s}", .{app.target_hw_address.?});
    }
    nm_device_wifi_p2p_start_find(device, null, null, log_start, null); //dies after 30 seconds
    _ = g_timeout_add_seconds(30, timer_callback, device);
    const existingPeers = nm_device_wifi_p2p_get_peers(device);
    for (0..existingPeers.len) |p| {
        const peer: *NMWifiP2PPeer = @ptrCast(existingPeers.pdata[p]);
        peer_added_cb(device, peer, app);
    }
}

fn timer_callback(dev: ?*anyopaque) callconv(.c) c_int {
    const device: ?*NMDevice = @ptrCast(dev);
    std.log.debug("{s}", .{"Restarting search"});
    nm_device_wifi_p2p_start_find(device, null, null, log_start, null);
    return 1; //G_CONTINUE
}

fn peer_added_cb(
    device: ?*NMDevice,
    peer: ?*NMWifiP2PPeer,
    user_data: ?*anyopaque,
) callconv(.c) void {
    const app: *App = @ptrCast(@alignCast(user_data.?));
    std.log.debug("peer-added event fired", .{});
    const wfd_ies = nm_wifi_p2p_peer_get_wfd_ies(peer);
    if (wfd_ies == null) {
        return;
    }
    const peer_name = nm_wifi_p2p_peer_get_name(peer);
    const hardware_address = std.mem.span(nm_wifi_p2p_peer_get_hw_address(peer));
    std.log.info("Discovered peer with name {s} and hardware address {s}", .{ peer_name, hardware_address });

    if (app.stream and std.mem.order(u8, app.target_hw_address.?, hardware_address) == .eq) {
        std.log.info("Found target device. Starting stream", .{});
        startStream(device, app, peer);
    }
}

fn startStream(device: ?*NMDevice, app: *App, peer: ?*NMWifiP2PPeer) void {
    std.log.debug("Connecting to device", .{});
    const client = app.client;
    const connection = nm_simple_connection_new();
    // const general_setting = nm_setting_connection_new();
    // nm_setting_connection_add_permission(general_setting, "user", "noble", null);
    // nm_connection_add_setting(connection, general_setting);
    // g_object_set(general_setting,"zone",)

    const wfd_ies = g_bytes_new_static("\x00\x00\x06\x00\x90\x1c\x44\x00\xc8", 9);
    const p2p_setting = nm_setting_wifi_p2p_new();
    nm_connection_add_setting(connection, p2p_setting);
    g_object_set(p2p_setting, "wfd-ies", wfd_ies, @as(?*anyopaque, null));

    const ipv4_setting = nm_setting_ip4_config_new();
    nm_connection_add_setting(connection, ipv4_setting);
    g_object_set(ipv4_setting, "method", "auto", "never-default", @as(c_int, 1), @as(?*anyopaque, null));

    const ipv6_setting = nm_setting_ip6_config_new();
    nm_connection_add_setting(connection, ipv6_setting);
    g_object_set(ipv6_setting, "method", "auto", "never-default", @as(c_int, 1), "may-fail", @as(c_int, 1), @as(?*anyopaque, null));

    nm_client_add_and_activate_connection2(client, connection, device, nm_object_get_path(peer), null, null, p2p_connected, app);
}

fn p2p_connected(
    source: ?*anyopaque,
    result: ?*anyopaque,
    user_data: ?*anyopaque,
) callconv(.c) void {
    _ = user_data;
    var err: ?*GError = null;
    const active = nm_client_add_and_activate_connection2_finish(
        @ptrCast(source),
        result,
        null,
        &err,
    );
    _ = active;
    if (err) |e| {
        std.log.err("P2P connection failed: {s}", .{e.message});
        return;
    }
    std.log.info("P2P activation started", .{});
}

fn peer_removed_cb(
    device: ?*NMDevice,
    peer: ?*NMWifiP2PPeer,
    user_data: ?*anyopaque,
) callconv(.c) void {
    _ = user_data;
    _ = device;

    std.log.debug("peer-removed event fired", .{});
    const peer_name = nm_wifi_p2p_peer_get_name(peer);
    const hardware_address = nm_wifi_p2p_peer_get_hw_address(peer);
    std.log.info("Peer with name {s} and hardware address {s} was removed", .{ peer_name, hardware_address });
}
fn log_start(_: ?*anyopaque, _: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {}
