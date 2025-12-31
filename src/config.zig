pub const api = @import("config_api.zig");

pub const borderpx: u32 = 1;
pub const snap: u32 = 32;

pub const showbar: api.Boolean = .True;
pub const topbar: api.Boolean = .True;
pub const bar_all_monitors: api.Boolean = .True;

pub const fonts = [_][*:0]const u8{"Terminus:size=8"};
pub const dmenufont: [*:0]const u8 = "Terminus:size=8";

pub const normbordercolor: [*:0]const u8 = "#073642";
pub const normbgcolor: [*:0]const u8 = "#002b36";
pub const normfgcolor: [*:0]const u8 = "#839496";
pub const selbordercolor: [*:0]const u8 = "#93a1a1";
pub const selbgcolor: [*:0]const u8 = "#839496";
pub const selfgcolor: [*:0]const u8 = "#002b36";

pub const mfact: f32 = 0.5;
pub const nmaster: i32 = 1;
pub const resizehints: i32 = 0;
pub const lockfullscreen: i32 = 0;

pub const colors = [_][3][*:0]const u8{
    [_][*:0]const u8{ normfgcolor, normbgcolor, normbordercolor },
    [_][*:0]const u8{ selfgcolor, selbgcolor, selbordercolor },
};

pub const normalScheme: usize = 0;
pub const selectedScheme: usize = 1;

pub const tags = [_][*:0]const u8{ "1", "2", "3", "4", "5", "6", "7" };

const pp_moni: [*:0]const u8 = "pdfpc - presenter";
const pp_proj: [*:0]const u8 = "pdfpc - presentation";

fn rule(comptime class_name: ?[*:0]const u8, comptime instance_name: ?[*:0]const u8, comptime title_pattern: ?[*:0]const u8, tags_mask: u32, comptime is_centered: bool, comptime is_floating: bool, comptime respect_period: bool, monitor_idx: i32) api.Rule {
    return .{
        .class = class_name,
        .instance = instance_name,
        .title = title_pattern,
        .tags = tags_mask,
        .isCentered = if (is_centered) .True else api.Boolean.False,
        .isFloating = if (is_floating) api.Boolean.True else api.Boolean.False,
        .respectPeriod = if (respect_period) api.Boolean.True else api.Boolean.False,
        .monitor = monitor_idx,
    };
}

pub const rules = [_]api.Rule{
    rule(null, null, "Scratch", 0, true, true, false, -1),
    rule(null, null, "mail", 1 << 3, false, false, true, -1),
    rule(null, null, "irc", 1 << 2, false, false, true, -1),
    rule(null, null, "mattermost", 1 << 2, false, false, true, -1),
    rule(null, null, pp_moni, 0, false, true, false, 2),
    rule(null, null, pp_proj, 0, false, true, false, 1),
    rule(null, "google-chrome", null, 1 << 1, false, false, true, -1),
};

pub const ruleperiod: i32 = 5;

pub const keyrules = [_]api.KeyRule{
    .{ .title = "QEMU", .modifiers = api.AnyModifier, .keySym = api.keys.XK_F10 },
};

pub const lm_rules = [_]api.LayoutMonitorRule{
    .{ .minWidth = 3000, .minHeight = 0, .requiredLayout = 0, .newMasterCount = 3, .newMasterFactor = 3.0 / 4.0 },
    .{ .minWidth = 2500, .minHeight = 0, .requiredLayout = 0, .newMasterCount = 2, .newMasterFactor = 2.0 / 3.0 },
};

const st_cmd = [_]?[*:0]const u8{ "st", null };
const xterm_cmd = [_]?[*:0]const u8{ "kitty", null };
const rofi_cmd = [_]?[*:0]const u8{ "dmenu_run", null };

pub var layouts: [4]api.Layout = [_]api.Layout{
    .{ .symbol = "|||", .arrange = null }, // col layout
    .{ .symbol = "><>", .arrange = null }, // floating (no layout)
    .{ .symbol = "TTT", .arrange = null }, // bstack layout
    .{ .symbol = "HHH", .arrange = null },
};

pub var keys: [12]api.Key = [_]api.Key{
    .{ .eventType = api.KeyPress, .modifiers = api.MODKEY | api.ShiftMask, .keySym = api.keys.XK_q, .action = .exitWindowManager, .actionArg = api.Arg.none() },
    .{ .eventType = api.KeyPress, .modifiers = api.MODKEY | api.ShiftMask, .keySym = api.keys.XK_c, .action = .closeClient, .actionArg = api.Arg.none() },
    .{ .eventType = api.KeyPress, .modifiers = api.MODKEY, .keySym = api.keys.XK_Return, .action = .spawnCommand, .actionArg = api.Arg.command(&xterm_cmd) },
    .{ .eventType = api.KeyPress, .modifiers = api.MODKEY | api.ShiftMask, .keySym = api.keys.XK_Return, .action = .spawnCommand, .actionArg = api.Arg.command(&st_cmd) },
    .{ .eventType = api.KeyPress, .modifiers = api.MODKEY, .keySym = api.keys.XK_d, .action = .spawnCommand, .actionArg = api.Arg.command(&rofi_cmd) },
    .{ .eventType = api.KeyPress, .modifiers = api.MODKEY, .keySym = api.keys.XK_space, .action = .setLayout, .actionArg = api.Arg.none() },
    .{ .eventType = api.KeyPress, .modifiers = api.MODKEY, .keySym = api.keys.XK_Tab, .action = .promoteToMaster, .actionArg = api.Arg.none() },
    .{ .eventType = api.KeyPress, .modifiers = api.MODKEY, .keySym = api.keys.XK_1, .action = .viewTagMask, .actionArg = api.Arg.tag(0) },
    .{ .eventType = api.KeyPress, .modifiers = api.MODKEY, .keySym = api.keys.XK_2, .action = .viewTagMask, .actionArg = api.Arg.tag(1) },
    .{ .eventType = api.KeyPress, .modifiers = api.MODKEY, .keySym = api.keys.XK_3, .action = .viewTagMask, .actionArg = api.Arg.tag(2) },
    .{ .eventType = api.KeyPress, .modifiers = api.MODKEY, .keySym = api.keys.XK_h, .action = .adjustMasterAreaFactor, .actionArg = api.Arg.factorDelta(-0.05) },
    .{ .eventType = api.KeyPress, .modifiers = api.MODKEY, .keySym = api.keys.XK_l, .action = .adjustMasterAreaFactor, .actionArg = api.Arg.factorDelta(0.05) },
};

pub var buttons: [2]api.Button = [_]api.Button{
    .{ .clickTarget = api.clickClientWindow, .modifiers = api.MODKEY, .mouseButton = api.Button1, .func = null, .actionArg = api.Arg.none() },
    .{ .clickTarget = api.clickClientWindow, .modifiers = api.MODKEY, .mouseButton = api.Button3, .func = null, .actionArg = api.Arg.none() },
};
