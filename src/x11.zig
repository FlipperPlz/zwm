const std = @import("std");

pub const Display = opaque {};
pub const Window = u64;
pub const Drawable = u64;
pub const Pixmap = u64;
pub const Cursor = u64;
pub const Colormap = u64;
pub const Visual = opaque {};
pub const GC = opaque {};
pub const Atom = u64;
pub const KeySym = u64;
pub const KeyCode = u8;
pub const Time = u64;

pub const Bool = bool;
pub const Status = i32;

pub const XftColor = extern struct {
    pixel: u64,
    color: extern struct {
        red: u16,
        green: u16,
        blue: u16,
        alpha: u16,
    },
};

pub const XftFont = extern struct {
    ascent: i32,
    descent: i32,
    height: i32,
    max_advance_width: i32,
    charset: ?*anyopaque,
    pattern: ?*anyopaque,
};
pub const XftDraw = opaque {};
pub const XftChar8 = u8;

pub const XftResult = enum(i32) {
    Match = 0,
    NoMatch = 1,
    TypeMismatch = 2,
    NoId = 3,
    _,
};

pub const FcPattern = opaque {};
pub const FcCharSet = opaque {};
pub const FcChar8 = u8;
pub const FcBool = bool;

pub const FcTrue: FcBool = true;
pub const FcFalse: FcBool = false;

pub const FC_CHARSET = "charset";
pub const FC_SCALABLE = "scalable";

pub const FcMatchPattern = 0;

pub const XGlyphInfo = extern struct {
    width: u16,
    height: u16,
    x: i16,
    y: i16,
    xOff: i16,
    yOff: i16,
};

pub const SubstructureRedirectMask: i64 = (1 << 20);
pub const SubstructureNotifyMask: i64 = (1 << 19);
pub const ButtonPressMask: i64 = (1 << 2);
pub const ButtonReleaseMask: i64 = (1 << 3);
pub const PointerMotionMask: i64 = (1 << 6);
pub const EnterWindowMask: i64 = (1 << 4);
pub const LeaveWindowMask: i64 = (1 << 5);
pub const StructureNotifyMask: i64 = (1 << 17);
pub const PropertyChangeMask: i64 = (1 << 22);
pub const KeyPressMask: i64 = (1 << 0);
pub const KeyReleaseMask: i64 = (1 << 1);
pub const FocusChangeMask: i64 = (1 << 21);
pub const ExposureMask: i64 = (1 << 15);

pub const ShiftMask: u32 = (1 << 0);
pub const LockMask: u32 = (1 << 1);
pub const ControlMask: u32 = (1 << 2);
pub const Mod1Mask: u32 = (1 << 3);
pub const Mod2Mask: u32 = (1 << 4);
pub const Mod3Mask: u32 = (1 << 5);
pub const Mod4Mask: u32 = (1 << 6);
pub const Mod5Mask: u32 = (1 << 7);

pub const LineSolid: i32 = 0;
pub const CapButt: i32 = 1;
pub const JoinMiter: i32 = 0;

pub const False: Bool = false;
pub const True: Bool = true;

pub const XC_left_ptr: u32 = 68;
pub const XC_sizing: u32 = 120;
pub const XC_fleur: u32 = 52;

pub const PropModeReplace: i32 = 0;
pub const PropModeAppend: i32 = 2;

pub const XA_STRING: Atom = 31;
pub const XA_WINDOW: Atom = 33;
pub const XA_WM_NAME: Atom = 39;
pub const XA_ATOM: Atom = 4;
pub const XA_WM_TRANSIENT_FOR: Atom = 68;
pub const XA_WM_NORMAL_HINTS: Atom = 40;
pub const XA_WM_HINTS: Atom = 35;

pub const RevertToParent: i32 = 2;
pub const RevertToPointerRoot: i32 = 1;
pub const RevertToNone: i32 = 0;
pub const CurrentTime: Time = 0;
pub const PointerRoot: Window = 1;

