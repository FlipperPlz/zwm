const x11 = @import("x11.zig");
pub const keys = @import("keys.zig");

pub const Boolean = enum(i32) {
    False = 0,
    True = 1,
};

pub const Arg = union {
    i: i32,
    ui: u32,
    f: f32,
    v: ?*const anyopaque,

    pub fn none() Arg {
        return .{ .i = 0 };
    }

    pub fn int(value: i32) Arg {
        return .{ .i = value };
    }

    pub fn uint(value: u32) Arg {
        return .{ .ui = value };
    }

    pub fn float(value: f32) Arg {
        return .{ .f = value };
    }

    pub fn command(cmd: anytype) Arg {
        return .{ .v = @ptrCast(cmd) };
    }

    pub fn tagMask(mask: u32) Arg {
        return .{ .ui = mask };
    }

    pub fn tag(tag_index: u5) Arg {
        return .{ .ui = @as(u32, 1) << tag_index };
    }

    pub fn factorDelta(delta: f32) Arg {
        return .{ .f = delta };
    }

    pub fn layoutIndex(index: i32) Arg {
        return .{ .i = index };
    }

    pub fn pointer(ptr: *const anyopaque) Arg {
        return .{ .v = ptr };
    }
};

pub const Rule = struct {
    class: ?[*:0]const u8,
    instance: ?[*:0]const u8,
    title: ?[*:0]const u8,
    tags: u32,
    isCentered: Boolean,
    isFloating: Boolean,
    respectPeriod: Boolean,
    monitor: i32,
};

pub const KeyRule = struct {
    title: ?[*:0]const u8,
    modifiers: u32,
    keySym: x11.KeySym,
};

pub const LayoutFn = ?*const fn (?*anyopaque) callconv(.c) void;

pub const Layout = struct {
    symbol: [*:0]const u8,
    arrange: ?*const fn (?*anyopaque) callconv(.c) void,
};

pub const LayoutMonitorRule = struct {
    minWidth: i32,
    minHeight: i32,
    requiredLayout: i32,
    newMasterCount: i32,
    newMasterFactor: f32,
};

pub const KeyAction = enum(u8) {
    none,
    exitWindowManager,
    closeClient,
    spawnCommand,
    setLayout,
    promoteToMaster,
    viewTagMask,
    adjustMasterAreaFactor,
};

pub const Key = struct {
    eventType: i32,
    modifiers: u32,
    keySym: x11.KeySym,
    action: KeyAction,
    actionArg: Arg,
};

pub const Button = struct {
    clickTarget: u32,
    modifiers: u32,
    mouseButton: u32,
    func: ?*const fn (?*const Arg) callconv(.c) void,
    actionArg: Arg,
};

pub const KeyPress: i32 = 2;
pub const KeyRelease: i32 = 3;

pub const Button1: u32 = 1;
pub const Button2: u32 = 2;
pub const Button3: u32 = 3;
pub const Button4: u32 = 4;
pub const Button5: u32 = 5;

pub const clickTagBar: u32 = 0;
pub const clickLayoutSymbol: u32 = 1;
pub const clickStatusText: u32 = 2;
pub const clickWindowTitle: u32 = 3;
pub const clickClientWindow: u32 = 4;
pub const clickRootWindow: u32 = 5;

pub const AnyModifier: u32 = 1 << 15;
pub const TAGMASK: u32 = ((1 << 9) - 1);

pub const ShiftMask = x11.ShiftMask;
pub const ControlMask = x11.ControlMask;
pub const Mod1Mask = x11.Mod1Mask;
pub const Mod2Mask = x11.Mod2Mask;
pub const Mod3Mask = x11.Mod3Mask;
pub const Mod4Mask = x11.Mod4Mask;
pub const Mod5Mask = x11.Mod5Mask;
pub const LockMask = x11.LockMask;

pub const MODKEY = x11.Mod4Mask;
