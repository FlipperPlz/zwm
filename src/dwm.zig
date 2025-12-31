const std = @import("std");
const util = @import("util.zig");
const drw = @import("drw.zig");
const x11 = @import("x11.zig");
const config = @import("config.zig");

fn buttonMask() i64 {
    return x11.ButtonPressMask | x11.ButtonReleaseMask;
}

fn cleanMask(mask: u32) u32 {
    return mask & ~@as(u32, @intCast(numlockmask | x11.LockMask)) & (x11.ShiftMask | x11.ControlMask | x11.Mod1Mask | x11.Mod2Mask | x11.Mod3Mask | x11.Mod4Mask | x11.Mod5Mask);
}

fn intersect(x_val: i32, y_val: i32, w_val: i32, h_val: i32, m: *Monitor) i32 {
    return util.max(0, util.min(x_val + w_val, m.windowX + m.windowWidth) - util.max(x_val, m.windowX)) *
        util.max(0, util.min(y_val + h_val, m.windowY + m.windowHeight) - util.max(y_val, m.windowY));
}

fn isVisibleOnTag(c_client: *Client, t: u32) bool {
    return (c_client.tags & t) != 0;
}

fn isVisible(c_client: *Client) bool {
    return isVisibleOnTag(c_client, c_client.monitor.tagset[c_client.monitor.selectedTags]);
}

fn mouseMask() i64 {
    return buttonMask() | x11.PointerMotionMask;
}

fn width(x_val: *Client) i32 {
    return x_val.width + 2 * x_val.borderWidth;
}

fn height(x_val: *Client) i32 {
    return x_val.height + 2 * x_val.borderWidth;
}

fn tagMask() u32 {
    return (@as(u32, 1) << util.length(config.tags)) - 1;
}

fn textW(x_val: [*:0]const u8) u32 {
    return drw.drwFontsetGetWidth(drw_state, x_val) + @as(u32, @intCast(leftRightPadding));
}

pub const CursorType = enum(u32) {
    normal,
    resize,
    move,
    last,
};

pub const ColorScheme = enum(u32) {
    normal = 0,
    selected = 1,
};

pub const NetAtom = enum(u32) {
    NetSupported,
    NetWMName,
    NetWMState,
    NetWMCheck,
    NetWMFullscreen,
    NetActiveWindow,
    NetWMWindowType,
    NetWMWindowTypeDialog,
    NetClientList,
    NetLast,
};

pub const WMAtom = enum(u32) {
    WMProtocols,
    WMDelete,
    WMState,
    WMTakeFocus,
    WMLast,
};

pub const ClickType = enum(u32) {
    tagBar,
    layoutSymbol,
    statusText,
    windowTitle,
    clientWindow,
    rootWindow,
    last,
};

pub const Client = struct {
    name: [256]u8,
    minAspect: f32,
    maxAspect: f32,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    oldX: i32,
    oldY: i32,
    oldWidth: i32,
    oldHeight: i32,
    baseWidth: i32,
    baseHeight: i32,
    incrementWidth: i32,
    incrementHeight: i32,
    maxWidth: i32,
    maxHeight: i32,
    minWidth: i32,
    minHeight: i32,
    hintsValid: config.api.Boolean,
    borderWidth: i32,
    oldBorderWidth: i32,
    tags: u32,
    isFixed: config.api.Boolean,
    isCentered: config.api.Boolean,
    isFloating: config.api.Boolean,
    isUrgent: config.api.Boolean,
    neverFocus: config.api.Boolean,
    oldState: config.api.Boolean,
    isFullscreen: config.api.Boolean,
    next: ?*Client,
    snext: ?*Client,
    monitor: *Monitor,
    window: x11.Window,
};

pub const Pertag = struct {
    currentTag: u32,
    previousTag: u32,
    masterCounts: [8]i32, // length(tags) + 1
    masterFactors: [8]f32,
    selectedLayouts: [8]u32,
    layoutIndices: [8][2]?*const config.api.Layout,
    showBars: [8]config.api.Boolean,
};

pub const Monitor = struct {
    layoutSymbol: [16]u8,
    masterFactor: f32,
    masterCount: i32,
    num: i32,
    barY: i32,
    monitorX: i32,
    monitorY: i32,
    monitorWidth: i32,
    monitorHeight: i32,
    windowX: i32,
    windowY: i32,
    windowWidth: i32,
    windowHeight: i32,
    selectedTags: u32,
    selectedLayout: u32,
    tagset: [2]u32,
    showBar: config.api.Boolean,
    topBar: config.api.Boolean,
    clients: ?*Client,
    selected: ?*Client,
    stack: ?*Client,
    next: ?*Monitor,
    barWindow: x11.Window,
    layouts: [2]?*const config.api.Layout,
    pertag: ?*Pertag,
};

var lastfocused: ?*Client = null;
var prevzoom: ?*Client = null;
const broken = "broken";
var statusText: [256]u8 = [_]u8{0} ** 256;
var screen: i32 = undefined;
var screenWidth: i32 = undefined;
var screenHeight: i32 = undefined;
var barHeight: i32 = undefined;
var leftRightPadding: i32 = undefined;
var xerrorxlib: ?*const fn (*x11.Display, *anyopaque) callconv(.c) c_int = null;
var numlockmask: u32 = 0;
var wmatom: [@intFromEnum(WMAtom.WMLast)]x11.Atom = undefined;
var netatom: [@intFromEnum(NetAtom.NetLast)]x11.Atom = undefined;
var running: i32 = 1;
var cursor: [@intFromEnum(CursorType.last)]?*drw.Cur = undefined;
var scheme: [*][*]drw.Clr = undefined;
var display: *x11.Display = undefined;
var drw_state: ?*drw.Drw = null;
var monitors: ?*Monitor = null;
var selectedMonitor: ?*Monitor = null;
var rootWindow: x11.Window = undefined;
var wmcheckwin: x11.Window = undefined;
var starttime: x11.struct_timespec = undefined;

const EventHandler = ?*const fn (*x11.XEvent) callconv(.c) void;
var handler: [x11.LASTEvent]EventHandler = [_]EventHandler{null} ** x11.LASTEvent;