pub const CWX: u32 = (1 << 0);
pub const CWY: u32 = (1 << 1);
pub const CWWidth: u32 = (1 << 2);
pub const CWHeight: u32 = (1 << 3);
pub const CWBorderWidth: u32 = (1 << 4);
pub const CWSibling: u32 = (1 << 5);
pub const CWStackMode: u32 = (1 << 6);

pub const Below: i32 = 1;

pub const NotifyNormal: i32 = 0;
pub const NotifyInferior: i32 = 2;

pub const PropertyDelete: i32 = 1;

pub const ReplayPointer: i32 = 2;

pub const MappingKeyboard: i32 = 1;

pub extern "X11" fn XOpenDisplay(display_name: ?[*:0]const u8) ?*Display;
pub extern "X11" fn XDisplayString(display: *Display) ?[*:0]const u8;
pub extern "X11" fn XDefaultScreen(display: *Display) i32;
pub extern "X11" fn XRootWindow(display: *Display, screen_number: i32) Window;
pub extern "X11" fn XDefaultDepth(display: *Display, screen_number: i32) i32;
pub extern "X11" fn XDefaultVisual(display: *Display, screen_number: i32) *Visual;
pub extern "X11" fn XDefaultColormap(display: *Display, screen_number: i32) Colormap;
pub extern "X11" fn XCreatePixmap(display: *Display, drawable: Drawable, width: u32, height: u32, depth: i32) Pixmap;
pub extern "X11" fn XFreePixmap(display: *Display, pixmap: Pixmap) i32;
pub extern "X11" fn XCreateGC(display: *Display, drawable: Drawable, valuemask: u64, values: ?*anyopaque) ?*GC;
pub extern "X11" fn XFreeGC(display: *Display, gc: *GC) i32;
pub extern "X11" fn XSetLineAttributes(display: *Display, gc: *GC, line_width: u32, line_style: i32, cap_style: i32, join_style: i32) i32;
pub extern "X11" fn XSetForeground(display: *Display, gc: *GC, foreground: u64) i32;
pub extern "X11" fn XFillRectangle(display: *Display, drawable: Drawable, gc: *GC, x: i32, y: i32, width: u32, height: u32) i32;
pub extern "X11" fn XDrawRectangle(display: *Display, drawable: Drawable, gc: *GC, x: i32, y: i32, width: u32, height: u32) i32;
pub extern "X11" fn XCopyArea(display: *Display, src: Drawable, dest: Drawable, gc: *GC, src_x: i32, src_y: i32, width: u32, height: u32, dest_x: i32, dest_y: i32) i32;
pub extern "X11" fn XSync(display: *Display, discard: Bool) i32;
pub extern "X11" fn XCreateFontCursor(display: *Display, shape: u32) Cursor;
pub extern "X11" fn XFreeCursor(display: *Display, cursor: Cursor) i32;
pub extern "X11" fn XInternAtom(display: *Display, atom_name: [*:0]const u8, only_if_exists: Bool) Atom;
pub extern "X11" fn XCreateSimpleWindow(display: *Display, parent: Window, x: i32, y: i32, width: u32, height: u32, border_width: u32, border: u64, background: u64) Window;
pub extern "X11" fn XChangeProperty(display: *Display, w: Window, property: Atom, _type: Atom, format: i32, mode: i32, data: [*]const u8, nelements: i32) i32;
pub extern "X11" fn XDeleteProperty(display: *Display, w: Window, property: Atom) i32;
pub extern "X11" fn XSelectInput(display: *Display, w: Window, event_mask: i64) i32;
pub extern "X11" fn XSetErrorHandler(handler: ?*const fn (*Display, *anyopaque) callconv(.c) i32) ?*const fn (*Display, *anyopaque) callconv(.c) i32;
pub extern "X11" fn XCloseDisplay(display: *Display) i32;
pub extern "X11" fn XDisplayWidth(display: *Display, screen_number: i32) i32;
pub extern "X11" fn XDisplayHeight(display: *Display, screen_number: i32) i32;
pub extern "X11" fn XSetInputFocus(display: *Display, focus: Window, revert_to: i32, time: Time) i32;
pub extern "X11" fn XMoveWindow(display: *Display, w: Window, x: i32, y: i32) i32;
pub extern "X11" fn XMoveResizeWindow(display: *Display, w: Window, x: i32, y: i32, width: u32, height: u32) i32;
pub extern "X11" fn XConfigureWindow(display: *Display, w: Window, value_mask: u32, values: *anyopaque) i32;
pub extern "X11" fn XNextEvent(display: *Display, event_return: *anyopaque) i32;
pub extern "X11" fn XPeekEvent(display: *Display, event_return: *anyopaque) i32;
pub extern "X11" fn XEventsQueued(display: *Display, mode: i32) i32;

pub const QueuedAlready: i32 = 0;
pub const QueuedAfterReading: i32 = 1;
pub const QueuedAfterFlush: i32 = 2;
pub extern "X11" fn XQueryTree(display: *Display, w: Window, root_return: *Window, parent_return: *Window, children_return: *[*]Window, nchildren_return: *u32) i32;
pub extern "X11" fn XGetWindowAttributes(display: *Display, w: Window, window_attributes_return: *anyopaque) i32;
pub extern "X11" fn XChangeWindowAttributes(display: *Display, w: Window, value_mask: u64, attributes: *const XSetWindowAttributes) i32;
pub extern "X11" fn XGetTransientForHint(display: *Display, w: Window, prop_window_return: *Window) i32;
pub extern "X11" fn XRaiseWindow(display: *Display, w: Window) i32;
pub extern "X11" fn XMapWindow(display: *Display, w: Window) i32;
pub extern "X11" fn XMapRaised(display: *Display, w: Window) i32;
pub extern "X11" fn XDefineCursor(display: *Display, w: Window, cursor: Cursor) i32;
pub extern "X11" fn XGrabKey(display: *Display, keycode: i32, modifiers: u32, grab_window: Window, owner_events: Bool, pointer_mode: i32, keyboard_mode: i32) i32;
pub extern "X11" fn XUngrabKey(display: *Display, keycode: i32, modifiers: u32, grab_window: Window) i32;
pub extern "X11" fn XGrabButton(display: *Display, button: u32, modifiers: u32, grab_window: Window, owner_events: Bool, event_mask: u32, pointer_mode: i32, keyboard_mode: i32, confine_to: Window, cursor: Cursor) i32;
pub extern "X11" fn XUngrabButton(display: *Display, button: u32, modifiers: u32, grab_window: Window) i32;
pub extern "X11" fn XKeycodeToKeysym(display: *Display, keycode: KeyCode, index: i32) KeySym;
pub extern "X11" fn XSetWindowBorder(display: *Display, w: Window, border_pixel: u64) i32;
pub extern "X11" fn XDisplayKeycodes(display: *Display, min_keycodes_return: *i32, max_keycodes_return: *i32) i32;
pub extern "X11" fn XGetKeyboardMapping(display: *Display, first_keycode: KeyCode, keycode_count: i32, keysyms_per_keycode_return: *i32) ?*KeySym;
pub const XModifierKeymap = extern struct {
    max_keypermod: i32,
    modifiermap: [*]KeyCode,
};