fn buttonPress(e: *x11.XEvent) callconv(.c) void {
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    // std.debug.print("▶▶▶ BUTTONPRESS event\n", .{});

    const ev = &e.xbutton;
    var click: u32 = @intFromEnum(ClickType.rootWindow);
    var arg = config.api.Arg{ .ui = 0 };

    std.debug.print("    Button: {d}, window: 0x{x}, x={d}, y={d}\n", .{ ev.button, ev.window, ev.x, ev.y });

    if (windowToMonitor(ev.window)) |m| {
        if (m != selectedMonitor) {
            std.debug.print("    Switching to monitor {d}\n", .{m.num});
            unfocus(selectedMonitor.?.selected, 1);
            selectedMonitor = m;
            focus(null);
        }
    }

    if (selectedMonitor) |mon| {
        if (ev.window == mon.barWindow) {
            std.debug.print("    Click on bar\n", .{});
            var i: i32 = 0;
            var x: u32 = 0;
            while (true) {
                x += textW(config.tags[@intCast(i)]);
                if (@as(i32, @intCast(ev.x)) < @as(i32, @intCast(x)) or i + 1 >= @as(i32, @intCast(config.tags.len))) break;
                i += 1;
            }
            if (i < @as(i32, @intCast(config.tags.len))) {
                click = @intFromEnum(ClickType.tagBar);
                arg.ui = @as(u32, 1) << @as(u5, @intCast(i));
                std.debug.print("    Tag {d} clicked\n", .{i});
            }

            if (i >= @as(i32, @intCast(config.tags.len))) {
                if (@as(i32, @intCast(ev.x)) < @as(i32, @intCast(x + textW(@as([*:0]const u8, @ptrCast(&mon.layoutSymbol)))))) {
                    click = @intFromEnum(ClickType.layoutSymbol);
                    std.debug.print("    Layout symbol clicked\n", .{});
                } else if (@as(i32, @intCast(ev.x)) > mon.windowWidth - @as(i32, @intCast(textW(@as([*:0]const u8, @ptrCast(&statusText)))))) {
                    click = @intFromEnum(ClickType.statusText);
                    std.debug.print("    Status text clicked\n", .{});
                } else {
                    click = @intFromEnum(ClickType.windowTitle);
                    std.debug.print("    Window title clicked\n", .{});
                }
            }
        } else if (windowToClient(ev.window)) |client_click| {
            std.debug.print("    Click on client window 0x{x}\n", .{client_click.window});
            focus(client_click);
            restack(selectedMonitor.?);
            _ = x11.XAllowEvents(display, x11.ReplayPointer, x11.CurrentTime);
            click = @intFromEnum(ClickType.clientWindow);
        }
    }

    for (config.buttons) |button| {
        if (click == button.clickTarget and button.func != null and button.mouseButton == ev.button and
            cleanMask(button.modifiers) == cleanMask(@intCast(ev.state)))
        {
            std.debug.print("    Executing button function\n", .{});
            const final_arg = if (click == @intFromEnum(ClickType.tagBar) and button.actionArg.i == 0) &arg else &button.actionArg;
            button.func.?(final_arg);
        }
    }

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

fn clientMessage(e: *x11.XEvent) callconv(.c) void {
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ CLIENTMESSAGE event\n", .{});

    const cme = &e.xclient;
    const c_opt = windowToClient(cme.window);

    if (c_opt == null) {
        std.debug.print("    No client found for window 0x{x}\n", .{cme.window});
        return;
    }

    const client = c_opt.?;
    std.debug.print("    Client: 0x{x}, message_type: {d}\n", .{ client.window, cme.message_type });

    if (cme.message_type == netatom[@intFromEnum(NetAtom.NetWMState)]) {
        std.debug.print("    _NET_WM_STATE message\n", .{});
        if (cme.data.l[1] == @as(i64, @intCast(netatom[@intFromEnum(NetAtom.NetWMFullscreen)])) or
            cme.data.l[2] == @as(i64, @intCast(netatom[@intFromEnum(NetAtom.NetWMFullscreen)])))
        {
            // _NET_WM_STATE_ADD = 1, _NET_WM_STATE_TOGGLE = 2
            const fullscreen = @intFromBool(cme.data.l[0] == 1 or
                (cme.data.l[0] == 2 and client.isFullscreen == .False));
            std.debug.print("    Setting fullscreen: {d}\n", .{fullscreen});
            setFullscreen(client, fullscreen);
        }
    } else if (cme.message_type == netatom[@intFromEnum(NetAtom.NetActiveWindow)]) {
        std.debug.print("    _NET_ACTIVE_WINDOW message\n", .{});
        if (client != selectedMonitor.?.selected and client.isUrgent == .False) {
            std.debug.print("    Setting client urgent\n", .{});
            setUrgent(client, 1);
        }
    }

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

fn configureNotify(e: *x11.XEvent) callconv(.c) void {
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ CONFIGURENOTIFY event\n", .{});

    const ev = &e.xconfigure;

    // TODO: updategeom handling sucks, needs to be simplified
    if (ev.window == rootWindow) {
        std.debug.print("    Root window configured\n", .{});
        const dirty_screen = (screenWidth != ev.width or screenHeight != ev.height);
        screenWidth = ev.width;
        screenHeight = ev.height;
        std.debug.print("    New screen size: {d}x{d}, dirty={}\n", .{ screenWidth, screenHeight, dirty_screen });

        const dirty_geom = updateGeom();
        if (dirty_geom != 0 or dirty_screen) {
            if (drw_state) |d| {
                drw.drwResize(d, @intCast(screenWidth), @intCast(barHeight));
            }
            updateBars();

            var m_opt = monitors;
            while (m_opt) |m| : (m_opt = m.next) {
                var c_opt = m.clients;
                while (c_opt) |c| : (c_opt = c.next) {
                    if (c.isFullscreen != .False) {
                        resizeClient(c, m.monitorX, m.monitorY, m.monitorWidth, m.monitorHeight);
                    }
                }
                _ = x11.XMoveResizeWindow(display, m.barWindow, m.windowX, m.barY, @intCast(m.windowWidth), @intCast(barHeight));
            }

            focus(null);
            arrange(null);
        }
    }

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

fn configureRequest(e: *x11.XEvent) callconv(.c) void {
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ CONFIGUREREQUEST event\n", .{});

    const ev = &e.xconfigurerequest;
    var wc: x11.XWindowChanges = undefined;

    std.debug.print("    Window: 0x{x}, value_mask: 0x{x}\n", .{ ev.window, ev.value_mask });

    if (windowToClient(ev.window)) |client| {
        std.debug.print("    Client found: 0x{x}\n", .{client.window});

        if ((ev.value_mask & x11.CWBorderWidth) != 0) {
            client.borderWidth = ev.border_width;
            std.debug.print("    Setting border width: {d}\n", .{client.borderWidth});
        } else if (client.isFloating != .False or client.monitor.layouts[client.monitor.selectedLayout] == null or client.monitor.layouts[client.monitor.selectedLayout].?.arrange == null) {
            const m = client.monitor;
            if ((ev.value_mask & x11.CWX) != 0) {
                client.oldX = client.x;
                client.x = m.windowX + ev.x;
            }
            if ((ev.value_mask & x11.CWY) != 0) {
                client.oldY = client.y;
                client.y = m.windowY + ev.y;
            }
            if ((ev.value_mask & x11.CWWidth) != 0) {
                client.oldWidth = client.width;
                client.width = ev.width;
            }
            if ((ev.value_mask & x11.CWHeight) != 0) {
                client.oldHeight = client.height;
                client.height = ev.height;
            }

            std.debug.print("    New geometry: {d}x{d} at ({d},{d})\n", .{ client.width, client.height, client.x, client.y });

            if ((client.x + client.width) > m.windowX + m.windowWidth and client.isFloating != .False)
                client.x = m.windowX + @divTrunc(m.windowWidth, 2) - @divTrunc(width(client), 2);
            if ((client.y + client.height) > m.windowY + m.windowHeight and client.isFloating != .False)
                client.y = m.windowY + @divTrunc(m.windowHeight, 2) - @divTrunc(height(client), 2);

            if (((ev.value_mask & (x11.CWX | x11.CWY)) != 0) and ((ev.value_mask & (x11.CWWidth | x11.CWHeight)) == 0)) {
                configure(client);
            }

            if (isVisible(client)) {
                _ = x11.XMoveResizeWindow(display, client.window, client.x, client.y, @intCast(client.width), @intCast(client.height));
            }
        } else {
            configure(client);
        }
    } else {
        std.debug.print("    Unmanaged window, forwarding configure\n", .{});
        wc.x = ev.x;
        wc.y = ev.y;
        wc.width = ev.width;
        wc.height = ev.height;
        wc.border_width = ev.border_width;
        wc.sibling = ev.above;
        wc.stack_mode = ev.detail;
        _ = x11.XConfigureWindow(display, ev.window, @intCast(ev.value_mask), &wc);
    }

    _ = x11.XSync(display, x11.False);
    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

fn destroyNotify(e: *x11.XEvent) callconv(.c) void {
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ DESTROYNOTIFY event\n", .{});

    const ev = &e.xdestroywindow;
    std.debug.print("    Window: 0x{x}\n", .{ev.window});

    if (windowToClient(ev.window)) |client| {
        std.debug.print("    Unmanaging client 0x{x}\n", .{client.window});
        unmanage(client, 1);
    }

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

fn enterNotify(e: *x11.XEvent) callconv(.c) void {
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ ENTERNOTIFY event\n", .{});

    const ev = &e.xcrossing;

    std.debug.print("    Window: 0x{x}, mode: {d}, detail: {d}\n", .{ ev.window, ev.mode, ev.detail });

    if ((ev.mode != x11.NotifyNormal or ev.detail == x11.NotifyInferior) and ev.window != rootWindow) {
        std.debug.print("    Ignoring (not normal mode or inferior detail)\n", .{});
        // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
        return;
    }

    const c_opt = windowToClient(ev.window);
    const m = if (c_opt) |client| client.monitor else windowToMonitor(ev.window);

    if (m != selectedMonitor) {
        std.debug.print("    Switching monitor\n", .{});
        unfocus(selectedMonitor.?.selected, 1);
        selectedMonitor = m;
    } else if (c_opt == null or c_opt == selectedMonitor.?.selected) {
        std.debug.print("    No focus change needed\n", .{});
        // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
        return;
    }

    if (c_opt) |client| {
        std.debug.print("    Focusing client 0x{x}\n", .{client.window});
        focus(client);
    }

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

fn expose(e: *x11.XEvent) callconv(.c) void {
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ EXPOSE event\n", .{});

    const ev = &e.xexpose;

    std.debug.print("    Window: 0x{x}, count: {d}\n", .{ ev.window, ev.count });

    if (ev.count == 0) {
        if (windowToMonitor(ev.window)) |m| {
            std.debug.print("    Drawing bar for monitor {d}\n", .{m.num});
            drawBar(m);
        }
    }

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

fn focusin(e: *x11.XEvent) callconv(.c) void {
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ FOCUSIN event\n", .{});

    const ev = &e.xfocus;
    std.debug.print("    Window: 0x{x}\n", .{ev.window});

    if (selectedMonitor) |mon| {
        if (mon.selected) |sel| {
            if (ev.window != sel.window) {
                std.debug.print("    Refocusing correct window 0x{x}\n", .{sel.window});
                setFocus(sel);
            }
        }
    }

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

fn mappingNotify(e: *x11.XEvent) callconv(.c) void {
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ MAPPINGNOTIFY event\n", .{});

    const ev = &e.xmapping;
    std.debug.print("    Request: {d}\n", .{ev.request});

    _ = x11.XRefreshKeyboardMapping(ev);
    if (ev.request == x11.MappingKeyboard) {
        std.debug.print("    Regrabbing keys\n", .{});
        grabKeys();
    }

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

fn mapRequest(e: *x11.XEvent) callconv(.c) void {
    var wa: x11.XWindowAttributes = undefined;
    const ev = &e.xmaprequest;

    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ MAPREQUEST: Window 0x{x}\n", .{ev.window});

    if (x11.XGetWindowAttributes(display, ev.window, &wa) == 0) {
        std.debug.print("    ✗ XGetWindowAttributes failed\n", .{});
        return;
    }

    std.debug.print("    Geometry: {d}x{d} at ({d},{d})\n", .{ wa.width, wa.height, wa.x, wa.y });
    std.debug.print("    override_redirect: {}\n", .{wa.override_redirect});

    if (wa.override_redirect) {
        std.debug.print("    ✗ Ignoring (override_redirect)\n", .{});
        return;
    }

    if (windowToClient(ev.window)) |_| {
        std.debug.print("    ✗ Already managed\n", .{});
    } else {
        std.debug.print("    ✓ Managing new window...\n", .{});
        manage(ev.window, &wa);
    }
}

fn motionNotify(e: *x11.XEvent) callconv(.c) void {
    const mon_static = struct {
        var monitor: ?*Monitor = null;
    };

    const ev = &e.xmotion;

    if (ev.window != rootWindow) {
        return;
    }

    const m = rectToMon(ev.x_root, ev.y_root, 1, 1);

    if (m != mon_static.monitor and mon_static.monitor != null) {
        unfocus(selectedMonitor.?.selected, 1);
        selectedMonitor = m;
        focus(null);
    }
    mon_static.monitor = m;
}

fn propertyNotify(e: *x11.XEvent) callconv(.c) void {
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ PROPERTYNOTIFY event\n", .{});

    const ev = &e.xproperty;
    var trans: x11.Window = 0;

    std.debug.print("    Window: 0x{x}, atom: {d}, state: {d}\n", .{ ev.window, ev.atom, ev.state });

    if (ev.window == rootWindow and ev.atom == x11.XA_WM_NAME) {
        std.debug.print("    Root window WM_NAME changed, updating status\n", .{});
        updateStatus();
    } else if (ev.state == x11.PropertyDelete) {
        std.debug.print("    Property deleted, ignoring\n", .{});
    } else if (windowToClient(ev.window)) |client| {
        std.debug.print("    Client property changed: 0x{x}\n", .{client.window});

        if (ev.atom == x11.XA_WM_TRANSIENT_FOR) {
            std.debug.print("    WM_TRANSIENT_FOR changed\n", .{});
            if (client.isFloating == .False and x11.XGetTransientForHint(display, client.window, &trans) != 0 and windowToClient(trans) != null) {
                client.isFloating = .True;
                arrange(client.monitor);
            }
        } else if (ev.atom == x11.XA_WM_NORMAL_HINTS) {
            std.debug.print("    WM_NORMAL_HINTS changed\n", .{});
            client.hintsValid = .False;
        } else if (ev.atom == x11.XA_WM_HINTS) {
            std.debug.print("    WM_HINTS changed\n", .{});
            updateWmHints(client);
            drawBars();
        }

        if (ev.atom == x11.XA_WM_NAME or ev.atom == netatom[@intFromEnum(NetAtom.NetWMName)]) {
            std.debug.print("    WM_NAME changed\n", .{});
            updateTitle(client);
            if (client == client.monitor.selected) {
                drawBar(client.monitor);
            }
        }

        if (ev.atom == netatom[@intFromEnum(NetAtom.NetWMWindowType)]) {
            std.debug.print("    _NET_WM_WINDOW_TYPE changed\n", .{});
            updateWindowType(client);
        }
    }

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

fn unmapNotify(e: *x11.XEvent) callconv(.c) void {
    const ev = &e.xunmap;
    if (windowToClient(ev.window)) |client| {
        if (ev.send_event) {
            setClientState(client, x11.WithdrawnState);
        } else {
            unmanage(client, 0);
        }
    }
}

fn xError(dpy: *x11.Display, errorEvent: *anyopaque) callconv(.c) c_int {
    const ee: *x11.XErrorEvent = @ptrCast(@alignCast(errorEvent));

    // Filter out benign errors that we can ignore
    // Note: X11 error codes are defined in X11/X.h, using numeric values
    const BadWindow: u8 = 3;
    const BadMatch: u8 = 8;
    const BadDrawable: u8 = 9;
    const BadAccess: u8 = 10;

    const X_SetInputFocus: u8 = 42;
    const X_PolyText8: u8 = 64;
    const X_PolyFillRectangle: u8 = 70;
    const X_PolySegment: u8 = 68;
    const X_ConfigureWindow: u8 = 12;
    const X_GrabButton: u8 = 27;
    const X_GrabKey: u8 = 33;
    const X_CopyArea: u8 = 62;

    if (ee.error_code == BadWindow or
        (ee.request_code == X_SetInputFocus and ee.error_code == BadMatch) or
        (ee.request_code == X_PolyText8 and ee.error_code == BadDrawable) or
        (ee.request_code == X_PolyFillRectangle and ee.error_code == BadDrawable) or
        (ee.request_code == X_PolySegment and ee.error_code == BadDrawable) or
        (ee.request_code == X_ConfigureWindow and ee.error_code == BadMatch) or
        (ee.request_code == X_GrabButton and ee.error_code == BadAccess) or
        (ee.request_code == X_GrabKey and ee.error_code == BadAccess) or
        (ee.request_code == X_CopyArea and ee.error_code == BadDrawable))
    {
        return 0;
    }

    // For other errors, print and call the original error handler
    std.debug.print("zwm: fatal error: request code={d}, error code={d}\n", .{ ee.request_code, ee.error_code });
    if (xerrorxlib) |err_handler| {
        return err_handler(dpy, errorEvent); // may call exit
    }
    return 0;
}

fn xErrorStart(dpy: *x11.Display, errorEvent: *anyopaque) callconv(.c) c_int {
    _ = dpy;
    _ = errorEvent;
    util.die("zwm: another window manager is already running", .{});
    return -1;
}

fn applyLmRules() void {
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ APPLYLMRULES: Applying layout monitor rules\n", .{});

    var m_opt = monitors;
    while (m_opt) |m| : (m_opt = m.next) {
        std.debug.print("    Processing monitor {d}\n", .{m.num});

        if (m.pertag) |pertag| {
            var t: usize = 0;
            while (t <= config.tags.len) : (t += 1) {
                var new_mfact: f32 = config.mfact;
                var new_nmaster: i32 = config.nmaster;

                if (@hasDecl(config, "lm_rules")) {
                    std.debug.print("    Checking lm_rules for tag {d}\n", .{t});
                    for (config.lm_rules) |lmr| {
                        const current_layout = m.layouts[pertag.selectedLayouts[t]];
                        const rule_layout = &config.layouts[@intCast(lmr.requiredLayout)];

                        if (m.monitorWidth >= lmr.minWidth and m.monitorHeight >= lmr.minHeight and current_layout == rule_layout) {
                            std.debug.print("    Rule matched: new_mfact={d}, new_nmaster={d}\n", .{ lmr.newMasterFactor, lmr.newMasterCount });
                            new_mfact = lmr.newMasterFactor;
                            new_nmaster = lmr.newMasterCount;
                            break;
                        }
                    }
                }

                pertag.masterFactors[t] = new_mfact;
                pertag.masterCounts[t] = new_nmaster;
            }

            m.masterFactor = pertag.masterFactors[pertag.currentTag];
            m.masterCount = pertag.masterCounts[pertag.currentTag];
        }

        arrange(m);
    }

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

pub fn spawnCommand(arg: ?*const config.api.Arg) callconv(.c) void {
    const argv = arg orelse {
        std.debug.print("═══ SPAWN: ERROR - arg is null\n", .{});
        return;
    };
    if (argv.v == null) {
        std.debug.print("═══ SPAWN: ERROR - argv.v is null\n", .{});
        return;
    }

    const cmd: [*]const ?[*:0]const u8 = @ptrCast(@alignCast(argv.v));
    std.debug.print("\n═══════════════════════════════════════════\n", .{});
    std.debug.print("═══ SPAWN: Command '{s}'\n", .{cmd[0].?});
    std.debug.print("═══════════════════════════════════════════\n", .{});

    const pid = x11.fork();
    if (pid == -1) {
        std.debug.print("═══ SPAWN: ERROR - fork() failed\n", .{});
        return;
    }

    if (pid == 0) {
        std.debug.print("═══ SPAWN [child]: Executing '{s}'\n", .{cmd[0].?});

        const dpy_c: *anyopaque = @ptrCast(display);
        _ = x11.close(x11.connectionNumber(@ptrCast(dpy_c)));
        _ = x11.setsid();

        var sa = std.mem.zeroInit(x11.struct_sigaction, .{});
        _ = x11.sigemptyset(&sa.sa_mask);
        sa.sa_flags = 0;
        sa.__sigaction_handler.sa_handler = x11.SIG_DFL;
        _ = x11.sigaction(x11.SIGCHLD, &sa, null);

        const display_name = x11.XDisplayString(display);
        if (display_name) |dname| {
            std.debug.print("═══ SPAWN [child]: DISPLAY={s}\n", .{dname});
            _ = x11.setenv("DISPLAY", dname, 1);
        }

        _ = x11.execvp(cmd[0].?, @ptrCast(cmd));

        std.debug.print("═══ SPAWN [child]: ERROR - execvp failed\n", .{});
        std.process.exit(1);
    } else {
        std.debug.print("═══ SPAWN [parent]: Child PID {d}\n", .{pid});
    }
}

pub fn viewTagMask(arg: ?*const config.api.Arg) callconv(.c) void {
    const a = arg orelse return;
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ VIEW: Switching view, arg.ui=0x{x}\n", .{a.ui});

    if (selectedMonitor == null) return;
    const mon = selectedMonitor.?;

    if ((a.ui & tagMask()) == mon.tagset[mon.selectedTags]) {
        std.debug.print("    Same tagset, ignoring\n", .{});
        return;
    }

    mon.selectedTags ^= 1; // toggle sel tagset
    std.debug.print("    Toggled seltags to {d}\n", .{mon.selectedTags});

    if ((a.ui & tagMask()) != 0) {
        mon.tagset[mon.selectedTags] = a.ui & tagMask();

        if (mon.pertag) |pertag| {
            pertag.previousTag = pertag.currentTag;

            if (a.ui == ~@as(u32, 0)) {
                pertag.currentTag = 0;
                std.debug.print("    Show all tags\n", .{});
            } else {
                var i: u32 = 0;
                while ((a.ui & (@as(u32, 1) << @intCast(i))) == 0) : (i += 1) {}
                pertag.currentTag = i + 1;
                std.debug.print("    Switched to tag {d}\n", .{i});
            }
        }
    } else {
        if (mon.pertag) |pertag| {
            const tmptag = pertag.previousTag;
            pertag.previousTag = pertag.currentTag;
            pertag.currentTag = tmptag;
            std.debug.print("    Swapped tags: {d} <-> {d}\n", .{ pertag.previousTag, pertag.currentTag });
        }
    }

    if (mon.pertag) |pertag| {
        mon.masterCount = pertag.masterCounts[pertag.currentTag];
        mon.masterFactor = pertag.masterFactors[pertag.currentTag];
        mon.selectedLayout = pertag.selectedLayouts[pertag.currentTag];
        mon.layouts[mon.selectedLayout] = pertag.layoutIndices[pertag.currentTag][mon.selectedLayout];
        mon.layouts[mon.selectedLayout ^ 1] = pertag.layoutIndices[pertag.currentTag][mon.selectedLayout ^ 1];

        if (mon.showBar != pertag.showBars[pertag.currentTag]) {
            std.debug.print("    Toggling bar\n", .{});
            toggleBar(null);
        }
    }

    focus(null);
    arrange(mon);
    warp(null);

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

fn toggleView(arg: ?*const config.api.Arg) callconv(.c) void {
    const a = arg orelse return;
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ TOGGLEVIEW: Toggling view, arg.ui=0x{x}\n", .{a.ui});

    if (selectedMonitor == null) return;
    const mon = selectedMonitor.?;

    const newtagset = mon.tagset[mon.selectedTags] ^ (a.ui & tagMask());
    if (newtagset != 0) {
        std.debug.print("    New tagset: 0x{x}\n", .{newtagset});
        mon.tagset[mon.selectedTags] = newtagset;

        if (mon.pertag) |pertag| {
            if (newtagset == ~@as(u32, 0)) {
                pertag.previousTag = pertag.currentTag;
                pertag.currentTag = 0;
                std.debug.print("    Show all tags\n", .{});
            } else if ((newtagset & (@as(u32, 1) << @intCast(pertag.currentTag - 1))) == 0) {
                pertag.previousTag = pertag.currentTag;
                var i: u32 = 0;
                while ((newtagset & (@as(u32, 1) << @intCast(i))) == 0) : (i += 1) {}
                pertag.currentTag = i + 1;
                std.debug.print("    Switched to tag {d}\n", .{i});
            }

            mon.masterCount = pertag.masterCounts[pertag.currentTag];
            mon.masterFactor = pertag.masterFactors[pertag.currentTag];
            mon.selectedLayout = pertag.selectedLayouts[pertag.currentTag];
            mon.layouts[mon.selectedLayout] = pertag.layoutIndices[pertag.currentTag][mon.selectedLayout];
            mon.layouts[mon.selectedLayout ^ 1] = pertag.layoutIndices[pertag.currentTag][mon.selectedLayout ^ 1];

            if (mon.showBar != pertag.showBars[pertag.currentTag]) {
                std.debug.print("    Toggling bar\n", .{});
                toggleBar(null);
            }
        }

        focus(null);
        arrange(mon);
    }

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

fn tag(arg: ?*const config.api.Arg) callconv(.c) void {
    const a = arg orelse return;
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ TAG: Tagging window, arg.ui=0x{x}\n", .{a.ui});

    if (selectedMonitor == null or selectedMonitor.?.selected == null) return;
    const mon = selectedMonitor.?;
    const client = mon.selected.?;

    if ((a.ui & tagMask()) != 0) {
        std.debug.print("    Setting tags: 0x{x}\n", .{a.ui & tagMask()});
        client.tags = a.ui & tagMask();
        focus(null);
        arrange(mon);
    }

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

fn toggleTag(arg: ?*const config.api.Arg) callconv(.c) void {
    const a = arg orelse return;
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ TOGGLETAG: Toggling tag, arg.ui=0x{x}\n", .{a.ui});

    if (selectedMonitor == null or selectedMonitor.?.selected == null) return;
    const mon = selectedMonitor.?;
    const client = mon.selected.?;

    const newtags = client.tags ^ (a.ui & tagMask());
    if (newtags != 0) {
        std.debug.print("    New tags: 0x{x}\n", .{newtags});
        client.tags = newtags;
        focus(null);
        arrange(mon);
        warp(null);
    }

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

pub fn promoteToMaster(arg: ?*const config.api.Arg) callconv(.c) void {
    _ = arg;
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ ZOOM: Zooming window\n", .{});

    if (selectedMonitor == null or selectedMonitor.?.selected == null) {
        std.debug.print("    No selected monitor or client\n", .{});
        return;
    }

    const mon = selectedMonitor.?;
    var c_var = mon.selected;
    var at: ?*Client = null;
    var cprevious: ?*Client = null;

    if (mon.layouts[mon.selectedLayout] == null or mon.layouts[mon.selectedLayout].?.arrange == null) {
        std.debug.print("    No layout or floating layout, ignoring\n", .{});
        return;
    }

    if (mon.selected) |sel| {
        if (sel.isFloating != .False) {
            std.debug.print("    Client is floating, ignoring\n", .{});
            return;
        }
    }

    if (c_var == nextTiled(mon.clients)) {
        std.debug.print("    Current client is master\n", .{});
        if (prevzoom) |pz| {
            at = findBefore(pz);
            if (at) |a| {
                cprevious = nextTiled(a.next);
            }
        }
        if (cprevious == null or cprevious != prevzoom) {
            prevzoom = null;
            if (c_var) |client_current| {
                const next_opt = nextTiled(client_current.next);
                if (next_opt == null) {
                    std.debug.print("    No next tiled window\n", .{});
                    return;
                }
                c_var = next_opt;
            } else {
                std.debug.print("    No current client\n", .{});
                return;
            }
        } else {
            c_var = cprevious;
        }
    }

    const cold = nextTiled(mon.clients);
    if (c_var != cold and at == null) {
        at = findBefore(c_var.?);
    }

    if (c_var) |client_zoom| {
        std.debug.print("    Detaching and attaching client 0x{x}\n", .{client_zoom.window});
        detach(client_zoom);
        attach(client_zoom);

        if (client_zoom != cold and at != null) {
            prevzoom = cold;
            if (cold) |cold_client| {
                if (at) |at_client| {
                    if (at_client != cold_client) {
                        std.debug.print("    Swapping windows\n", .{});
                        detach(cold_client);
                        cold_client.next = at_client.next;
                        at_client.next = cold_client;
                    }
                }
            }
        }

        arrange(client_zoom.monitor);

        if (cprevious != null) {
            if (cold) |cold_client| {
                warp(cold_client);
            }
        } else {
            warp(client_zoom);
        }
    }

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

fn moveMouse(arg: ?*const config.api.Arg) callconv(.c) void {
    _ = arg;
    std.debug.print("    movemouse: starting window move\n", .{});

    if (selectedMonitor == null or selectedMonitor.?.selected == null) return;
    const client = selectedMonitor.?.selected.?;
    if (client.isFullscreen != .False) {
        std.debug.print("    movemouse: no support moving fullscreen windows\n", .{});
        return;
    }

    restack(selectedMonitor.?);
    const ocx = client.x;
    const ocy = client.y;

    if (x11.XGrabPointer(display, rootWindow, x11.False, @intCast(mouseMask()), x11.GrabModeAsync, x11.GrabModeAsync, 0, cursor[@intFromEnum(CursorType.move)].?.cursor, x11.CurrentTime) != x11.GrabSuccess) {
        std.debug.print("    movemouse: XGrabPointer failed\n", .{});
        return;
    }

    var x: i32 = 0;
    var y: i32 = 0;
    if (getRootPtr(&x, &y) == 0) {
        std.debug.print("    movemouse: getrootptr failed\n", .{});
        return;
    }

    var ev: x11.XEvent = undefined;
    var lasttime: x11.Time = 0;

    while (true) {
        _ = x11.XMaskEvent(display, mouseMask() | x11.ExposureMask | x11.SubstructureRedirectMask, @ptrCast(&ev));

        switch (ev.type) {
            x11.ConfigureRequest, x11.Expose, x11.MapRequest => {
                const ev_type: usize = @intCast(ev.type);
                if (ev_type < handler.len and handler[ev_type] != null) {
                    handler[ev_type].?(&ev);
                }
            },
            x11.MotionNotify => {
                if (ev.xmotion.time - lasttime <= 1000 / 60)
                    continue;
                lasttime = ev.xmotion.time;

                var nx = ocx + (ev.xmotion.x - x);
                var ny = ocy + (ev.xmotion.y - y);

                if (@abs(selectedMonitor.?.windowX - nx) < config.snap)
                    nx = selectedMonitor.?.windowX
                else if (@abs((selectedMonitor.?.windowX + selectedMonitor.?.windowWidth) - (nx + width(client))) < config.snap)
                    nx = selectedMonitor.?.windowX + selectedMonitor.?.windowWidth - width(client);

                if (@abs(selectedMonitor.?.windowY - ny) < config.snap)
                    ny = selectedMonitor.?.windowY
                else if (@abs((selectedMonitor.?.windowY + selectedMonitor.?.windowHeight) - (ny + height(client))) < config.snap)
                    ny = selectedMonitor.?.windowY + selectedMonitor.?.windowHeight - height(client);

                if (client.isFloating == .False and selectedMonitor.?.layouts[selectedMonitor.?.selectedLayout] != null and selectedMonitor.?.layouts[selectedMonitor.?.selectedLayout].?.arrange != null and (@abs(nx - client.x) > config.snap or @abs(ny - client.y) > config.snap)) {
                    toggleFloating(null);
                }

                if (selectedMonitor.?.layouts[selectedMonitor.?.selectedLayout] == null or selectedMonitor.?.layouts[selectedMonitor.?.selectedLayout].?.arrange == null or client.isFloating != .False) {
                    resize(client, nx, ny, client.width, client.height, 1);
                }
            },
            else => {},
        }

        if (ev.type == x11.ButtonRelease) break;
    }

    _ = x11.XUngrabPointer(display, x11.CurrentTime);

    const m = rectToMon(client.x, client.y, client.width, client.height);
    if (m != selectedMonitor) {
        sendMon(client, m.?, 0);
        selectedMonitor = m;
        focus(null);
    }

    std.debug.print("    movemouse: move complete\n", .{});
}

fn resizeMouse(arg: ?*const config.api.Arg) callconv(.c) void {
    _ = arg;
    std.debug.print("    resizemouse: starting window resize\n", .{});

    if (selectedMonitor == null or selectedMonitor.?.selected == null) return;
    const client = selectedMonitor.?.selected.?;
    if (client.isFullscreen != .False) {
        std.debug.print("    resizemouse: no support resizing fullscreen windows\n", .{});
        return;
    }

    restack(selectedMonitor.?);
    const ocx = client.x;
    const ocy = client.y;

    if (x11.XGrabPointer(display, rootWindow, x11.False, @intCast(mouseMask()), x11.GrabModeAsync, x11.GrabModeAsync, 0, cursor[@intFromEnum(CursorType.resize)].?.cursor, x11.CurrentTime) != x11.GrabSuccess) {
        std.debug.print("    resizemouse: XGrabPointer failed\n", .{});
        return;
    }

    _ = x11.XWarpPointer(display, 0, client.window, 0, 0, 0, 0, client.width + client.borderWidth - 1, client.height + client.borderWidth - 1);

    var ev: x11.XEvent = undefined;
    var lasttime: x11.Time = 0;

    while (true) {
        _ = x11.XMaskEvent(display, mouseMask() | x11.ExposureMask | x11.SubstructureRedirectMask, @ptrCast(&ev));

        switch (ev.type) {
            x11.ConfigureRequest, x11.Expose, x11.MapRequest => {
                const ev_type: usize = @intCast(ev.type);
                if (ev_type < handler.len and handler[ev_type] != null) {
                    handler[ev_type].?(&ev);
                }
            },
            x11.MotionNotify => {
                if (ev.xmotion.time - lasttime <= 1000 / 60)
                    continue;
                lasttime = ev.xmotion.time;

                const nw = util.max(ev.xmotion.x - ocx - 2 * client.borderWidth + 1, 1);
                const nh = util.max(ev.xmotion.y - ocy - 2 * client.borderWidth + 1, 1);

                if (client.monitor.windowX + nw >= selectedMonitor.?.windowX and client.monitor.windowX + nw <= selectedMonitor.?.windowX + selectedMonitor.?.windowWidth and client.monitor.windowY + nh >= selectedMonitor.?.windowY and client.monitor.windowY + nh <= selectedMonitor.?.windowY + selectedMonitor.?.windowHeight) {
                    if (client.isFloating == .False and selectedMonitor.?.layouts[selectedMonitor.?.selectedLayout] != null and selectedMonitor.?.layouts[selectedMonitor.?.selectedLayout].?.arrange != null and (@abs(nw - client.width) > config.snap or @abs(nh - client.height) > config.snap)) {
                        toggleFloating(null);
                    }
                }

                if (selectedMonitor.?.layouts[selectedMonitor.?.selectedLayout] == null or selectedMonitor.?.layouts[selectedMonitor.?.selectedLayout].?.arrange == null or client.isFloating != .False) {
                    resize(client, client.x, client.y, nw, nh, 1);
                }
            },
            else => {},
        }

        if (ev.type == x11.ButtonRelease) break;
    }

    _ = x11.XWarpPointer(display, 0, client.window, 0, 0, 0, 0, client.width + client.borderWidth - 1, client.height + client.borderWidth - 1);
    _ = x11.XUngrabPointer(display, x11.CurrentTime);
    while (x11.XCheckMaskEvent(display, x11.EnterWindowMask, @ptrCast(&ev))) {}

    const m = rectToMon(client.x, client.y, client.width, client.height);
    if (m != selectedMonitor) {
        sendMon(client, m.?, 0);
        selectedMonitor = m;
        focus(null);
    }

    std.debug.print("    resizemouse: resize complete\n", .{});
}

fn toggleBar(arg: ?*const config.api.Arg) callconv(.c) void {
    _ = arg;
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ TOGGLEBAR: Toggling bar\n", .{});

    if (selectedMonitor == null) return;
    const mon = selectedMonitor.?;

    mon.showBar = if (mon.showBar == .False) .True else .False;
    std.debug.print("    Bar now: {s}\n", .{if (mon.showBar == .True) "visible" else "hidden"});

    if (mon.pertag) |pertag| {
        pertag.showBars[pertag.currentTag] = mon.showBar;
    }

    updateBarPos(mon);
    _ = x11.XMoveResizeWindow(display, mon.barWindow, mon.windowX, mon.barY, @intCast(mon.windowWidth), @intCast(barHeight));
    arrange(mon);

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

fn toggleFloating(arg: ?*const config.api.Arg) callconv(.c) void {
    _ = arg;
    std.debug.print("    togglefloating: toggling floating\n", .{});

    if (selectedMonitor == null or selectedMonitor.?.selected == null) return;
    const client = selectedMonitor.?.selected.?;

    if (client.isFullscreen == .True) return; // no support for fullscreen windows

    // C logic: !client.isFloating || client.isFixed
    if (client.isFloating == .False or client.isFixed != .False) {
        client.isFloating = .True;
    } else {
        client.isFloating = .False;
    }

    if (client.isFloating != .False) {
        resize(client, client.x, client.y, client.width, client.height, 0);
    }

    arrange(selectedMonitor.?);
    warp(null);
}

fn resetLayout(arg: ?*const config.api.Arg) callconv(.c) void {
    _ = arg;
    std.debug.print("    resetlayout: resetting to default layout\n", .{});

    const default_layout = config.api.Arg{ .v = @ptrCast(&config.layouts[0]) };
    setLayout(&default_layout);
    applyLmRules();
}

fn tagMon(arg: ?*const config.api.Arg) callconv(.c) void {
    const a = arg orelse return;
    std.debug.print("    tagmon: tagging to monitor direction={d}\n", .{a.i});

    if (selectedMonitor == null or selectedMonitor.?.selected == null or monitors == null or monitors.?.next == null) return;

    const m = dirToMon(a.i);
    if (m) |mon| {
        sendMon(selectedMonitor.?.selected.?, mon, 0);
        focusmon(arg);
    }
}

fn tagAllMon(arg: ?*const config.api.Arg) callconv(.c) void {
    const a = arg orelse return;
    std.debug.print("    tagallmon: tagging all to monitor direction={d}\n", .{a.i});

    if (monitors == null or monitors.?.next == null or selectedMonitor == null) return;

    const m = dirToMon(a.i);
    if (m) |mon| {
        var c_opt = selectedMonitor.?.clients;
        while (c_opt) |cl| {
            const next = cl.next;
            sendMon(cl, mon, 1);
            c_opt = next;
        }
        focusmon(arg);
    }
}

fn applyRules(client: *Client) void {
    std.debug.print("    applyrules: applying rules for client 0x{x}\n", .{client.window});

    var ch: x11.XClassHint = undefined;
    ch.res_class = null;
    ch.res_name = null;

    client.isFloating = .False;
    client.tags = 0;

    _ = x11.XGetClassHint(@ptrCast(display), client.window, &ch);
    const class: [*:0]const u8 = if (ch.res_class != null) @ptrCast(ch.res_class) else broken;
    const instance: [*:0]const u8 = if (ch.res_name != null) @ptrCast(ch.res_name) else broken;

    std.debug.print("    applyrules: class='{s}', instance='{s}'\n", .{ class, instance });

    for (config.rules) |rule| {
        const title_match = if (rule.title) |t| std.mem.indexOf(u8, &client.name, std.mem.span(t)) != null else true;
        const class_match = if (rule.class) |c_str| std.mem.indexOf(u8, std.mem.span(class), std.mem.span(c_str)) != null else true;
        const instance_match = if (rule.instance) |i| std.mem.indexOf(u8, std.mem.span(instance), std.mem.span(i)) != null else true;

        if (title_match and class_match and instance_match) {
            std.debug.print("    applyrules: rule matched\n", .{});
            client.isFloating = rule.isFloating;
            client.tags |= rule.tags;

            var m_opt = monitors;
            while (m_opt) |m| : (m_opt = m.next) {
                if (m.num == rule.monitor) {
                    client.monitor = m;
                    break;
                }
            }
        }
    }

    if (ch.res_class != null) {
        if (ch.res_class) |res_class| {
            _ = x11.XFree(@ptrCast(res_class));
        }
    }
    if (ch.res_name) |res_name| {
        _ = x11.XFree(@ptrCast(res_name));
    }

    client.tags = if ((client.tags & tagMask()) != 0)
        client.tags & tagMask()
    else
        client.monitor.tagset[client.monitor.selectedTags];

    std.debug.print("    applyrules: final tags=0x{x}\n", .{client.tags});
}

fn manage(window: x11.Window, windowAttrs: *x11.XWindowAttributes) void {
    std.debug.print("┌─────────────────────────────────────────\n", .{});
    std.debug.print("│ MANAGE: Window 0x{x}\n", .{window});
    std.debug.print("│ Initial geometry: {d}x{d} at ({d},{d})\n", .{ windowAttrs.width, windowAttrs.height, windowAttrs.x, windowAttrs.y });

    const client = util.ecallocOne(Client) catch util.die("cannot allocate client", .{});
    var trans: x11.Window = 0;

    client.window = window;

    client.x = windowAttrs.x;
    client.oldX = windowAttrs.x;
    client.y = windowAttrs.y;
    client.oldY = windowAttrs.y;
    client.width = windowAttrs.width;
    client.oldWidth = windowAttrs.width;
    client.height = windowAttrs.height;
    client.oldHeight = windowAttrs.height;
    client.oldBorderWidth = windowAttrs.border_width;

    updateTitle(client);

    if (x11.XGetTransientForHint(display, window, &trans) != 0 and windowToClient(trans) != null) {
        std.debug.print("│ Transient for window 0x{x}\n", .{trans});
        const t = windowToClient(trans).?;
        client.monitor = t.monitor;
        client.tags = t.tags;
    } else {
        std.debug.print("│ Not transient, applying rules\n", .{});
        client.monitor = selectedMonitor.?;
        applyRules(client);
    }

    std.debug.print("│ Assigned tags: 0x{x}\n", .{client.tags});
    std.debug.print("│ Monitor tagset: 0x{x}\n", .{client.monitor.tagset[client.monitor.selectedTags]});
    std.debug.print("│ ISVISIBLE: {}\n", .{isVisible(client)});

    std.debug.print("│ Monitor work area: {d}x{d} at ({d},{d})\n", .{ client.monitor.windowWidth, client.monitor.windowHeight, client.monitor.windowX, client.monitor.windowY });

    if (client.x + width(client) > client.monitor.windowX + client.monitor.windowWidth)
        client.x = client.monitor.windowX + client.monitor.windowWidth - width(client);
    if (client.y + height(client) > client.monitor.windowY + client.monitor.windowHeight)
        client.y = client.monitor.windowY + client.monitor.windowHeight - height(client);
    client.x = util.max(client.x, client.monitor.windowX);
    client.y = util.max(client.y, client.monitor.windowY);
    client.borderWidth = config.borderpx;

    std.debug.print("│ Adjusted geometry: {d}x{d} at ({d},{d}), border={d}\n", .{ client.width, client.height, client.x, client.y, client.borderWidth });

    var wc: x11.XWindowChanges = undefined;
    wc.border_width = @intCast(client.borderWidth);
    _ = x11.XConfigureWindow(display, window, @intCast(x11.CWBorderWidth), &wc);
    _ = x11.XSetWindowBorder(display, window, scheme[config.normalScheme][2].pixel);
    configure(client); // propagates border_width, if size doesn't change
    updateWindowType(client);
    updateSizeHints(client);
    updateWmHints(client);
    _ = x11.XSelectInput(display, window, x11.EnterWindowMask | x11.FocusChangeMask | x11.PropertyChangeMask | x11.StructureNotifyMask);
    grabButtons(client, 0);

    if (client.isFloating == .False) {
        const should_be_floating = (trans != 0 or client.isFixed != .False);
        client.oldState = if (should_be_floating) .True else .False;
        client.isFloating = client.oldState;
    } else {
        client.oldState = client.isFloating;
    }

    std.debug.print("│ isfloating: {d}, isfixed: {d}\n", .{ client.isFloating, client.isFixed });

    if (client.isFloating != .False) {
        std.debug.print("│ Raising floating window\n", .{});
        _ = x11.XRaiseWindow(display, client.window);
    }

    std.debug.print("│ Attaching to client list...\n", .{});
    attach(client);
    attachStack(client);

    _ = x11.XChangeProperty(display, rootWindow, netatom[@intFromEnum(NetAtom.NetClientList)], x11.XA_WINDOW, 32, x11.PropModeAppend, @ptrCast(&client.window), 1);

    const offscreen_x = client.x + 2 * screenWidth;
    std.debug.print("│ Moving off-screen temporarily to ({d},{d})\n", .{ offscreen_x, client.y });
    _ = x11.XMoveResizeWindow(display, client.window, offscreen_x, client.y, @intCast(client.width), @intCast(client.height));

    std.debug.print("│ Setting client state to NormalState\n", .{});
    setClientState(client, x11.NormalState);

    if (client.monitor == selectedMonitor) {
        unfocus(selectedMonitor.?.selected, 0);
    }
    client.monitor.selected = client;

    std.debug.print("│ Calling arrange()...\n", .{});
    arrange(client.monitor);

    std.debug.print("│ Calling XMapWindow()...\n", .{});
    _ = x11.XMapWindow(display, client.window);

    std.debug.print("│ Calling focus()...\n", .{});
    focus(null);

    std.debug.print("└─────────────────────────────────────────\n", .{});
    std.debug.print("│ MANAGE COMPLETE for 0x{x}\n", .{window});
    std.debug.print("└─────────────────────────────────────────\n\n", .{});
}

fn unmanage(client: *Client, destroyed: i32) void {
    const m = client.monitor;

    detach(client);
    detachStack(client);

    if (destroyed == 0) {
        var wc: x11.XWindowChanges = undefined;
        wc.border_width = @intCast(client.oldBorderWidth);
        _ = x11.XGrabServer(display);
        _ = x11.XSetErrorHandler(xerrordummy);
        _ = x11.XSelectInput(display, client.window, x11.NoEventMask);
        _ = x11.XConfigureWindow(display, client.window, @intCast(x11.CWBorderWidth), &wc);
        _ = x11.XUngrabButton(display, x11.AnyButton, x11.AnyModifier, client.window);
        setClientState(client, x11.WithdrawnState);
        _ = x11.XSync(display, x11.False);
        _ = x11.XSetErrorHandler(xError);
        _ = x11.XUngrabServer(display);
    }

    if (lastfocused == client)
        lastfocused = null;

    std.heap.c_allocator.destroy(client);

    updateClientList();
    arrange(m);
    focus(null);
}

fn configure(client: *Client) void {
    var ce: x11.XConfigureEvent = undefined;
    ce.type = x11.ConfigureNotify;
    ce.display = @ptrCast(display);
    ce.event = client.window;
    ce.window = client.window;
    ce.x = client.x;
    ce.y = client.y;
    ce.width = client.width;
    ce.height = client.height;
    ce.border_width = client.borderWidth;
    ce.above = 0;
    ce.override_redirect = x11.False;
    _ = x11.XSendEvent(display, client.window, x11.False, x11.StructureNotifyMask, @ptrCast(&ce));
}

fn setClientState(client: *Client, state: i64) void {
    var data = [_]i64{ state, 0 };
    _ = x11.XChangeProperty(display, client.window, wmatom[@intFromEnum(WMAtom.WMState)], wmatom[@intFromEnum(WMAtom.WMState)], 32, x11.PropModeReplace, @ptrCast(&data), 2);
}

fn updateTitle(client: *Client) void {
    // std.debug.print("    updatetitle: updating title for client 0x{x}\n", .{client.window});
    var text_buf: [256]u8 = [_]u8{0} ** 256;

    const got_netwm = getTextProp(client.window, netatom[@intFromEnum(NetAtom.NetWMName)], &text_buf);
    std.debug.print("    updatetitle: _NET_WM_NAME result={d}, text='{s}'\n", .{ got_netwm, if (text_buf[0] != 0) text_buf[0..std.mem.indexOfScalar(u8, &text_buf, 0).?] else "" });

    if (got_netwm == 0) {
        const got_wm = getTextProp(client.window, x11.XA_WM_NAME, &text_buf);
        std.debug.print("    updatetitle: WM_NAME result={d}, text='{s}'\n", .{ got_wm, if (text_buf[0] != 0) text_buf[0..std.mem.indexOfScalar(u8, &text_buf, 0).?] else "" });
    }

    if (text_buf[0] == 0) {
        std.debug.print("    updatetitle: ⚠️  Window has NO title, marking as 'broken'\n", .{});
        @memcpy(client.name[0..broken.len], broken);
        client.name[broken.len] = 0;
    } else {
        const len = std.mem.indexOfScalar(u8, &text_buf, 0) orelse text_buf.len;
        const copy_len = @min(len, client.name.len - 1);
        @memcpy(client.name[0..copy_len], text_buf[0..copy_len]);
        client.name[copy_len] = 0;
    }

    std.debug.print("    updatetitle: ✓ Final title='{s}'\n", .{client.name[0 .. std.mem.indexOfScalar(u8, &client.name, 0) orelse client.name.len]});
}

fn updateWindowType(client: *Client) void {
    std.debug.print("    updatewindowtype: checking window type for client 0x{x}\n", .{client.window});
    const state = getAtomProp(client, netatom[@intFromEnum(NetAtom.NetWMState)]);
    const wtype = getAtomProp(client, netatom[@intFromEnum(NetAtom.NetWMWindowType)]);

    if (state == netatom[@intFromEnum(NetAtom.NetWMFullscreen)]) {
        std.debug.print("    updatewindowtype: setting fullscreen\n", .{});
        setFullscreen(client, 1);
    }
    if (wtype == netatom[@intFromEnum(NetAtom.NetWMWindowTypeDialog)]) {
        std.debug.print("    updatewindowtype: setting floating (dialog)\n", .{});
        client.isFloating = .True;
    }
}

fn updateSizeHints(client: *Client) void {
    var msize: i64 = 0;
    var size: x11.XSizeHints = std.mem.zeroInit(x11.XSizeHints, .{});

    if (x11.XGetWMNormalHints(@ptrCast(display), client.window, &size, &msize) == 0)
        size.flags = x11.PSize;

    if (size.flags & x11.PBaseSize != 0) {
        client.baseWidth = size.base_width;
        client.baseHeight = size.base_height;
    } else if (size.flags & x11.PMinSize != 0) {
        client.baseWidth = size.min_width;
        client.baseHeight = size.min_height;
    } else {
        client.baseWidth = 0;
        client.baseHeight = 0;
    }

    if (size.flags & x11.PResizeInc != 0) {
        client.incrementWidth = size.width_inc;
        client.incrementHeight = size.height_inc;
    } else {
        client.incrementWidth = 0;
        client.incrementHeight = 0;
    }

    if (size.flags & x11.PMaxSize != 0) {
        client.maxWidth = size.max_width;
        client.maxHeight = size.max_height;
    } else {
        client.maxWidth = 0;
        client.maxHeight = 0;
    }

    if (size.flags & x11.PMinSize != 0) {
        client.minWidth = size.min_width;
        client.minHeight = size.min_height;
    } else if (size.flags & x11.PBaseSize != 0) {
        client.minWidth = size.base_width;
        client.minHeight = size.base_height;
    } else {
        client.minWidth = 0;
        client.minHeight = 0;
    }

    if (size.flags & x11.PAspect != 0) {
        client.minAspect = @as(f32, @floatFromInt(size.min_aspect.y)) / @as(f32, @floatFromInt(size.min_aspect.x));
        client.maxAspect = @as(f32, @floatFromInt(size.max_aspect.x)) / @as(f32, @floatFromInt(size.max_aspect.y));
    } else {
        client.maxAspect = 0.0;
        client.minAspect = 0.0;
    }

    client.isFixed = if (client.maxWidth != 0 and client.maxHeight != 0 and client.maxWidth == client.minWidth and client.maxHeight == client.minHeight) .True else .False;
}

fn updateWmHints(client: *Client) void {
    std.debug.print("    updatewmhints: updating WM hints for client 0x{x}\n", .{client.window});
    const wmh = x11.XGetWMHints(display, client.window);
    if (wmh == null) return;

    const hints: *x11.XWMHints = @ptrCast(@alignCast(wmh.?));

    if (client == selectedMonitor.?.selected and (hints.flags & x11.XUrgencyHint) != 0) {
        hints.flags &= ~x11.XUrgencyHint;
        _ = x11.XSetWMHints(display, client.window, hints);
    } else {
        client.isUrgent = if ((hints.flags & x11.XUrgencyHint) != 0) .True else .False;
    }

    if ((hints.flags & x11.InputHint) != 0) {
        client.neverFocus = if (!hints.input) .True else .False;
    } else {
        client.neverFocus = .False;
    }

    _ = x11.XFree(wmh.?);
    std.debug.print("    updatewmhints: isurgent={d}, neverfocus={d}\n", .{ client.isUrgent, client.neverFocus });
}

fn grabButtons(client: *Client, focused: i32) void {
    updateNumLockMask();

    const modifiers = [_]u32{ 0, x11.LockMask, numlockmask, numlockmask | x11.LockMask };
    _ = x11.XUngrabButton(display, x11.AnyButton, x11.AnyModifier, client.window);

    if (focused == 0) {
        _ = x11.XGrabButton(display, x11.AnyButton, x11.AnyModifier, client.window, x11.False, @intCast(buttonMask()), x11.GrabModeSync, x11.GrabModeSync, 0, 0);
    }

    for (config.buttons) |button| {
        if (button.clickTarget == @intFromEnum(ClickType.clientWindow)) {
            for (modifiers) |mod| {
                _ = x11.XGrabButton(display, button.mouseButton, button.modifiers | mod, client.window, x11.False, @intCast(buttonMask()), x11.GrabModeAsync, x11.GrabModeSync, 0, 0);
            }
        }
    }
}

pub fn setLayout(arg: ?*const config.api.Arg) callconv(.c) void {
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ SETLAYOUT: Setting layout\n", .{});

    if (selectedMonitor == null) return;
    const mon = selectedMonitor.?;

    const should_toggle = blk: {
        if (arg == null or arg.?.v == null) break :blk true;
        if (mon.layouts[mon.selectedLayout]) |current_layout| {
            const arg_layout: *const config.api.Layout = @ptrCast(@alignCast(arg.?.v.?));
            break :blk arg_layout != current_layout;
        }
        break :blk true;
    };

    if (should_toggle) {
        std.debug.print("    Toggling layout\n", .{});
        if (mon.pertag) |pertag| {
            pertag.selectedLayouts[pertag.currentTag] ^= 1;
            mon.selectedLayout = pertag.selectedLayouts[pertag.currentTag];
        } else {
            mon.selectedLayout ^= 1;
        }
    }

    if (arg) |a| {
        if (a.v) |layout_ptr| {
            const layout: *const config.api.Layout = @ptrCast(@alignCast(layout_ptr));
            std.debug.print("    Setting layout to: {s}\n", .{layout.symbol});

            if (mon.pertag) |pertag| {
                mon.layouts[mon.selectedLayout] = layout;
                pertag.layoutIndices[pertag.currentTag][mon.selectedLayout] = layout;
            } else {
                mon.layouts[mon.selectedLayout] = layout;
            }
        }
    }

    if (mon.layouts[mon.selectedLayout]) |layout| {
        const src = std.mem.sliceTo(layout.symbol, 0);
        const dest_len = @min(src.len, mon.layoutSymbol.len - 1);
        @memcpy(mon.layoutSymbol[0..dest_len], src[0..dest_len]);
        mon.layoutSymbol[dest_len] = 0;
        std.debug.print("    Layout symbol: {s}\n", .{src});
    }

    applyLmRules();

    if (mon.selected == null) {
        drawBar(mon);
    }

    warp(null);

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

pub fn adjustMasterAreaFactor(arg: ?*const config.api.Arg) callconv(.c) void {
    const a = arg orelse return;
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ SETMFACT: Setting mfact, arg.f={d}\n", .{a.f});

    if (selectedMonitor == null) return;
    const mon = selectedMonitor.?;

    if (mon.layouts[mon.selectedLayout]) |layout| {
        if (layout.arrange == null) {
            std.debug.print("    Floating layout, ignoring\n", .{});
            return; // Floating layout
        }
    } else {
        std.debug.print("    No layout, ignoring\n", .{});
        return;
    }

    var f = a.f;
    if (f < 1.0) {
        f = mon.masterFactor + f;
    } else {
        f = f - 1.0;
    }

    if (f < 0.05 or f > 0.95) {
        std.debug.print("    mfact out of range: {d}\n", .{f});
        return;
    }

    std.debug.print("    Setting mfact to {d}\n", .{f});
    mon.masterFactor = f;

    if (mon.pertag) |pertag| {
        pertag.masterFactors[pertag.currentTag] = f;
    }

    arrange(mon);

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

fn resize(client: *Client, x: i32, y: i32, w: i32, h: i32, interact: i32) void {
    var new_x = x;
    var new_y = y;
    var new_w = w;
    var new_h = h;

    if (applySizeHints(client, &new_x, &new_y, &new_w, &new_h, interact) != 0) {
        resizeClient(client, new_x, new_y, new_w, new_h);
    }
}

fn resizeClient(client: *Client, x: i32, y: i32, w: i32, h: i32) void {
    var wc: x11.XWindowChanges = undefined;

    client.oldX = client.x;
    client.oldY = client.y;
    client.oldWidth = client.width;
    client.oldHeight = client.height;

    client.x = x;
    wc.x = x;
    client.y = y;
    wc.y = y;
    client.width = w;
    wc.width = w;
    client.height = h;
    wc.height = h;
    wc.border_width = client.borderWidth;

    _ = x11.XConfigureWindow(display, client.window, @intCast(x11.CWX | x11.CWY | x11.CWWidth | x11.CWHeight | x11.CWBorderWidth), &wc);
    configure(client);
    _ = x11.XSync(display, x11.False);
}

fn applySizeHints(client: *Client, x_ptr: *i32, y_ptr: *i32, w_ptr: *i32, h_ptr: *i32, interact: i32) i32 {
    std.debug.print("    applysizehints: client 0x{x}, interact={d}\n", .{ client.window, interact });
    std.debug.print("    applysizehints: input: x={d}, y={d}, w={d}, h={d}\n", .{ x_ptr.*, y_ptr.*, w_ptr.*, h_ptr.* });

    var baseismin: i32 = 0;
    const m = client.monitor;

    w_ptr.* = util.max(1, w_ptr.*);
    h_ptr.* = util.max(1, h_ptr.*);

    if (interact != 0) {
        if (x_ptr.* > screenWidth)
            x_ptr.* = screenWidth - width(client);
        if (y_ptr.* > screenHeight)
            y_ptr.* = screenHeight - height(client);
        if (x_ptr.* + w_ptr.* + 2 * client.borderWidth < 0)
            x_ptr.* = 0;
        if (y_ptr.* + h_ptr.* + 2 * client.borderWidth < 0)
            y_ptr.* = 0;
    } else {
        if (x_ptr.* >= m.windowX + m.windowWidth)
            x_ptr.* = m.windowX + m.windowWidth - width(client);
        if (y_ptr.* >= m.windowY + m.windowHeight)
            y_ptr.* = m.windowY + m.windowHeight - height(client);
        if (x_ptr.* + w_ptr.* + 2 * client.borderWidth <= m.windowX)
            x_ptr.* = m.windowX;
        if (y_ptr.* + h_ptr.* + 2 * client.borderWidth <= m.windowY)
            y_ptr.* = m.windowY;
    }

    if (h_ptr.* < barHeight)
        h_ptr.* = barHeight;
    if (w_ptr.* < barHeight)
        w_ptr.* = barHeight;

    if (config.resizehints != 0 or client.isFloating != .False or m.layouts[m.selectedLayout] == null or m.layouts[m.selectedLayout].?.arrange == null) {
        if (client.hintsValid == .False) {
            updateSizeHints(client);
        }

        // See last two sentences in ICCCM 4.1.2.3
        baseismin = @intFromBool(client.baseWidth == client.minWidth and client.baseHeight == client.minHeight);

        if (baseismin == 0) {
            w_ptr.* -= client.baseWidth;
            h_ptr.* -= client.baseHeight;
        }

        if (client.minAspect > 0.0 and client.maxAspect > 0.0) {
            if (client.maxAspect < @as(f32, @floatFromInt(w_ptr.*)) / @as(f32, @floatFromInt(h_ptr.*))) {
                w_ptr.* = @intFromFloat(@as(f32, @floatFromInt(h_ptr.*)) * client.maxAspect + 0.5);
            } else if (client.minAspect < @as(f32, @floatFromInt(h_ptr.*)) / @as(f32, @floatFromInt(w_ptr.*))) {
                h_ptr.* = @intFromFloat(@as(f32, @floatFromInt(w_ptr.*)) * client.minAspect + 0.5);
            }
        }

        if (baseismin != 0) {
            w_ptr.* -= client.baseWidth;
            h_ptr.* -= client.baseHeight;
        }

        if (client.incrementWidth != 0)
            w_ptr.* -= @mod(w_ptr.*, client.incrementWidth);
        if (client.incrementHeight != 0)
            h_ptr.* -= @mod(h_ptr.*, client.incrementHeight);

        w_ptr.* = util.max(w_ptr.* + client.baseWidth, client.minWidth);
        h_ptr.* = util.max(h_ptr.* + client.baseHeight, client.minHeight);

        if (client.maxWidth != 0)
            w_ptr.* = util.min(w_ptr.*, client.maxWidth);
        if (client.maxHeight != 0)
            h_ptr.* = util.min(h_ptr.*, client.maxHeight);
    }

    const changed = @intFromBool(x_ptr.* != client.x or y_ptr.* != client.y or w_ptr.* != client.width or h_ptr.* != client.height);
    std.debug.print("    applysizehints: output: x={d}, y={d}, w={d}, h={d}, changed={d}\n", .{ x_ptr.*, y_ptr.*, w_ptr.*, h_ptr.*, changed });
    return changed;
}

fn nextTiled(c_opt: ?*Client) ?*Client {
    var client_opt = c_opt;
    while (client_opt) |cl| {
        if (isVisible(cl) and cl.isFloating == .False) {
            return cl;
        }
        client_opt = cl.next;
    }
    return null;
}

fn createMon() *Monitor {
    const m = util.ecallocOne(Monitor) catch util.die("cannot allocate monitor", .{});

    // Initialize geometry to 0 - will be set properly by updateGeom
    m.monitorX = 0;
    m.monitorY = 0;
    m.monitorWidth = 0;
    m.monitorHeight = 0;
    m.windowX = 0;
    m.windowY = 0;
    m.windowWidth = 0;
    m.windowHeight = 0;
    m.barY = 0;

    m.tagset[0] = 1;
    m.tagset[1] = 1;
    m.masterFactor = config.mfact;
    m.masterCount = config.nmaster;
    m.showBar = config.showbar;
    m.topBar = config.topbar;

    m.layouts[0] = &config.layouts[0];
    m.layouts[1] = &config.layouts[1 % config.layouts.len];

    if (m.layouts[0]) |layout| {
        const symbol_bytes = std.mem.span(layout.symbol);
        const copy_len = @min(symbol_bytes.len, m.layoutSymbol.len - 1);
        @memcpy(m.layoutSymbol[0..copy_len], symbol_bytes[0..copy_len]);
        m.layoutSymbol[copy_len] = 0;
    }

    return m;
}

fn isUniqueGeom(unique: [*]x11.XineramaScreenInfo, n: i32, info: *x11.XineramaScreenInfo) i32 {
    std.debug.print("    isuniquegeom: checking n={d}\n", .{n});
    var i: i32 = n;
    while (i > 0) {
        i -= 1;
        if (unique[@intCast(i)].x_org == info.x_org and
            unique[@intCast(i)].y_org == info.y_org and
            unique[@intCast(i)].width == info.width and
            unique[@intCast(i)].height == info.height)
        {
            std.debug.print("    isuniquegeom: not unique\n", .{});
            return 0;
        }
    }
    std.debug.print("    isuniquegeom: unique\n", .{});
    return 1;
}

fn updateGeom() i32 {
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ UPDATEGEOM: Updating geometry\n", .{});

    var dirty: i32 = 0;

    if (x11.XineramaIsActive(display)) {
        std.debug.print("    Xinerama is active\n", .{});
        var nn: i32 = 0;
        const info_opt = x11.XineramaQueryScreens(display, &nn);

        if (info_opt) |info| {
            std.debug.print("    Found {d} screens from Xinerama\n", .{nn});

            // Filter unique geometries
            const unique = util.ecalloc(std.heap.c_allocator, x11.XineramaScreenInfo, @intCast(nn)) catch util.die("cannot allocate unique screens", .{});
            defer std.heap.c_allocator.free(unique);

            var n: i32 = 0;
            var i: i32 = 0;
            while (i < nn) : (i += 1) {
                std.debug.print("    Screen {d}: {d}x{d} at ({d},{d})\n", .{ i, info[@intCast(i)].width, info[@intCast(i)].height, info[@intCast(i)].x_org, info[@intCast(i)].y_org });
                if (isUniqueGeom(unique.ptr, n, &info[@intCast(i)]) != 0) {
                    unique[@intCast(n)] = info[@intCast(i)];
                    n += 1;
                }
            }

            _ = x11.XFree(info);

            // Count existing monitors
            var existing_count: i32 = 0;
            var m_opt = monitors;
            while (m_opt) |_| : (m_opt = m_opt.?.next) {
                existing_count += 1;
            }

            // Create new monitors if needed
            if (n > existing_count) {
                std.debug.print("    Creating {d} new monitors\n", .{n - existing_count});
                i = existing_count;
                while (i < n) : (i += 1) {
                    // Find the last monitor
                    var last_m: ?*Monitor = monitors;
                    while (last_m) |m| {
                        if (m.next == null) break;
                        last_m = m.next;
                    }

                    const new_mon = createMon();
                    new_mon.num = i; // Set monitor number immediately
                    std.debug.print("    Created monitor {d} (geometry to be set)\n", .{new_mon.num});
                    if (last_m) |last| {
                        last.next = new_mon;
                    } else {
                        monitors = new_mon;
                    }
                }
            }

            std.debug.print("    After creating monitors, total monitors: {d}, unique geometries: {d}\n", .{ existing_count + (n - existing_count), n });

            // Update monitor geometries
            i = 0;
            m_opt = monitors;
            while (m_opt) |m| : (m_opt = m.next) {
                if (i >= n) break;

                std.debug.print("    Processing monitor {d}: current geometry {d}x{d} at ({d},{d}), unique[{d}]={d}x{d} at ({d},{d})\n", .{ i, m.monitorWidth, m.monitorHeight, m.monitorX, m.monitorY, i, unique[@intCast(i)].width, unique[@intCast(i)].height, unique[@intCast(i)].x_org, unique[@intCast(i)].y_org });

                if (i >= existing_count or
                    unique[@intCast(i)].x_org != m.monitorX or
                    unique[@intCast(i)].y_org != m.monitorY or
                    unique[@intCast(i)].width != m.monitorWidth or
                    unique[@intCast(i)].height != m.monitorHeight)
                {
                    std.debug.print("    Monitor {d} needs update (i={d} >= existing={d}: {}, geometry mismatch)\n", .{ m.num, i, existing_count, i >= existing_count });
                    dirty = 1;
                    m.num = i;
                    m.monitorX = unique[@intCast(i)].x_org;
                    m.monitorY = unique[@intCast(i)].y_org;
                    m.monitorWidth = unique[@intCast(i)].width;
                    m.monitorHeight = unique[@intCast(i)].height;
                    // Set window coordinates to match monitor coordinates (C: m->mx = m->wx = ...)
                    m.windowX = unique[@intCast(i)].x_org;
                    m.windowY = unique[@intCast(i)].y_org;
                    m.windowWidth = unique[@intCast(i)].width;
                    m.windowHeight = unique[@intCast(i)].height;
                    updateBarPos(m);
                    std.debug.print("    Monitor {d} UPDATED: monitor={d}x{d} at ({d},{d}), window={d}x{d} at ({d},{d}), barY={d}\n", .{ i, m.monitorWidth, m.monitorHeight, m.monitorX, m.monitorY, m.windowWidth, m.windowHeight, m.windowX, m.windowY, m.barY });
                }
                i += 1;
            }

            // Remove extra monitors
            if (n < existing_count) {
                std.debug.print("    Removing {d} monitors\n", .{existing_count - n});
                i = n;
                while (i < existing_count) : (i += 1) {
                    // Find the last monitor
                    var last_m: ?*Monitor = monitors;
                    while (last_m) |m| {
                        if (m.next == null) break;
                        last_m = m.next;
                    }

                    if (last_m) |m| {
                        // Move clients to first monitor
                        var c_opt = m.clients;
                        while (c_opt) |c| {
                            const next = c.next;
                            c.monitor = monitors.?;
                            detach(c);
                            detachStack(c);
                            attachtop(c);
                            attachStack(c);
                            c_opt = next;
                        }

                        cleanupMon(m);
                    }
                }
            }
        } else {
            std.debug.print("    Failed to query Xinerama screens\n", .{});
        }
    } else {
        std.debug.print("    Xinerama not active, using default monitor\n", .{});
        // Default single monitor setup
        if (monitors == null) {
            std.debug.print("    Creating initial monitor\n", .{});
            monitors = createMon();
        }

        if (monitors) |m| {
            if (m.monitorWidth != screenWidth or m.monitorHeight != screenHeight) {
                std.debug.print("    Monitor size changed: {d}x{d} -> {d}x{d}\n", .{ m.monitorWidth, m.monitorHeight, screenWidth, screenHeight });
                dirty = 1;
                // Set both monitor and window coordinates (C: mons->mw = mons->ww = sw;)
                m.monitorX = 0;
                m.monitorY = 0;
                m.monitorWidth = screenWidth;
                m.monitorHeight = screenHeight;
                m.windowX = 0;
                m.windowY = 0;
                m.windowWidth = screenWidth;
                m.windowHeight = screenHeight;
                updateBarPos(m);
                std.debug.print("    Monitor: {d}x{d} at ({d},{d})\n", .{ m.monitorWidth, m.monitorHeight, m.monitorX, m.monitorY });
            }
        }
    }

    if (dirty != 0) {
        selectedMonitor = monitors;
        selectedMonitor = windowToMonitor(rootWindow);
        std.debug.print("    Geometry updated (dirty=1)\n", .{});
    }

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
    return dirty;
}

fn updateBarPos(m: *Monitor) void {
    m.windowX = m.monitorX;
    m.windowY = m.monitorY;
    m.windowWidth = m.monitorWidth;
    m.windowHeight = m.monitorHeight;
    if (m.showBar != .False) {
        m.windowHeight -= barHeight;
        m.barY = if (m.topBar != .False) m.windowY else m.windowY + m.windowHeight;
        m.windowY = if (m.topBar != .False) m.windowY + barHeight else m.windowY;
    } else {
        m.barY = -barHeight;
    }
}

fn arrange(monitor: ?*Monitor) void {
    std.debug.print("  ┏━ ARRANGE called\n", .{});
    if (monitor) |mon| {
        std.debug.print("  ┃  Arranging single monitor\n", .{});
        std.debug.print("  ┃  Layout: {s}\n", .{@as([*:0]const u8, @ptrCast(&mon.layoutSymbol))});
        showHide(mon.stack);
        arrangeMon(mon);
        restack(mon);
    } else {
        std.debug.print("  ┃  Arranging all monitors\n", .{});
        var mon_opt = monitors;
        while (mon_opt) |mon| : (mon_opt = mon.next) {
            showHide(mon.stack);
        }
        mon_opt = monitors;
        while (mon_opt) |mon| : (mon_opt = mon.next) {
            arrangeMon(mon);
        }
    }
    std.debug.print("  ┗━ ARRANGE complete\n", .{});
}

fn arrangeMon(monitor: *Monitor) void {
    if (monitor.layouts[monitor.selectedLayout]) |layout| {
        const symbol_bytes = std.mem.span(layout.symbol);
        const copy_len = @min(symbol_bytes.len, monitor.layoutSymbol.len - 1);
        @memcpy(monitor.layoutSymbol[0..copy_len], symbol_bytes[0..copy_len]);
        monitor.layoutSymbol[copy_len] = 0;

        if (layout.arrange) |arrange_fn| {
            arrange_fn(@ptrCast(monitor));
        }
    }
}

fn showHide(c_opt: ?*Client) void {
    if (c_opt == null) return;
    const cl = c_opt.?;

    if (isVisible(cl)) {
        std.debug.print("    ┌─ SHOWHIDE: SHOWING window 0x{x}\n", .{cl.window});
        std.debug.print("    │  Position: ({d},{d}), Size: {d}x{d}\n", .{ cl.x, cl.y, cl.width, cl.height });
        std.debug.print("    │  XMoveWindow to ({d},{d})\n", .{ cl.x, cl.y });
        _ = x11.XMoveWindow(display, cl.window, cl.x, cl.y);

        if ((cl.monitor.layouts[cl.monitor.selectedLayout] == null or cl.monitor.layouts[cl.monitor.selectedLayout].?.arrange == null or cl.isFloating != .False) and cl.isFullscreen == .False) {
            std.debug.print("    │  Calling resize (floating or no layout)\n", .{});
            resize(cl, cl.x, cl.y, cl.width, cl.height, 0);
        }
        showHide(cl.snext);
    } else {
        showHide(cl.snext);
        const hide_x = width(cl) * -2;
        std.debug.print("    └─ SHOWHIDE: HIDING window 0x{x} to x={d}\n", .{ cl.window, hide_x });
        _ = x11.XMoveWindow(display, cl.window, hide_x, cl.y);
    }
}

fn col(m_ptr: ?*anyopaque) callconv(.c) void {
    const m: *Monitor = @ptrCast(@alignCast(m_ptr.?));
    var n: u32 = 0;
    var w: i32 = 0;
    var h: i32 = 0;
    var x: i32 = 0;
    var y: i32 = 0;
    var mw: i32 = 0;

    var c_opt = nextTiled(m.clients);
    while (c_opt) |_| : (c_opt = nextTiled(c_opt.?.next)) {
        n += 1;
    }

    if (n == 0) return;

    if (n > m.masterCount) {
        mw = if (m.masterCount > 0) @intFromFloat(@as(f32, @floatFromInt(m.windowWidth)) * m.masterFactor) else 0;
    } else {
        mw = m.windowWidth;
    }

    std.debug.print("col: n={d}, mw={d}, monitor: {d}x{d} at ({d},{d}), window area: {d}x{d} at ({d},{d})\n", .{ n, mw, m.monitorWidth, m.monitorHeight, m.monitorX, m.monitorY, m.windowWidth, m.windowHeight, m.windowX, m.windowY });

    var i: u32 = 0;
    x = 0;
    y = 0;
    c_opt = nextTiled(m.clients);

    while (c_opt) |cl| : (c_opt = nextTiled(cl.next)) {
        if (i < m.masterCount) {
            w = @divTrunc(mw - x, @as(i32, @intCast(util.min(n, @as(u32, @intCast(m.masterCount))) - i)));
            resize(cl, x + m.windowX, m.windowY, w - 2 * cl.borderWidth, m.windowHeight - 2 * cl.borderWidth, 0);
            x += width(cl);
        } else {
            h = @divTrunc(m.windowHeight - y, @as(i32, @intCast(n - i)));
            resize(cl, x + m.windowX, m.windowY + y, m.windowWidth - x - 2 * cl.borderWidth, h - 2 * cl.borderWidth, 0);
            y += height(cl);
        }
        i += 1;
    }
}

fn bstack(m_ptr: ?*anyopaque) callconv(.c) void {
    const m: *Monitor = @ptrCast(@alignCast(m_ptr.?));
    var n: u32 = 0;

    var c_opt = nextTiled(m.clients);
    while (c_opt) |_| : (c_opt = nextTiled(c_opt.?.next)) {
        n += 1;
    }

    if (n == 0) return;

    var mh: i32 = 0;
    var tw: i32 = 0;
    var ty: i32 = 0;

    if (n > m.masterCount) {
        mh = if (m.masterCount > 0) @intFromFloat(@as(f32, @floatFromInt(m.windowHeight)) * m.masterFactor) else 0;
        tw = @divTrunc(m.windowWidth, @as(i32, @intCast(n - @as(u32, @intCast(m.masterCount)))));
        ty = m.windowY + mh;
    } else {
        mh = m.windowHeight;
        tw = m.windowWidth;
        ty = m.windowY;
    }

    var i: u32 = 0;
    var mx: i32 = 0;
    var tx: i32 = m.windowX;
    c_opt = nextTiled(m.clients);

    while (c_opt) |cl| : (c_opt = nextTiled(cl.next)) {
        if (i < m.masterCount) {
            const w = @divTrunc(m.windowWidth - mx, @as(i32, @intCast(util.min(n, @as(u32, @intCast(m.masterCount))) - i)));
            resize(cl, m.windowX + mx, m.windowY, w - 2 * cl.borderWidth, mh - 2 * cl.borderWidth, 0);
            mx += width(cl);
        } else {
            const h = m.windowHeight - mh;
            resize(cl, tx, ty, tw - 2 * cl.borderWidth, h - 2 * cl.borderWidth, 0);
            if (tw != m.windowWidth) {
                tx += width(cl);
            }
        }
        i += 1;
    }
}

fn gaplessGrid(m_ptr: ?*anyopaque) callconv(.c) void {
    const m: *Monitor = @ptrCast(@alignCast(m_ptr.?));
    var n: u32 = 0;

    var c_opt = nextTiled(m.clients);
    while (c_opt) |_| : (c_opt = nextTiled(c_opt.?.next)) {
        n += 1;
    }

    if (n == 0) return;

    var cols: u32 = 0;
    while (cols <= n / 2) : (cols += 1) {
        if (cols * cols >= n) break;
    }
    if (n == 5) cols = 2; // Special case for 5 windows

    const rows = if (cols > 0) @divTrunc(n, cols) else 1;

    const cw: i32 = if (cols > 0) @divTrunc(m.windowWidth, @as(i32, @intCast(cols))) else m.windowWidth;
    var cn: u32 = 0; // current column
    var rn: u32 = 0; // current row

    var i: u32 = 0;
    c_opt = nextTiled(m.clients);

    while (c_opt) |cl| : (c_opt = nextTiled(cl.next)) {
        var current_rows = rows;
        if (i / rows + 1 > cols - n % cols) {
            current_rows = @divTrunc(n, cols) + 1;
        }
        const ch: i32 = if (current_rows > 0) @divTrunc(m.windowHeight, @as(i32, @intCast(current_rows))) else m.windowHeight;
        const cx = m.windowX + @as(i32, @intCast(cn)) * cw;
        const cy = m.windowY + @as(i32, @intCast(rn)) * ch;

        resize(cl, cx, cy, cw - 2 * cl.borderWidth, ch - 2 * cl.borderWidth, 0);
        rn += 1;
        if (rn >= current_rows) {
            rn = 0;
            cn += 1;
        }
        i += 1;
    }
}

fn tile(m_ptr: ?*anyopaque) callconv(.c) void {
    std.debug.print("    tile: tiling windows\n", .{});
    const m: *Monitor = @ptrCast(@alignCast(m_ptr.?));
    var n: u32 = 0;

    var c_opt = nextTiled(m.clients);
    while (c_opt) |_| : (c_opt = nextTiled(c_opt.?.next)) {
        n += 1;
    }

    if (n == 0) return;

    const mw: u32 = if (n > m.masterCount)
        if (m.masterCount > 0) @intFromFloat(@as(f32, @floatFromInt(m.windowWidth)) * m.masterFactor) else 0
    else
        @intCast(m.windowWidth);

    var i: u32 = 0;
    var my: u32 = 0;
    var ty: u32 = 0;
    c_opt = nextTiled(m.clients);

    while (c_opt) |cl| : (c_opt = nextTiled(cl.next)) {
        if (i < m.masterCount) {
            const h = @divTrunc(m.windowHeight - @as(i32, @intCast(my)), @as(i32, @intCast(util.min(n, @as(u32, @intCast(m.masterCount))) - i)));
            resize(cl, m.windowX, m.windowY + @as(i32, @intCast(my)), @as(i32, @intCast(mw)) - 2 * cl.borderWidth, h - 2 * cl.borderWidth, 0);
            if (my + height(cl) < m.windowHeight) {
                my += @intCast(height(cl));
            }
        } else {
            const h = @divTrunc(m.windowHeight - @as(i32, @intCast(ty)), @as(i32, @intCast(n - i)));
            resize(cl, m.windowX + @as(i32, @intCast(mw)), m.windowY + @as(i32, @intCast(ty)), m.windowWidth - @as(i32, @intCast(mw)) - 2 * cl.borderWidth, h - 2 * cl.borderWidth, 0);
            if (ty + height(cl) < m.windowHeight) {
                ty += @intCast(height(cl));
            }
        }
        i += 1;
    }
}

fn monocle(m_ptr: ?*anyopaque) callconv(.c) void {
    std.debug.print("    monocle: arranging windows\n", .{});
    const m: *Monitor = @ptrCast(@alignCast(m_ptr.?));
    var n: u32 = 0;

    var c_opt = m.clients;
    while (c_opt) |cl| : (c_opt = cl.next) {
        if (isVisible(cl))
            n += 1;
    }

    if (n > 0) {
        const symbol_str = std.fmt.bufPrintZ(&m.layoutSymbol, "[{d}]", .{n}) catch "[?]";
        _ = symbol_str;
    }

    c_opt = nextTiled(m.clients);
    while (c_opt) |cl| : (c_opt = nextTiled(cl.next)) {
        resize(cl, m.windowX, m.windowY, m.windowWidth - 2 * cl.borderWidth, m.windowHeight - 2 * cl.borderWidth, 0);
    }
}

fn solitary(client: *Client) i32 {
    std.debug.print("    solitary: checking if client 0x{x} is solitary\n", .{client.window});
    const first = nextTiled(client.monitor.clients);
    const only_tiled = (first == client and nextTiled(client.next) == null);
    const is_monocle = (client.monitor.layouts[client.monitor.selectedLayout] != null and
        client.monitor.layouts[client.monitor.selectedLayout].?.arrange == monocle);
    const has_layout = (client.monitor.layouts[client.monitor.selectedLayout] != null and
        client.monitor.layouts[client.monitor.selectedLayout].?.arrange != null);

    const result = @intFromBool((only_tiled or is_monocle) and
        client.isFloating == .False and has_layout);
    std.debug.print("    solitary: result={d}\n", .{result});
    return result;
}

fn updateBars() void {
    std.debug.print("    updatebars: creating/updating status bars\n", .{});

    var wa: x11.XSetWindowAttributes = undefined;
    wa.override_redirect = x11.True;
    wa.background_pixmap = x11.ParentRelative;
    wa.event_mask = x11.ButtonPressMask | x11.ExposureMask;

    var ch: x11.XClassHint = undefined;
    ch.res_name = @constCast("zwm");
    ch.res_class = @constCast("zwm");

    var m_opt = monitors;
    var bar_count: i32 = 0;
    while (m_opt) |m| : (m_opt = m.next) {
        if (m.barWindow != 0) {
            std.debug.print("    updatebars: monitor {d} already has bar, skipping\n", .{m.num});
            continue;
        }

        std.debug.print("    updatebars: creating bar for monitor {d} at ({d},{d}) {d}x{d}\n", .{ m.num, m.windowX, m.barY, m.windowWidth, barHeight });

        const dpy_c: ?*x11.Display = @ptrCast(display);
        // C uses m->wx, m->by, m->ww (window coordinates, not monitor coordinates)
        m.barWindow = x11.XCreateWindow(@ptrCast(dpy_c), rootWindow, m.windowX, m.barY, @intCast(m.windowWidth), @intCast(barHeight), 0, x11.defaultDepth(@ptrCast(dpy_c), screen), x11.CopyFromParent, x11.defaultVisual(@ptrCast(dpy_c), screen), x11.CWOverrideRedirect | x11.CWBackPixmap | x11.CWEventMask, @ptrCast(&wa));

        _ = x11.XDefineCursor(display, m.barWindow, cursor[@intFromEnum(CursorType.normal)].?.cursor);
        _ = x11.XMapRaised(display, m.barWindow);
        _ = x11.XSetClassHint(@ptrCast(display), m.barWindow, &ch);

        bar_count += 1;
        std.debug.print("    updatebars: bar created for monitor {d} at ({d},{d}) {d}x{d}, window=0x{x}\n", .{ m.num, m.windowX, m.barY, m.windowWidth, barHeight, m.barWindow });
    }
    std.debug.print("    updatebars: created {d} bars total\n", .{bar_count});
}

fn updateStatus() void {
    std.debug.print("    updatestatus: updating status text\n", .{});
    if (getTextProp(rootWindow, x11.XA_WM_NAME, &statusText) == 0) {
        const version_str = "zwm-1.0";
        @memcpy(statusText[0..version_str.len], version_str);
        statusText[version_str.len] = 0;
    }
    std.debug.print("    updatestatus: status='{s}'\n", .{statusText[0 .. std.mem.indexOfScalar(u8, &statusText, 0) orelse statusText.len]});
    drawBars();
    // drawBar(selectedMonitor.?);
}

fn drawBar(monitor: *Monitor) void {
    std.debug.print("    drawbar: drawing bar for monitor {d}, barWindow=0x{x}, showBar={d}\n", .{ monitor.num, monitor.barWindow, monitor.showBar });
    if (monitor.showBar == .False) {
        std.debug.print("    drawbar: bar hidden, skipping\n", .{});
        return;
    }

    if (monitor.barWindow == 0) {
        std.debug.print("    drawbar: bar window not created yet, skipping\n", .{});
        return;
    }

    var x: i32 = 0;
    var w: i32 = 0;
    var tw: i32 = 0;
    const boxs = @divTrunc(drw_state.?.fonts.?.height, 9);
    const boxw = @divTrunc(drw_state.?.fonts.?.height, 6) + 2;
    var occ: u32 = 0;
    var urg: u32 = 0;

    var c_opt = monitor.clients;
    while (c_opt) |client_iter| : (c_opt = client_iter.next) {
        occ |= client_iter.tags;
        if (client_iter.isUrgent != .False)
            urg |= client_iter.tags;
    }

    if (monitor == selectedMonitor) {
        drw.drwSetScheme(drw_state, scheme[config.normalScheme]);
        tw = @intCast(textW(@as([*:0]const u8, @ptrCast(&statusText))) - @as(u32, @intCast(leftRightPadding)) + 2);
        _ = drw.drwText(drw_state, monitor.windowWidth - tw, 0, @intCast(tw), @intCast(barHeight), 0, @as([*:0]const u8, @ptrCast(&statusText)), 0);
    }

    x = 0;
    for (config.tags, 0..) |tag_str, i| {
        w = @intCast(textW(tag_str));
        const is_selected = (monitor.tagset[monitor.selectedTags] & (@as(u32, 1) << @as(u5, @intCast(i)))) != 0;
        drw.drwSetScheme(drw_state, scheme[if (is_selected) config.selectedScheme else config.normalScheme]);
        const urg_bit = (urg & (@as(u32, 1) << @as(u5, @intCast(i)))) != 0;
        _ = drw.drwText(drw_state, x, 0, @intCast(w), @intCast(barHeight), @intCast(@divTrunc(leftRightPadding, 2)), tag_str, @intFromBool(urg_bit));

        if ((occ & (@as(u32, 1) << @as(u5, @intCast(i)))) != 0) {
            const filled: i32 = if (monitor == selectedMonitor and selectedMonitor.?.selected != null and (selectedMonitor.?.selected.?.tags & (@as(u32, 1) << @as(u5, @intCast(i)))) != 0) 1 else 0;
            const urgent = (urg & (@as(u32, 1) << @as(u5, @intCast(i)))) != 0;
            drw.drwRect(drw_state, x + @as(i32, @intCast(boxs)), @as(i32, @intCast(boxs)), @intCast(boxw), @intCast(boxw), filled, @intFromBool(urgent));
        }
        x += w;
    }

    w = @intCast(textW(@as([*:0]const u8, @ptrCast(&monitor.layoutSymbol))));
    drw.drwSetScheme(drw_state, scheme[config.normalScheme]);
    x = drw.drwText(drw_state, x, 0, @intCast(w), @intCast(barHeight), @intCast(@divTrunc(leftRightPadding, 2)), @as([*:0]const u8, @ptrCast(&monitor.layoutSymbol)), 0);

    // C uses m->ww (window width), not monitor width
    w = @as(i32, @intCast(monitor.windowWidth)) - tw - x;
    if (w > barHeight) {
        if (monitor.selected) |sel| {
            const is_selmon = (monitor == selectedMonitor);
            drw.drwSetScheme(drw_state, scheme[if (is_selmon) config.selectedScheme else config.normalScheme]);
            _ = drw.drwText(drw_state, x, 0, @intCast(w), @intCast(barHeight), @intCast(@divTrunc(leftRightPadding, 2)), @as([*:0]const u8, @ptrCast(&sel.name)), 0);
            if (sel.isFloating != .False) {
                drw.drwRect(drw_state, x + @as(i32, @intCast(boxs)), @as(i32, @intCast(boxs)), @intCast(boxw), @intCast(boxw), @intFromEnum(sel.isFixed), 0);
            }
        } else {
            drw.drwSetScheme(drw_state, scheme[config.normalScheme]);
            drw.drwRect(drw_state, x, 0, @intCast(w), @intCast(barHeight), 1, 1);
        }
    }

    // drwMap uses window coordinates (bar was created with windowWidth at line 2327, C uses m->ww)
    drw.drwMap(drw_state, monitor.barWindow, 0, 0, @intCast(monitor.windowWidth), @intCast(barHeight));
    std.debug.print("    drawbar: bar drawn for monitor {d}, should_draw_status={}\n", .{ monitor.num, (config.bar_all_monitors == .True or monitor == selectedMonitor) });
}

fn drawBars() void {
    std.debug.print("    drawbars: drawing all bars\n", .{});
    var m_opt = monitors;
    var count: i32 = 0;
    while (m_opt) |m| : (m_opt = m.next) {
        std.debug.print("    drawbars: calling drawBar for monitor {d}\n", .{m.num});
        drawBar(m);
        count += 1;
    }
    std.debug.print("    drawbars: drew {d} bars\n", .{count});
}

fn updateClientList() void {
    std.debug.print("    updateclientlist: updating _NET_CLIENT_LIST\n", .{});
    _ = x11.XDeleteProperty(display, rootWindow, netatom[@intFromEnum(NetAtom.NetClientList)]);

    var m_opt = monitors;
    while (m_opt) |m| : (m_opt = m.next) {
        var c_opt = m.clients;
        while (c_opt) |cl| : (c_opt = cl.next) {
            _ = x11.XChangeProperty(display, rootWindow, netatom[@intFromEnum(NetAtom.NetClientList)], x11.XA_WINDOW, 32, x11.PropModeAppend, @ptrCast(&cl.window), 1);
        }
    }
}

fn run() void {
    var ev: x11.XEvent = undefined;

    _ = x11.XSync(display, x11.False);

    while (running != 0 and x11.XNextEvent(display, @ptrCast(&ev)) == 0) {
        const ev_type: usize = @intCast(ev.type);
        if (ev_type < handler.len) {
            if (handler[ev_type]) |h| {
                h(&ev);
            }
        }
    }
}

fn scan() void {
    var d1: x11.Window = 0;
    var d2: x11.Window = 0;
    var wins: [*]x11.Window = undefined;
    var num: u32 = 0;
    var wa: x11.XWindowAttributes = undefined;

    if (x11.XQueryTree(display, rootWindow, &d1, &d2, @ptrCast(&wins), &num) != 0) {
        var i: u32 = 0;
        while (i < num) : (i += 1) {
            if (x11.XGetWindowAttributes(display, wins[i], @ptrCast(&wa)) == 0) {
                continue;
            }
            if (wa.override_redirect) {
                continue;
            }

            var trans: x11.Window = 0;
            if (x11.XGetTransientForHint(display, wins[i], &trans) != 0) {
                continue; // Skip transients in first pass
            }

            if (wa.map_state == x11.IsViewable or getState(wins[i]) == x11.IconicState) {
                manage(wins[i], &wa);
            }
        }

        i = 0;
        while (i < num) : (i += 1) {
            if (x11.XGetWindowAttributes(display, wins[i], @ptrCast(&wa)) == 0) {
                continue;
            }

            var trans: x11.Window = 0;
            if (x11.XGetTransientForHint(display, wins[i], &trans) != 0) {
                if (wa.map_state == x11.IsViewable or getState(wins[i]) == x11.IconicState) {
                    manage(wins[i], &wa);
                }
            }
        }

        _ = x11.XFree(wins);
    }

    if (selectedMonitor) |m| {
        if (nextTiled(m.clients)) |first| {
            warp(first);
        }
    }
}

fn getState(w: x11.Window) i64 {
    std.debug.print("    getstate: checking window 0x{x}\n", .{w});
    var format: i32 = 0;
    var result: i64 = -1;
    var p: [*]u8 = undefined;
    var n: c_ulong = 0;
    var extra: c_ulong = 0;
    var real: x11.Atom = 0;

    if (x11.XGetWindowProperty(display, w, wmatom[@intFromEnum(WMAtom.WMState)], 0, 2, x11.False, wmatom[@intFromEnum(WMAtom.WMState)], &real, &format, &n, &extra, @ptrCast(&p)) != x11.Success) {
        std.debug.print("    getstate: XGetWindowProperty failed\n", .{});
        return -1;
    }
    if (n != 0) {
        result = @as(*i64, @ptrCast(@alignCast(p))).*;
        std.debug.print("    getstate: window state = {d}\n", .{result});
    }
    _ = x11.XFree(p);
    return result;
}

fn warp(c_opt: ?*Client) void {
    std.debug.print("    warp: warping cursor\n", .{});
    var client = c_opt;

    if (client == null)
        client = selectedMonitor.?.selected;

    if (client == null) {
        std.debug.print("    warp: no client, warping to screen center\n", .{});
        _ = x11.XWarpPointer(display, 0, rootWindow, 0, 0, 0, 0, selectedMonitor.?.windowX + @divTrunc(selectedMonitor.?.windowWidth, 2), selectedMonitor.?.windowY + @divTrunc(selectedMonitor.?.windowHeight, 2));
        return;
    }

    std.debug.print("    warp: warping to client 0x{x}\n", .{client.?.window});
    _ = x11.XWarpPointer(display, 0, client.?.window, 0, 0, 0, 0, @divTrunc(client.?.width, 2), @divTrunc(client.?.height, 2));
}

fn checkRulePeriod() i32 {
    std.debug.print("    checkruleperiod: checking rule period\n", .{});
    const inruleperiod_static = struct {
        var inruleperiod: i32 = 1;
    };

    if (inruleperiod_static.inruleperiod == 0)
        return inruleperiod_static.inruleperiod;

    var now: x11.struct_timespec = undefined;
    if (x11.clock_gettime(x11.CLOCK_MONOTONIC, &now) != 0) {
        std.debug.print("    checkruleperiod: clock_gettime failed\n", .{});
        return 0;
    }

    inruleperiod_static.inruleperiod = if (now.tv_sec - starttime.tv_sec <= config.ruleperiod) 1 else 0;
    std.debug.print("    checkruleperiod: inruleperiod = {d}\n", .{inruleperiod_static.inruleperiod});
    return inruleperiod_static.inruleperiod;
}

fn cleanupMon(mon: *Monitor) void {
    std.debug.print("    cleanupmon: cleaning up monitor\n", .{});
    if (mon == monitors) {
        monitors = monitors.?.next;
    } else {
        var m_opt = monitors;
        while (m_opt) |m| : (m_opt = m.next) {
            if (m.next == mon) {
                m.next = mon.next;
                break;
            }
        }
    }
    _ = x11.XUnmapWindow(display, mon.barWindow);
    _ = x11.XDestroyWindow(display, mon.barWindow);
    std.heap.c_allocator.destroy(mon);
}

fn findBefore(client: *Client) ?*Client {
    std.debug.print("    findbefore: finding client before 0x{x}\n", .{client.window});
    if (client == selectedMonitor.?.clients)
        return null;
    var tmp_opt = selectedMonitor.?.clients;
    while (tmp_opt) |tmp| : (tmp_opt = tmp.next) {
        if (tmp.next == client) {
            std.debug.print("    findbefore: found client 0x{x}\n", .{tmp.window});
            return tmp;
        }
    }
    return null;
}

fn getAtomProp(client: *Client, prop: x11.Atom) x11.Atom {
    std.debug.print("    getatomprop: getting atom property for client 0x{x}\n", .{client.window});
    var di: i32 = 0;
    var dl: c_ulong = 0;
    var p: ?[*]u8 = null;
    var da: x11.Atom = 0;
    var atom: x11.Atom = 0;

    if (x11.XGetWindowProperty(display, client.window, prop, 0, @sizeOf(x11.Atom), x11.False, x11.XA_ATOM, &da, &di, &dl, &dl, @ptrCast(&p)) == x11.Success and p != null) {
        atom = @as(*x11.Atom, @ptrCast(@alignCast(p.?))).*;
        _ = x11.XFree(p.?);
    }
    std.debug.print("    getatomprop: atom = {d}\n", .{atom});
    return atom;
}

fn getClientUnderMouse() ?*Client {
    std.debug.print("    getclientundermouse: checking\n", .{});
    var di: i32 = 0;
    var dui: u32 = 0;
    var child: x11.Window = 0;
    var dummy: x11.Window = 0;

    const ret = x11.XQueryPointer(display, rootWindow, &dummy, &child, &di, &di, &di, &di, &dui);
    if (ret == 0) {
        std.debug.print("    getclientundermouse: XQueryPointer failed\n", .{});
        return null;
    }

    const client = windowToClient(child);
    if (client) |cl| {
        std.debug.print("    getclientundermouse: found client 0x{x}\n", .{cl.window});
    }
    return client;
}

fn getRootPtr(x: *i32, y: *i32) i32 {
    std.debug.print("    getrootptr: getting rootWindow pointer\n", .{});
    var di: i32 = 0;
    var dui: u32 = 0;
    var dummy: x11.Window = 0;

    const ret = x11.XQueryPointer(display, rootWindow, &dummy, &dummy, x, y, &di, &di, &dui);
    std.debug.print("    getrootptr: pointer at ({d}, {d})\n", .{ x.*, y.* });
    return ret;
}

fn getTextProp(w: x11.Window, atom: x11.Atom, text: []u8) i32 {
    std.debug.print("    gettextprop: getting text property for window 0x{x}\n", .{w});
    if (text.len == 0)
        return 0;

    text[0] = 0;
    var name: x11.XTextProperty = undefined;

    if (x11.XGetTextProperty(display, w, &name, atom) == 0 or name.nitems == 0) {
        std.debug.print("    gettextprop: XGetTextProperty failed or empty\n", .{});
        return 0;
    }

    if (name.encoding == x11.XA_STRING) {
        const value_slice = name.value[0..@min(name.nitems, text.len - 1)];
        @memcpy(text[0..value_slice.len], value_slice);
        text[value_slice.len] = 0;
        std.debug.print("    gettextprop: got text (XA_STRING): {s}\n", .{text[0..value_slice.len]});
    } else {
        var list: [*]?[*:0]u8 = undefined;
        var n: i32 = 0;
        if (x11.XmbTextPropertyToTextList(@ptrCast(display), &name, @ptrCast(&list), &n) >= x11.Success and n > 0 and list[0] != null) {
            const list_str = std.mem.span(list[0].?);
            const copy_len = @min(list_str.len, text.len - 1);
            @memcpy(text[0..copy_len], list_str[0..copy_len]);
            text[copy_len] = 0;
            _ = x11.XFreeStringList(@ptrCast(list));
            std.debug.print("    gettextprop: got text (mb): {s}\n", .{text[0..copy_len]});
        }
    }

    _ = x11.XFree(name.value);
    return 1;
}

fn restack(m: *Monitor) void {
    std.debug.print("    restack: restacking for monitor {d}\n", .{m.num});
    drawBar(m);

    if (m.selected == null) return;

    const sel = m.selected.?;
    if (sel.isFloating != .False or m.layouts[m.selectedLayout] == null or m.layouts[m.selectedLayout].?.arrange == null) {
        _ = x11.XRaiseWindow(display, sel.window);
    }

    if (m.layouts[m.selectedLayout]) |layout| {
        if (layout.arrange != null) {
            var wc: x11.XWindowChanges = undefined;
            wc.stack_mode = x11.Below;
            wc.sibling = m.barWindow;

            var c_opt = m.stack;
            while (c_opt) |cl| : (c_opt = cl.snext) {
                if (cl.isFloating == .False and isVisible(cl)) {
                    _ = x11.XConfigureWindow(display, cl.window, x11.CWSibling | x11.CWStackMode, @ptrCast(&wc));
                    wc.sibling = cl.window;
                }
            }
        }
    }

    _ = x11.XSync(display, x11.False);
    var ev: x11.XEvent = undefined;
    while (x11.XCheckMaskEvent(display, x11.EnterWindowMask, @ptrCast(&ev))) {}
}

fn dirToMon(dir: i32) ?*Monitor {
    std.debug.print("    dirtomon: direction={d}\n", .{dir});
    var m_opt: ?*Monitor = null;

    if (dir > 0) {
        m_opt = selectedMonitor.?.next;
        if (m_opt == null)
            m_opt = monitors;
    } else if (selectedMonitor == monitors) {
        m_opt = monitors;
        while (m_opt.?.next != null) {
            m_opt = m_opt.?.next;
        }
    } else {
        m_opt = monitors;
        while (m_opt.?.next != selectedMonitor) {
            m_opt = m_opt.?.next;
        }
    }

    if (m_opt) |m| {
        std.debug.print("    dirtomon: selected monitor {d}\n", .{m.num});
    }
    return m_opt;
}

fn rectToMon(x: i32, y: i32, w: i32, h: i32) ?*Monitor {
    var r: ?*Monitor = selectedMonitor;
    var area: i32 = 0;

    var m_opt = monitors;
    while (m_opt) |m| : (m_opt = m.next) {
        const a = intersect(x, y, w, h, m);
        if (a > area) {
            area = a;
            r = m;
        }
    }

    return r;
}

fn focusmon(arg: ?*const config.Arg) callconv(.c) void {
    const a = arg orelse return;
    std.debug.print("    focusmon: direction={d}\n", .{a.i});

    if (monitors == null or monitors.?.next == null) return;

    const m = dirToMon(a.i);
    if (m == selectedMonitor) return;

    unfocus(selectedMonitor.?.selected, 0);
    selectedMonitor = m;
    focus(null);
    warp(selectedMonitor.?.selected);
}

fn sendMon(client: *Client, m: *Monitor, keeptags: i32) void {
    std.debug.print("    sendmon: sending client 0x{x} to monitor {d}, keeptags={d}\n", .{ client.window, m.num, keeptags });
    if (client.monitor == m)
        return;

    unfocus(client, 1);
    detach(client);
    detachStack(client);
    client.monitor = m;

    if (keeptags == 0) {
        client.tags = m.tagset[m.selectedTags];
    }

    attach(client);
    attachStack(client);
    focus(null);
    arrange(null);
}

fn focusstack(arg: ?*const config.Arg) callconv(.c) void {
    const a = arg orelse return;
    std.debug.print("    focusstack: direction={d}\n", .{a.i});

    if (selectedMonitor == null or selectedMonitor.?.selected == null) return;
    if (selectedMonitor.?.selected.?.isFullscreen != .False and config.lockfullscreen != 0) return;

    var c_opt: ?*Client = null;

    if (a.i > 0) {
        c_opt = selectedMonitor.?.selected.?.next;
        while (c_opt != null and !isVisible(c_opt.?)) {
            c_opt = c_opt.?.next;
        }
        if (c_opt == null) {
            c_opt = selectedMonitor.?.clients;
            while (c_opt != null and !isVisible(c_opt.?)) {
                c_opt = c_opt.?.next;
            }
        }
    } else {
        var i_opt = selectedMonitor.?.clients;
        while (i_opt != null and i_opt != selectedMonitor.?.selected) : (i_opt = i_opt.?.next) {
            if (isVisible(i_opt.?))
                c_opt = i_opt;
        }
        if (c_opt == null) {
            while (i_opt != null) : (i_opt = i_opt.?.next) {
                if (isVisible(i_opt.?))
                    c_opt = i_opt;
            }
        }
    }

    if (c_opt) |cl| {
        std.debug.print("    focusstack: focusing client 0x{x}\n", .{cl.window});
        focus(cl);
        restack(selectedMonitor.?);
    }
}

fn incnmaster(arg: ?*const config.Arg) callconv(.c) void {
    const a = arg orelse return;
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ INCNMASTER: Incrementing nmaster, arg.i={d}\n", .{a.i});

    if (selectedMonitor == null) return;
    const mon = selectedMonitor.?;

    const new_nmaster = util.max(mon.masterCount + a.i, 0);
    std.debug.print("    nmaster: {d} -> {d}\n", .{ mon.masterCount, new_nmaster });

    mon.masterCount = new_nmaster;

    if (mon.pertag) |pertag| {
        pertag.masterCounts[pertag.currentTag] = new_nmaster;
    }

    arrange(mon);

    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

fn killunsel(arg: ?*const config.api.Arg) callconv(.c) void {
    _ = arg;
    std.debug.print("    killunsel: killing unselected clients\n", .{});

    if (selectedMonitor == null or selectedMonitor.?.selected == null) return;

    var i_opt = selectedMonitor.?.clients;
    while (i_opt) |i| {
        const next = i.next;
        if (isVisible(i) and i != selectedMonitor.?.selected) {
            std.debug.print("    killunsel: killing client 0x{x}\n", .{i.window});
            if (sendevent(i, wmatom[@intFromEnum(WMAtom.WMDelete)]) == 0) {
                _ = x11.XGrabServer(display);
                _ = x11.XSetErrorHandler(@ptrCast(&xerrordummy));
                _ = x11.XSetCloseDownMode(display, x11.DestroyAll);
                _ = x11.XKillClient(display, i.window);
                _ = x11.XSync(display, x11.False);
                _ = x11.XSetErrorHandler(@ptrCast(&xError));
                _ = x11.XUngrabServer(display);
            }
        }
        i_opt = next;
    }
}

fn pop(client: *Client) void {
    std.debug.print("    pop: popping client 0x{x}\n", .{client.window});
    detach(client);
    attach(client);
    focus(client);
    arrange(client.monitor);
}

fn prevTiled(client: *Client) ?*Client {
    std.debug.print("    prevtiled: finding prev tiled before 0x{x}\n", .{client.window});
    var p_opt = selectedMonitor.?.clients;
    var r: ?*Client = null;

    while (p_opt) |p| : (p_opt = p.next) {
        if (p == client) break;
        if (p.isFloating == .False and isVisible(p))
            r = p;
    }

    if (r) |result| {
        std.debug.print("    prevtiled: found 0x{x}\n", .{result.window});
    }
    return r;
}

fn movestack(arg: ?*const config.api.Arg) callconv(.c) void {
    const a = arg orelse return;
    std.debug.print("    movestack: direction={d}\n", .{a.i});

    if (selectedMonitor == null or selectedMonitor.?.selected == null) return;
    const sel = selectedMonitor.?.selected.?;

    var target: ?*Client = null;
    var p: ?*Client = null;
    var pc: ?*Client = null;

    if (a.i > 0) {
        target = sel.next;
        while (target != null and (!isVisible(target.?) or target.?.isFloating != .False)) {
            target = target.?.next;
        }
        if (target == null) {
            target = selectedMonitor.?.clients;
            while (target != null and (!isVisible(target.?) or target.?.isFloating != .False)) {
                target = target.?.next;
            }
        }
    } else {
        var i_opt = selectedMonitor.?.clients;
        while (i_opt != null and i_opt != sel) : (i_opt = i_opt.?.next) {
            if (isVisible(i_opt.?) and i_opt.?.isFloating == .False)
                target = i_opt;
        }
        if (target == null) {
            while (i_opt != null) : (i_opt = i_opt.?.next) {
                if (isVisible(i_opt.?) and i_opt.?.isFloating == .False)
                    target = i_opt;
            }
        }
    }

    var i_opt = selectedMonitor.?.clients;
    while (i_opt != null and (p != null or pc != null)) : (i_opt = i_opt.?.next) {
        if (i_opt.?.next == sel)
            p = i_opt;
        if (i_opt.?.next == target)
            pc = i_opt;
    }

    if (target != null and target != sel) {
        std.debug.print("    movestack: swapping 0x{x} and 0x{x}\n", .{ sel.window, target.?.window });
        const temp = if (sel.next == target) sel else sel.next;
        sel.next = if (target.?.next == sel) target else target.?.next;
        target.?.next = temp;

        if (p != null and p != target)
            p.?.next = target;
        if (pc != null and pc != sel)
            p.?.next = sel;

        if (sel == selectedMonitor.?.clients)
            selectedMonitor.?.clients = target
        else if (target == selectedMonitor.?.clients)
            selectedMonitor.?.clients = sel;

        arrange(selectedMonitor.?);
    }

    warp(null);
}

fn updateNumLockMask() void {
    numlockmask = 0;
    const modmap = x11.XGetModifierMapping(display);
    if (modmap == null) return;

    const map = modmap.?;
    defer _ = x11.XFreeModifiermap(map);

    var i: u32 = 0;
    while (i < 8) : (i += 1) {
        var j: u32 = 0;
        while (j < @as(u32, @intCast(map.max_keypermod))) : (j += 1) {
            const index: usize = @intCast(i * @as(u32, @intCast(map.max_keypermod)) + j);
            const keycode = map.modifiermap[index];
            const numlock_keycode = x11.XKeysymToKeycode(display, config.api.keys.XK_Num_Lock);
            if (keycode == numlock_keycode) {
                numlockmask = @as(u32, 1) << @as(u5, @intCast(i));
            }
        }
    }
}

fn grabKeys() void {
    updateNumLockMask();
    const modifiers = [_]u32{ 0, x11.LockMask, numlockmask, numlockmask | x11.LockMask };

    _ = x11.XUngrabKey(display, x11.AnyKey, x11.AnyModifier, rootWindow);

    var start: i32 = 0;
    var end: i32 = 0;
    _ = x11.XDisplayKeycodes(display, &start, &end);

    var skip: i32 = 0;
    const syms = x11.XGetKeyboardMapping(display, @intCast(start), end - start + 1, &skip);
    if (syms == null) return;

    var k: i32 = start;
    while (k <= end) : (k += 1) {
        for (config.keys) |key| {
            const idx: usize = @intCast((k - start) * skip);
            const syms_array: [*]x11.KeySym = @ptrCast(syms.?);
            if (key.keySym == syms_array[idx]) {
                for (modifiers) |mod| {
                    _ = x11.XGrabKey(display, k, key.modifiers | mod, rootWindow, x11.True, x11.GrabModeAsync, x11.GrabModeAsync);
                }
            }
        }
    }

    _ = x11.XFree(syms.?);
}

fn dispatchKeyAction(key: *const config.api.Key) void {
    switch (key.action) {
        .none => {},
        .exitWindowManager => exitWindowManager(&key.actionArg),
        .closeClient => closeClient(&key.actionArg),
        .spawnCommand => spawnCommand(&key.actionArg),
        .setLayout => setLayout(&key.actionArg),
        .promoteToMaster => promoteToMaster(&key.actionArg),
        .viewTagMask => viewTagMask(&key.actionArg),
        .adjustMasterAreaFactor => adjustMasterAreaFactor(&key.actionArg),
    }
}

fn keypress(e: *x11.XEvent) callconv(.c) void {
    const ev = &e.xkey;

    if (ev.type != x11.KeyPress) {
        return;
    }

    const keysym = x11.XKeycodeToKeysym(display, @intCast(ev.keycode), 0);
    std.debug.print("\n⌨ KEYPRESS: keysym=0x{x}, keycode={d}, state=0x{x}\n", .{ keysym, ev.keycode, ev.state });

    const clean_state = cleanMask(@intCast(ev.state));
    for (config.keys) |key| {
        const clean_mod = cleanMask(key.modifiers);

        if (keysym == key.keySym and clean_mod == clean_state) {
            std.debug.print("✓ KEY MATCHED! Executing action {s}\n", .{@tagName(key.action)});
            dispatchKeyAction(&key);
            return;
        }
    }
    std.debug.print("✗ No key binding matched\n", .{});
}

pub fn exitWindowManager(arg: ?*const config.api.Arg) callconv(.c) void {
    _ = arg;
    running = 0;
}

pub fn closeClient(arg: ?*const config.api.Arg) callconv(.c) void {
    _ = arg;
    if (selectedMonitor == null or selectedMonitor.?.selected == null) return;

    const client = selectedMonitor.?.selected.?;
    if (sendevent(client, wmatom[@intFromEnum(WMAtom.WMDelete)]) == 0) {
        _ = x11.XGrabServer(display);
        _ = x11.XSetErrorHandler(@ptrCast(&xerrordummy));
        _ = x11.XSetCloseDownMode(display, x11.DestroyAll);
        _ = x11.XKillClient(display, client.window);
        _ = x11.XSync(display, x11.False);
        _ = x11.XSetErrorHandler(@ptrCast(&xError));
        _ = x11.XUngrabServer(display);
    }
}

fn sendevent(client: *Client, proto: x11.Atom) i32 {
    var n: i32 = 0;
    var protocols: [*]x11.Atom = undefined;
    var exists: i32 = 0;
    var ev: x11.XEvent = undefined;

    if (x11.XGetWMProtocols(display, client.window, @ptrCast(&protocols), &n) != 0) {
        while (exists == 0 and n > 0) {
            n -= 1;
            if (protocols[@intCast(n)] == proto) {
                exists = 1;
            }
        }
        _ = x11.XFree(protocols);
    }

    if (exists != 0) {
        ev.type = x11.ClientMessage;
        ev.xclient.window = client.window;
        ev.xclient.message_type = wmatom[@intFromEnum(WMAtom.WMProtocols)];
        ev.xclient.format = 32;
        ev.xclient.data.l[0] = @intCast(proto);
        ev.xclient.data.l[1] = x11.CurrentTime;
        _ = x11.XSendEvent(display, client.window, x11.False, x11.NoEventMask, @ptrCast(&ev));
    }

    return exists;
}

fn xerrordummy(dpy: *x11.Display, errorEvent: *anyopaque) callconv(.c) c_int {
    _ = dpy;
    _ = errorEvent;
    return 0;
}

fn attach(client: *Client) void {
    client.next = client.monitor.clients;
    client.monitor.clients = client;
}

fn attachtop(client: *Client) void {
    var n: i32 = 1;
    const m = client.monitor;
    var below_opt: ?*Client = client.monitor.clients;

    while (below_opt) |below| {
        const is_floating = below.isFloating != .False;
        const is_visible_tag = isVisibleOnTag(below, client.tags);
        if (below.next == null or (!is_floating and is_visible_tag and n == m.masterCount)) {
            break;
        }
        n = if (is_floating or !is_visible_tag) n else n + 1;
        below_opt = below.next;
    }

    client.next = null;
    if (below_opt) |below| {
        client.next = below.next;
        below.next = client;
    } else {
        attach(client);
    }
}

fn detach(client: *Client) void {
    var tc_opt = &client.monitor.clients;
    while (tc_opt.*) |tc| {
        if (tc == client) {
            tc_opt.* = client.next;
            break;
        }
        tc_opt = &tc.next;
    }
}

fn attachStack(client: *Client) void {
    client.snext = client.monitor.stack;
    client.monitor.stack = client;
}

fn detachStack(client: *Client) void {
    var tc_opt = &client.monitor.stack;
    while (tc_opt.*) |tc| {
        if (tc == client) {
            tc_opt.* = client.snext;
            break;
        }
        tc_opt = &tc.snext;
    }

    if (client == client.monitor.selected) {
        var t_opt = client.monitor.stack;
        while (t_opt) |t| : (t_opt = t.snext) {
            if (isVisible(t)) {
                client.monitor.selected = t;
                break;
            }
        }
    }
}

fn windowToClient(w: x11.Window) ?*Client {
    var m_opt = monitors;
    while (m_opt) |m| : (m_opt = m.next) {
        var c_opt = m.clients;
        while (c_opt) |c_ptr| : (c_opt = c_ptr.next) {
            if (c_ptr.window == w) {
                return c_ptr;
            }
        }
    }
    return null;
}

fn windowToMonitor(w: x11.Window) ?*Monitor {
    if (w == rootWindow) {
        var x: i32 = 0;
        var y: i32 = 0;
        if (getRootPtr(&x, &y) != 0) {
            return rectToMon(x, y, 1, 1);
        }
    }

    var m_opt = monitors;
    while (m_opt) |m| : (m_opt = m.next) {
        if (w == m.barWindow) {
            return m;
        }
    }

    if (windowToClient(w)) |client| {
        return client.monitor;
    }

    return selectedMonitor;
}

fn unfocus(c_opt: ?*Client, setfocus_flag: i32) void {
    const client = c_opt orelse return;

    grabButtons(client, 0);
    _ = x11.XSetWindowBorder(display, client.window, scheme[config.normalScheme][2].pixel);

    if (setfocus_flag != 0) {
        _ = x11.XSetInputFocus(display, rootWindow, x11.RevertToPointerRoot, x11.CurrentTime);
        _ = x11.XDeleteProperty(display, rootWindow, netatom[@intFromEnum(NetAtom.NetActiveWindow)]);
    }
}

fn focus(c_opt: ?*Client) void {
    var target = c_opt;

    if (target == null or !isVisible(target.?)) {
        target = selectedMonitor.?.stack;
        while (target != null and !isVisible(target.?)) {
            target = target.?.snext;
        }
    }

    if (selectedMonitor.?.selected != null and selectedMonitor.?.selected != target) {
        unfocus(selectedMonitor.?.selected, 0);
    }

    if (target) |client| {
        if (client.monitor != selectedMonitor) {
            selectedMonitor = client.monitor;
        }
        if (client.isUrgent != .False) {
            setUrgent(client, 0);
        }
        detachStack(client);
        attachStack(client);
        grabButtons(client, 1);

        _ = x11.XSetWindowBorder(display, client.window, scheme[config.selectedScheme][2].pixel);
        setFocus(client);
    } else {
        _ = x11.XSetInputFocus(display, rootWindow, x11.RevertToPointerRoot, x11.CurrentTime);
        _ = x11.XDeleteProperty(display, rootWindow, netatom[@intFromEnum(NetAtom.NetActiveWindow)]);
    }
    selectedMonitor.?.selected = target;
    drawBars();
}

fn setFocus(client: *Client) void {
    if (client.neverFocus == .False) {
        _ = x11.XSetInputFocus(display, client.window, x11.RevertToPointerRoot, x11.CurrentTime);
        _ = x11.XChangeProperty(display, rootWindow, netatom[@intFromEnum(NetAtom.NetActiveWindow)], x11.XA_WINDOW, 32, x11.PropModeReplace, @ptrCast(&client.window), 1);
    }
    _ = sendevent(client, wmatom[@intFromEnum(WMAtom.WMTakeFocus)]);
}

fn setFullscreen(client: *Client, fullscreen: i32) void {
    std.debug.print("    setfullscreen: client 0x{x}, fullscreen={d}\n", .{ client.window, fullscreen });
    if (fullscreen != 0 and client.isFullscreen == .False) {
        std.debug.print("    setfullscreen: setting fullscreen mode\n", .{});
        _ = x11.XChangeProperty(display, client.window, netatom[@intFromEnum(NetAtom.NetWMState)], x11.XA_ATOM, 32, x11.PropModeReplace, @ptrCast(&netatom[@intFromEnum(NetAtom.NetWMFullscreen)]), 1);
        client.isFullscreen = .True;
        client.oldState = client.isFloating;
        client.oldBorderWidth = client.borderWidth;
        client.borderWidth = 0;
        client.isFloating = .True;
        resizeClient(client, client.monitor.monitorX, client.monitor.monitorY, client.monitor.monitorWidth, client.monitor.monitorHeight);
        _ = x11.XRaiseWindow(display, client.window);
    } else if (fullscreen == 0 and client.isFullscreen != .False) {
        std.debug.print("    setfullscreen: unsetting fullscreen mode\n", .{});
        const empty: [0]u8 = undefined;
        _ = x11.XChangeProperty(display, client.window, netatom[@intFromEnum(NetAtom.NetWMState)], x11.XA_ATOM, 32, x11.PropModeReplace, &empty, 0);
        client.isFullscreen = .False;
        client.isFloating = client.oldState;
        client.borderWidth = client.oldBorderWidth;
        client.x = client.oldX;
        client.y = client.oldY;
        client.width = client.oldWidth;
        client.height = client.oldHeight;
        resizeClient(client, client.x, client.y, client.width, client.height);
        arrange(client.monitor);
    }
}

fn setUrgent(client: *Client, urg: i32) void {
    std.debug.print("    seturgent: client 0x{x}, urgent={d}\n", .{ client.window, urg });
    client.isUrgent = if (urg != 0) .True else .False;
    const wmh = x11.XGetWMHints(display, client.window);
    if (wmh == null) return;

    const hints: *x11.XWMHints = @ptrCast(@alignCast(wmh.?));
    if (urg != 0) {
        hints.flags |= x11.XUrgencyHint;
    } else {
        hints.flags &= ~x11.XUrgencyHint;
    }
    _ = x11.XSetWMHints(display, client.window, hints);
    _ = x11.XFree(wmh.?);
}

fn shouldGrabKey(client_opt: ?*Client, key: config.Key) i32 {
    std.debug.print("    shouldgrabkey: checking key 0x{x}\n", .{key.keySym});
    const client = client_opt orelse {
        std.debug.print("    shouldgrabkey: no client, grab=1\n", .{});
        return 1;
    };

    for (config.keyrules) |kr| {
        const title_match = if (kr.title) |title| std.mem.indexOf(u8, &client.name, std.mem.span(title)) != null else true;
        const mod_match = (kr.modifiers == config.AnyModifier or kr.modifiers == key.modifiers);
        const key_match = (kr.keySym == 0 or kr.keySym == key.keySym); // 0 = AnyKey

        if (title_match and mod_match and key_match) {
            std.debug.print("    shouldgrabkey: matched rule, grab=0\n", .{});
            return 0;
        }
    }

    std.debug.print("    shouldgrabkey: no match, grab=1\n", .{});
    return 1;
}

fn checkOtherWM() void {
    xerrorxlib = x11.XSetErrorHandler(@ptrCast(&xErrorStart));
    // This causes an error if some other window manager is running
    _ = x11.XSelectInput(display, @intCast(x11.defaultRootWindow(display)), x11.SubstructureRedirectMask);
    _ = x11.XSync(display, x11.False);
    _ = x11.XSetErrorHandler(@ptrCast(&xError));
    _ = x11.XSync(display, x11.False);
}

fn setup() !void {
    var sa = std.mem.zeroInit(x11.struct_sigaction, .{});
    _ = x11.sigemptyset(&sa.sa_mask);
    sa.sa_flags = x11.SA_NOCLDSTOP | x11.SA_NOCLDWAIT | x11.SA_RESTART;
    sa.__sigaction_handler = .{ .sa_handler = x11.SIG_IGN };
    _ = x11.sigaction(x11.SIGCHLD, &sa, null);

    while (x11.waitpid(-1, null, x11.WNOHANG) > 0) {}

    if (x11.clock_gettime(x11.CLOCK_MONOTONIC, &starttime) != 0) {
        return error.ClockGetTimeFailed;
    }

    config.layouts[0].arrange = col;
    config.layouts[2].arrange = bstack;
    config.layouts[3].arrange = gaplessGrid;

    config.buttons[0].func = moveMouse; // MODKEY + Button1
    config.buttons[1].func = resizeMouse; // MODKEY + Button3

    handler[@intCast(x11.ButtonPress)] = buttonPress;
    handler[@intCast(x11.ClientMessage)] = clientMessage;
    handler[@intCast(x11.ConfigureRequest)] = configureRequest;
    handler[@intCast(x11.ConfigureNotify)] = configureNotify;
    handler[@intCast(x11.DestroyNotify)] = destroyNotify;
    handler[@intCast(x11.EnterNotify)] = enterNotify;
    handler[@intCast(x11.Expose)] = expose;
    handler[@intCast(x11.FocusIn)] = focusin;
    handler[@intCast(x11.KeyPress)] = keypress;
    handler[@intCast(x11.MappingNotify)] = mappingNotify;
    handler[@intCast(x11.MapRequest)] = mapRequest;
    handler[@intCast(x11.MotionNotify)] = motionNotify;
    handler[@intCast(x11.PropertyNotify)] = propertyNotify;
    handler[@intCast(x11.UnmapNotify)] = unmapNotify;

    screen = x11.XDefaultScreen(display);
    screenWidth = x11.XDisplayWidth(display, screen);
    screenHeight = x11.XDisplayHeight(display, screen);
    rootWindow = x11.XRootWindow(display, screen);

    drw_state = drw.drwCreate(display, screen, rootWindow, @intCast(screenWidth), @intCast(screenHeight));
    if (drw_state == null) {
        util.die("cannot create drawing context", .{});
    }

    const fonts_slice = &config.fonts;
    if (drw.drwFontsetCreate(drw_state, fonts_slice) == null) {
        util.die("no fonts could be loaded.", .{});
    }

    leftRightPadding = @intCast(drw_state.?.fonts.?.height);
    barHeight = @intCast(drw_state.?.fonts.?.height + 2);

    _ = updateGeom();

    const utf8string = x11.XInternAtom(display, "UTF8_STRING", x11.False);
    wmatom[@intFromEnum(WMAtom.WMProtocols)] = x11.XInternAtom(display, "WM_PROTOCOLS", x11.False);
    wmatom[@intFromEnum(WMAtom.WMDelete)] = x11.XInternAtom(display, "WM_DELETE_WINDOW", x11.False);
    wmatom[@intFromEnum(WMAtom.WMState)] = x11.XInternAtom(display, "WM_STATE", x11.False);
    wmatom[@intFromEnum(WMAtom.WMTakeFocus)] = x11.XInternAtom(display, "WM_TAKE_FOCUS", x11.False);
    netatom[@intFromEnum(NetAtom.NetActiveWindow)] = x11.XInternAtom(display, "_NET_ACTIVE_WINDOW", x11.False);
    netatom[@intFromEnum(NetAtom.NetSupported)] = x11.XInternAtom(display, "_NET_SUPPORTED", x11.False);
    netatom[@intFromEnum(NetAtom.NetWMName)] = x11.XInternAtom(display, "_NET_WM_NAME", x11.False);
    netatom[@intFromEnum(NetAtom.NetWMState)] = x11.XInternAtom(display, "_NET_WM_STATE", x11.False);
    netatom[@intFromEnum(NetAtom.NetWMCheck)] = x11.XInternAtom(display, "_NET_SUPPORTING_WM_CHECK", x11.False);
    netatom[@intFromEnum(NetAtom.NetWMFullscreen)] = x11.XInternAtom(display, "_NET_WM_STATE_FULLSCREEN", x11.False);
    netatom[@intFromEnum(NetAtom.NetWMWindowType)] = x11.XInternAtom(display, "_NET_WM_WINDOW_TYPE", x11.False);
    netatom[@intFromEnum(NetAtom.NetWMWindowTypeDialog)] = x11.XInternAtom(display, "_NET_WM_WINDOW_TYPE_DIALOG", x11.False);
    netatom[@intFromEnum(NetAtom.NetClientList)] = x11.XInternAtom(display, "_NET_CLIENT_LIST", x11.False);

    cursor[@intFromEnum(CursorType.normal)] = drw.drwCurCreate(drw_state, x11.XC_left_ptr);
    cursor[@intFromEnum(CursorType.resize)] = drw.drwCurCreate(drw_state, x11.XC_sizing);
    cursor[@intFromEnum(CursorType.move)] = drw.drwCurCreate(drw_state, x11.XC_fleur);

    const allocator = std.heap.c_allocator;
    const scheme_array = try allocator.alloc([*]drw.Clr, config.colors.len);
    for (config.colors, 0..) |color_set, i| {
        const color_slice: []const [*:0]const u8 = &[_][*:0]const u8{ color_set[0], color_set[1], color_set[2] };
        scheme_array[i] = drw.drwScmCreate(drw_state, color_slice).?;
    }
    scheme = scheme_array.ptr;

    updateBars();
    drawBars();
    updateStatus();

    wmcheckwin = x11.XCreateSimpleWindow(display, rootWindow, 0, 0, 1, 1, 0, 0, 0);
    _ = x11.XChangeProperty(display, wmcheckwin, netatom[@intFromEnum(NetAtom.NetWMCheck)], x11.XA_WINDOW, 32, x11.PropModeReplace, @ptrCast(&wmcheckwin), 1);
    _ = x11.XChangeProperty(display, wmcheckwin, netatom[@intFromEnum(NetAtom.NetWMName)], utf8string, 8, x11.PropModeReplace, @ptrCast("zwm"), 3);
    _ = x11.XChangeProperty(display, rootWindow, netatom[@intFromEnum(NetAtom.NetWMCheck)], x11.XA_WINDOW, 32, x11.PropModeReplace, @ptrCast(&wmcheckwin), 1);

    _ = x11.XChangeProperty(display, rootWindow, netatom[@intFromEnum(NetAtom.NetSupported)], x11.XA_ATOM, 32, x11.PropModeReplace, @ptrCast(&netatom), @intFromEnum(NetAtom.NetLast));
    _ = x11.XDeleteProperty(display, rootWindow, netatom[@intFromEnum(NetAtom.NetClientList)]);

    // Set root window attributes including cursor and event mask
    var wa = std.mem.zeroInit(x11.XSetWindowAttributes, .{});
    if (cursor[@intFromEnum(CursorType.normal)]) |normal_cursor| {
        wa.cursor = normal_cursor.cursor;
    }
    wa.event_mask = x11.SubstructureRedirectMask | x11.SubstructureNotifyMask |
        x11.ButtonPressMask | x11.PointerMotionMask | x11.EnterWindowMask |
        x11.LeaveWindowMask | x11.StructureNotifyMask | x11.PropertyChangeMask;

    _ = x11.XChangeWindowAttributes(display, rootWindow, x11.CWEventMask | x11.CWCursor, &wa);
    _ = x11.XSelectInput(display, rootWindow, wa.event_mask);

    grabKeys();
    focus(null);

    std.debug.print("zwm: setup complete\n", .{});
}

fn cleanup() void {
    // std.debug.print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{});
    std.debug.print("▶▶▶ CLEANUP: Starting cleanup\n", .{});

    const a = config.api.Arg{ .ui = ~@as(u32, 0) };
    const foo = config.api.Layout{ .symbol = "", .arrange = null };
    viewTagMask(&a);
    if (selectedMonitor) |mon| {
        mon.layouts[mon.selectedLayout] = &foo;
    }

    std.debug.print("    Unmanaging all windows\n", .{});
    var m_opt = monitors;
    while (m_opt) |m| : (m_opt = m.next) {
        while (m.stack) |s| {
            unmanage(s, 0);
        }
    }

    std.debug.print("    Ungrabbing keys\n", .{});
    _ = x11.XUngrabKey(display, x11.AnyKey, x11.AnyModifier, rootWindow);

    std.debug.print("    Cleaning up monitors\n", .{});
    while (monitors) |_| {
        cleanupMon(monitors.?);
    }

    std.debug.print("    Freeing cursors\n", .{});
    if (drw_state) |d| {
        for (0..@intFromEnum(CursorType.last)) |i| {
            if (cursor[i]) |cur| {
                drw.drwCurFree(d, cur);
            }
        }
    }

    std.debug.print("    Freeing color schemes\n", .{});
    for (0..config.colors.len) |i| {
        std.heap.c_allocator.free(scheme[i][0..3]);
    }
    std.heap.c_allocator.free(scheme[0..config.colors.len]);

    std.debug.print("    Destroying wmcheckwin\n", .{});
    _ = x11.XDestroyWindow(display, wmcheckwin);

    std.debug.print("    Freeing drawing context\n", .{});
    if (drw_state) |d| {
        drw.drwFree(d);
    }

    std.debug.print("    Cleaning up X resources\n", .{});
    _ = x11.XSync(display, x11.False);
    _ = x11.XSetInputFocus(display, x11.PointerRoot, x11.RevertToPointerRoot, x11.CurrentTime);
    _ = x11.XDeleteProperty(display, rootWindow, netatom[@intFromEnum(NetAtom.NetActiveWindow)]);

    std.debug.print("▶▶▶ CLEANUP: Complete\n", .{});
    // std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});
}

pub fn main() !void {
    std.debug.print("zwm - Zig Window Manager\n", .{});

    const args = std.os.argv;
    if (args.len > 1 and std.mem.eql(u8, std.mem.span(args[1]), "-v")) {
        std.debug.print("zwm-1.0\n", .{});
        return;
    }

    if (args.len > 2) {
        std.debug.print("usage: zwm [-v] [display]\n", .{});
        std.debug.print("  -v       Show version\n", .{});
        std.debug.print("  display  X display to use (e.g., :0, :1)\n", .{});
        return error.InvalidArguments;
    }

    const display_name: ?[*:0]const u8 = if (args.len == 2) args[1] else null;

    _ = x11.setlocale(x11.LC_CTYPE, "");

    const maybe_dpy = x11.XOpenDisplay(display_name);
    if (maybe_dpy == null) {
        util.die("zwm: cannot open display", .{});
    }
    display = maybe_dpy.?;

    checkOtherWM();

    try setup();

    std.debug.print("✓ CHECKPOINT 5: X11 initialized successfully\n", .{});
    std.debug.print("   - Display: 0x{x}\n", .{@intFromPtr(display)});
    std.debug.print("   - Screen: {d}x{d}\n", .{ screenWidth, screenHeight });
    std.debug.print("   - Root window: 0x{x}\n", .{rootWindow});
    std.debug.print("✓ CHECKPOINT 6: Event loop ready\n", .{});
    std.debug.print("   - {d} event handlers registered\n", .{15});
    std.debug.print("✓ CHECKPOINT 7: Window management ready\n", .{});
    if (selectedMonitor) |m| {
        std.debug.print("   - Monitor: {d}x{d} at ({d},{d})\n", .{ m.monitorWidth, m.monitorHeight, m.monitorX, m.monitorY });
    }
    std.debug.print("   - {d} management functions implemented\n", .{12});
    std.debug.print("✓ CHECKPOINT 8: Layout functions ready\n", .{});
    std.debug.print("   - {d} layout algorithms (col, bstack, grid)\n", .{3});
    std.debug.print("✓ CHECKPOINT 9: User interaction ready\n", .{});
    std.debug.print("   - spawnCommand, viewTagMask, tag, promoteToMaster, setLayout implemented\n", .{});
    std.debug.print("   - Main event loop ready\n", .{});

    std.debug.print("\n✨ Window manager initialization COMPLETE!\n", .{});
    std.debug.print("Starting event loop...\n", .{});

    scan();

    run();

    std.debug.print("\nShutting down zwm...\n", .{});

    cleanup();
    _ = x11.XCloseDisplay(display);
}