pub extern "X11" fn XGetModifierMapping(display: *Display) ?*XModifierKeymap;
pub extern "X11" fn XFreeModifiermap(modmap: *XModifierKeymap) i32;
pub extern "X11" fn XKeysymToKeycode(display: *Display, keysym: KeySym) KeyCode;
pub extern "X11" fn XSendEvent(display: *Display, w: Window, propagate: Bool, event_mask: i64, event_send: *anyopaque) i32;
pub extern "X11" fn XGrabServer(display: *Display) i32;
pub extern "X11" fn XUngrabServer(display: *Display) i32;
pub extern "X11" fn XSetCloseDownMode(display: *Display, close_mode: i32) i32;
pub extern "X11" fn XKillClient(display: *Display, resource: Window) i32;
pub extern "X11" fn XGetWMProtocols(display: *Display, w: Window, protocols_return: *[*]Atom, count_return: *i32) i32;
pub extern "X11" fn XGetWindowProperty(display: *Display, w: Window, property: Atom, long_offset: i64, long_length: i64, delete: Bool, req_type: Atom, actual_type_return: *Atom, actual_format_return: *i32, nitems_return: *u64, bytes_after_return: *u64, prop_return: *[*]u8) i32;
pub extern "X11" fn XWarpPointer(display: *Display, src_w: Window, dest_w: Window, src_x: i32, src_y: i32, src_width: u32, src_height: u32, dest_x: i32, dest_y: i32) i32;
pub extern "X11" fn XQueryPointer(display: *Display, w: Window, root_return: *Window, child_return: *Window, root_x_return: *i32, root_y_return: *i32, win_x_return: *i32, win_y_return: *i32, mask_return: *u32) i32;
pub extern "X11" fn XGrabPointer(display: *Display, grab_window: Window, owner_events: Bool, event_mask: u32, pointer_mode: i32, keyboard_mode: i32, confine_to: Window, cursor: Cursor, time: Time) i32;
pub extern "X11" fn XUngrabPointer(display: *Display, time: Time) i32;
pub extern "X11" fn XMaskEvent(display: *Display, event_mask: i64, event_return: *anyopaque) i32;
pub extern "X11" fn XCheckMaskEvent(display: *Display, event_mask: i64, event_return: *anyopaque) Bool;
pub extern "X11" fn XSetWMHints(display: *Display, w: Window, wmhints: *anyopaque) i32;
pub extern "X11" fn XGetTextProperty(display: *Display, w: Window, text_prop_return: *anyopaque, property: Atom) i32;
pub extern "X11" fn XAllowEvents(display: *Display, event_mode: i32, time: Time) i32;
pub extern "X11" fn XRefreshKeyboardMapping(event: *anyopaque) i32;
pub extern "X11" fn XUnmapWindow(display: *Display, w: Window) i32;
pub extern "X11" fn XDestroyWindow(display: *Display, w: Window) i32;

pub const IsViewable: i32 = 2;
pub const IsUnviewable: i32 = 1;
pub const IsUnmapped: i32 = 0;

pub const Success: i32 = 0;
pub const GrabSuccess: i32 = 0;

pub const Above: i32 = 0;

pub const GrabModeSync: i32 = 0;
pub const GrabModeAsync: i32 = 1;
pub const AnyKey: i32 = 0;
pub const AnyButton: u32 = 0;
pub const AnyModifier: u32 = (1 << 15);

pub const DestroyAll: i32 = 0;
pub const RetainPermanent: i32 = 1;
pub const RetainTemporary: i32 = 2;

pub const NoEventMask: i64 = 0;

pub const WithdrawnState: i64 = 0;
pub const NormalState: i64 = 1;
pub const IconicState: i64 = 3;

pub extern "Xft" fn XftColorAllocName(display: *Display, visual: *Visual, colormap: Colormap, name: [*:0]const u8, result: *XftColor) Bool;
pub extern "Xft" fn XftFontOpenName(display: *Display, screen: i32, name: [*:0]const u8) ?*XftFont;
pub extern "Xft" fn XftFontOpenPattern(display: *Display, pattern: *FcPattern) ?*XftFont;
pub extern "Xft" fn XftFontClose(display: *Display, font: *XftFont) void;
pub extern "Xft" fn XftCharExists(display: *Display, font: *XftFont, ucs4: u64) Bool;
pub extern "Xft" fn XftDrawCreate(display: *Display, drawable: Drawable, visual: *Visual, colormap: Colormap) ?*XftDraw;
pub extern "Xft" fn XftDrawDestroy(draw: *XftDraw) void;
pub extern "Xft" fn XftDrawStringUtf8(draw: *XftDraw, color: *const XftColor, font: *XftFont, x: i32, y: i32, string: [*]const XftChar8, len: i32) void;
pub extern "Xft" fn XftTextExtentsUtf8(display: *Display, font: *XftFont, string: [*]const XftChar8, len: i32, extents: *XGlyphInfo) void;
pub extern "Xft" fn XftFontMatch(display: *Display, screen: i32, pattern: *const FcPattern, result: *XftResult) ?*FcPattern;

pub extern "fontconfig" fn FcNameParse(name: [*:0]const FcChar8) ?*FcPattern;
pub extern "fontconfig" fn FcPatternDestroy(pattern: *FcPattern) void;
pub extern "fontconfig" fn FcPatternDuplicate(pattern: *const FcPattern) ?*FcPattern;
pub extern "fontconfig" fn FcPatternAddCharSet(pattern: *FcPattern, object: [*:0]const u8, charset: *FcCharSet) FcBool;
pub extern "fontconfig" fn FcPatternAddBool(pattern: *FcPattern, object: [*:0]const u8, b: FcBool) FcBool;
pub extern "fontconfig" fn FcConfigSubstitute(config: ?*anyopaque, pattern: *FcPattern, kind: i32) FcBool;
pub extern "fontconfig" fn FcDefaultSubstitute(pattern: *FcPattern) void;
pub extern "fontconfig" fn FcCharSetCreate() ?*FcCharSet;
pub extern "fontconfig" fn FcCharSetDestroy(charset: *FcCharSet) void;
pub extern "fontconfig" fn FcCharSetAddChar(charset: *FcCharSet, ucs4: u32) FcBool;

pub const XEvent = extern union {
    type: i32,
    xany: XAnyEvent,
    xkey: XKeyEvent,
    xbutton: XButtonEvent,
    xmotion: XMotionEvent,
    xcrossing: XCrossingEvent,
    xfocus: XFocusChangeEvent,
    xexpose: XExposeEvent,
    xgraphicsexpose: XGraphicsExposeEvent,
    xnoexpose: XNoExposeEvent,
    xvisibility: XVisibilityEvent,
    xcreatewindow: XCreateWindowEvent,
    xdestroywindow: XDestroyWindowEvent,
    xunmap: XUnmapEvent,
    xmap: XMapEvent,
    xmaprequest: XMapRequestEvent,
    xreparent: XReparentEvent,
    xconfigure: XConfigureEvent,
    xgravity: XGravityEvent,
    xresizerequest: XResizeRequestEvent,
    xconfigurerequest: XConfigureRequestEvent,
    xcirculate: XCirculateEvent,
    xcirculaterequest: XCirculateRequestEvent,
    xproperty: XPropertyEvent,
    xselectionclear: XSelectionClearEvent,
    xselectionrequest: XSelectionRequestEvent,
    xselection: XSelectionEvent,
    xcolormap: XColormapEvent,
    xclient: XClientMessageEvent,
    xmapping: XMappingEvent,
    xerror: XErrorEvent,
    xkeymap: XKeymapEvent,
    xgeneric: XGenericEvent,
    xcookies: XGenericEventCookie,
    pad: [24]i64,
};

pub const XAnyEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    window: Window,
};

pub const XKeyEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: i32,
    y: i32,
    x_root: i32,
    y_root: i32,
    state: u32,
    keycode: u32,
    same_screen: Bool,
};

pub const XButtonEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: i32,
    y: i32,
    x_root: i32,
    y_root: i32,
    state: u32,
    button: u32,
    same_screen: Bool,
};

pub const XMotionEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: i32,
    y: i32,
    x_root: i32,
    y_root: i32,
    state: u32,
    is_hint: u8,
    same_screen: Bool,
};

pub const XCrossingEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: i32,
    y: i32,
    x_root: i32,
    y_root: i32,
    mode: i32,
    detail: i32,
    same_screen: Bool,
    focus: Bool,
    state: u32,
};

pub const XFocusChangeEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    window: Window,
    mode: i32,
    detail: i32,
};

pub const XExposeEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    window: Window,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    count: i32,
};

pub const XGraphicsExposeEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    drawable: Drawable,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    minor_event: i32,
    count: i32,
    major_event: i32,
};

pub const XNoExposeEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    drawable: Drawable,
    minor_event: i32,
    major_event: i32,
};

pub const XVisibilityEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    window: Window,
    state: i32,
};

pub const XCreateWindowEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    parent: Window,
    window: Window,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    border_width: i32,
    override_redirect: Bool,
};

pub const XDestroyWindowEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    event: Window,
    window: Window,
};

pub const XUnmapEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    event: Window,
    window: Window,
    from_configure: Bool,
};

pub const XMapEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    event: Window,
    window: Window,
    override_redirect: Bool,
};

pub const XMapRequestEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    parent: Window,
    window: Window,
};

pub const XReparentEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    event: Window,
    window: Window,
    parent: Window,
    x: i32,
    y: i32,
    override_redirect: Bool,
};

pub const XConfigureEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    event: Window,
    window: Window,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    border_width: i32,
    above: Window,
    override_redirect: Bool,
};

pub const XGravityEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    event: Window,
    window: Window,
    x: i32,
    y: i32,
};

pub const XResizeRequestEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    window: Window,
    width: i32,
    height: i32,
};

pub const XConfigureRequestEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    parent: Window,
    window: Window,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    border_width: i32,
    above: Window,
    detail: i32,
    value_mask: u32,
};

pub const XCirculateEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    event: Window,
    window: Window,
    place: i32,
};

pub const XCirculateRequestEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    parent: Window,
    window: Window,
    place: i32,
};

pub const XPropertyEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    window: Window,
    atom: Atom,
    time: Time,
    state: i32,
};

pub const XSelectionClearEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    window: Window,
    selection: Atom,
    time: Time,
};

pub const XSelectionRequestEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    owner: Window,
    requestor: Window,
    selection: Atom,
    target: Atom,
    property: Atom,
    time: Time,
};

pub const XSelectionEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    requestor: Window,
    selection: Atom,
    target: Atom,
    property: Atom,
    time: Time,
};

pub const XColormapEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    window: Window,
    colormap: Colormap,
    new: Bool,
    state: i32,
};

pub const XClientMessageEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    window: Window,
    message_type: Atom,
    format: i32,
    data: extern union {
        b: [20]u8,
        s: [10]i16,
        l: [5]i64,
    },
};

pub const XMappingEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    window: Window,
    request: i32,
    first_keycode: i32,
    count: i32,
};

pub const XErrorEvent = extern struct {
    type: i32,
    display: *Display,
    resourceid: u64,
    serial: u64,
    error_code: u8,
    request_code: u8,
    minor_code: u8,
    pad: [21]u8,
};

pub const XKeymapEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    window: Window,
    key_vector: [32]u8,
};

pub const XGenericEvent = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    extension: i32,
    evtype: i32,
};

pub const XGenericEventCookie = extern struct {
    type: i32,
    serial: u64,
    send_event: Bool,
    display: *Display,
    extension: i32,
    evtype: i32,
    cookie: u32,
    data: *anyopaque,
};

pub const XWindowChanges = extern struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    border_width: i32,
    sibling: Window,
    stack_mode: i32,
};

pub const XWindowAttributes = extern struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    border_width: i32,
    depth: i32,
    visual: *Visual,
    root: Window,
    class: i32,
    bit_gravity: i32,
    win_gravity: i32,
    backing_store: i32,
    backing_planes: u64,
    backing_pixel: u64,
    save_under: Bool,
    colormap: Colormap,
    map_installed: Bool,
    map_state: i32,
    all_event_masks: i64,
    your_event_mask: i64,
    do_not_propagate_mask: i64,
    override_redirect: Bool,
    screen: *anyopaque,
};

pub const XClassHint = extern struct {
    res_name: ?[*:0]u8,
    res_class: ?[*:0]u8,
};

pub const XSizeHints = extern struct {
    flags: i64,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    min_width: i32,
    min_height: i32,
    max_width: i32,
    max_height: i32,
    width_inc: i32,
    height_inc: i32,
    min_aspect: extern struct { x: i32, y: i32 },
    max_aspect: extern struct { x: i32, y: i32 },
    base_width: i32,
    base_height: i32,
    win_gravity: i32,
};

pub const XWMHints = extern struct {
    flags: i64,
    input: Bool,
    initial_state: i32,
    icon_pixmap: Pixmap,
    icon_window: Window,
    icon_x: i32,
    icon_y: i32,
    icon_mask: Pixmap,
    window_group: Window,
};

pub const LASTEvent: i32 = 35;
pub const XUrgencyHint: i64 = 256;

pub const KeyPress: i32 = 2;
pub const KeyRelease: i32 = 3;
pub const ButtonPress: i32 = 4;
pub const ButtonRelease: i32 = 5;
pub const MotionNotify: i32 = 6;
pub const EnterNotify: i32 = 7;
pub const LeaveNotify: i32 = 8;
pub const FocusIn: i32 = 9;
pub const FocusOut: i32 = 10;
pub const KeymapNotify: i32 = 11;
pub const Expose: i32 = 12;
pub const GraphicsExpose: i32 = 13;
pub const NoExpose: i32 = 14;
pub const VisibilityNotify: i32 = 15;
pub const CreateNotify: i32 = 16;
pub const DestroyNotify: i32 = 17;
pub const UnmapNotify: i32 = 18;
pub const MapNotify: i32 = 19;
pub const MapRequest: i32 = 20;
pub const ReparentNotify: i32 = 21;
pub const ConfigureNotify: i32 = 22;
pub const ConfigureRequest: i32 = 23;
pub const GravityNotify: i32 = 24;
pub const ResizeRequest: i32 = 25;
pub const CirculateNotify: i32 = 26;
pub const CirculateRequest: i32 = 27;
pub const PropertyNotify: i32 = 28;
pub const SelectionClear: i32 = 29;
pub const SelectionRequest: i32 = 30;
pub const SelectionNotify: i32 = 31;
pub const ColormapNotify: i32 = 32;
pub const ClientMessage: i32 = 33;
pub const MappingNotify: i32 = 34;

pub const CWBackPixmap: u64 = (1 << 0);
pub const CWBackPixel: u64 = (1 << 1);
pub const CWBorderPixmap: u64 = (1 << 2);
pub const CWBorderPixel: u64 = (1 << 3);
pub const CWBitGravity: u64 = (1 << 4);
pub const CWWinGravity: u64 = (1 << 5);
pub const CWBackingStore: u64 = (1 << 6);
pub const CWBackingPlanes: u64 = (1 << 7);
pub const CWBackingPixel: u64 = (1 << 8);
pub const CWOverrideRedirect: u64 = (1 << 9);
pub const CWSaveUnder: u64 = (1 << 10);
pub const CWEventMask: u64 = (1 << 11);
pub const CWDontPropagate: u64 = (1 << 12);
pub const CWColormap: u64 = (1 << 13);
pub const CWCursor: u64 = (1 << 14);

pub const InputOutput: u32 = 1;
pub const InputOnly: u32 = 2;

pub const CopyFromParent: i32 = 0;

pub fn defaultDepth(display: *Display, screen_number: i32) i32 {
    return XDefaultDepth(display, screen_number);
}

pub fn defaultVisual(display: *Display, screen_number: i32) *Visual {
    return XDefaultVisual(display, screen_number);
}

pub fn defaultColormap(display: *Display, screen_number: i32) Colormap {
    return XDefaultColormap(display, screen_number);
}

pub const sigset_t = u64;
pub const siginfo_t = extern struct {
    si_signo: i32,
    si_errno: i32,
    si_code: i32,
    _pad: [29]i32,
};

pub const struct_timespec = extern struct {
    tv_sec: i64,
    tv_nsec: i64,
};

pub const struct_sigaction = extern struct {
    __sigaction_handler: extern union {
        sa_handler: ?*const fn (i32) callconv(.c) void,
        sa_sigaction: ?*const fn (i32, *siginfo_t, *anyopaque) callconv(.c) void,
    },
    sa_mask: sigset_t,
    sa_flags: i32,
    sa_restorer: ?*const fn () callconv(.c) void,
};

pub const SIGCHLD: i32 = 17;
pub const SIG_DFL: ?*const fn (i32) callconv(.c) void = @ptrFromInt(0);
pub const SIG_IGN: ?*const fn (i32) callconv(.c) void = @ptrFromInt(1);

pub extern "c" fn fork() i32;
pub extern "c" fn close(fd: i32) i32;
pub extern "c" fn setsid() i32;
pub extern "c" fn sigemptyset(set: *sigset_t) i32;
pub extern "c" fn sigaction(sig: i32, act: ?*const struct_sigaction, oact: ?*struct_sigaction) i32;
pub extern "c" fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: i32) i32;
pub extern "c" fn execvp(file: [*:0]const u8, argv: [*]const ?[*:0]const u8) i32;

pub extern "X11" fn XCreateWindow(display: *Display, parent: Window, x: i32, y: i32, width: u32, height: u32, border_width: u32, depth: i32, class: u32, visual: *Visual, valuemask: u64, attributes: *anyopaque) Window;
pub extern "X11" fn XGetClassHint(display: *Display, w: Window, class_hint_return: *XClassHint) Status;
pub extern "X11" fn XSetClassHint(display: *Display, w: Window, class_hint: *XClassHint) Status;
pub extern "X11" fn XGetWMNormalHints(display: *Display, w: Window, hints_return: *XSizeHints, supplied_return: *i64) Status;
pub extern "X11" fn XGetWMHints(display: *Display, w: Window) ?*XWMHints;

pub extern "c" fn setlocale(category: i32, locale: ?[*:0]const u8) ?[*:0]u8;
pub extern "c" fn clock_gettime(clockid: i32, tp: *struct_timespec) i32;

pub const LC_CTYPE: i32 = 0;

pub fn defaultRootWindow(display: *Display) Window {
    return XRootWindow(display, XDefaultScreen(display));
}

pub fn connectionNumber(display: *Display) i32 {
    return XConnectionNumber(display);
}

pub extern "X11" fn XConnectionNumber(display: *Display) i32;

pub const SA_NOCLDSTOP: i32 = 1;
pub const SA_NOCLDWAIT: i32 = 2;
pub const SA_RESTART: i32 = 4;

pub const WNOHANG: i32 = 1;

pub const CLOCK_MONOTONIC: i32 = 1;

pub extern "c" fn waitpid(pid: i32, status: ?*i32, options: i32) i32;

pub const PSize: i64 = 1;
pub const PBaseSize: i64 = 2;
pub const PMinSize: i64 = 4;
pub const PMaxSize: i64 = 16;
pub const PResizeInc: i64 = 8;
pub const PAspect: i64 = 32;
pub const InputHint: i64 = 1;

pub const ParentRelative: Pixmap = 1;

pub extern "X11" fn XmbTextPropertyToTextList(display: *Display, text_prop: *XTextProperty, list_return: *[*]?[*:0]u8, count_return: *i32) i32;
pub extern "X11" fn XFreeStringList(list: [*]?[*:0]u8) void;
pub extern "X11" fn XFree(data: ?*anyopaque) i32;

// Xinerama support
pub const XineramaScreenInfo = extern struct {
    screen_number: i32,
    x_org: i16,
    y_org: i16,
    width: i16,
    height: i16,
};

pub extern "Xinerama" fn XineramaIsActive(display: *Display) Bool;
pub extern "Xinerama" fn XineramaQueryScreens(display: *Display, number: *i32) ?[*]XineramaScreenInfo;

pub const XSetWindowAttributes = extern struct {
    background_pixmap: Pixmap,
    background_pixel: u64,
    border_pixmap: Pixmap,
    border_pixel: u64,
    bit_gravity: i32,
    win_gravity: i32,
    backing_store: i32,
    backing_planes: u64,
    backing_pixel: u64,
    save_under: Bool,
    event_mask: i64,
    do_not_propagate_mask: i64,
    override_redirect: Bool,
    colormap: Colormap,
    cursor: Cursor,
};

pub const XTextProperty = extern struct {
    value: [*]u8,
    encoding: Atom,
    format: i32,
    nitems: u64,
};
