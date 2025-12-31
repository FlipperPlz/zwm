// See LICENSE file for copyright and license details.

const std = @import("std");
const util = @import("util.zig");
const x11 = @import("x11.zig");

const UTF_INVALID: u32 = 0xFFFD;

pub const foregroundColorIndex: usize = 0;
pub const backgroundColorIndex: usize = 1;
pub const borderColorIndex: usize = 2;

pub const Clr = x11.XftColor;

pub const Cur = struct {
    cursor: x11.Cursor,
};

pub const Fnt = struct {
    display: *x11.Display,
    height: u32,
    xftFont: *x11.XftFont,
    pattern: ?*x11.FcPattern,
    next: ?*Fnt,

    fn init(drw: *Drw, fontname: ?[*:0]const u8, fontpattern: ?*x11.FcPattern) ?*Fnt {
        var xfont: ?*x11.XftFont = null;
        var pattern: ?*x11.FcPattern = null;

        if (fontname) |name| {
            xfont = x11.XftFontOpenName(drw.display, drw.screen, name);
            if (xfont == null) {
                std.debug.print("error, cannot load font from name: '{s}'\n", .{name});
                return null;
            }
            pattern = x11.FcNameParse(@ptrCast(name));
            if (pattern == null) {
                std.debug.print("error, cannot parse font name to pattern: '{s}'\n", .{name});
                x11.XftFontClose(drw.display, xfont.?);
                return null;
            }
        } else if (fontpattern) |pat| {
            xfont = x11.XftFontOpenPattern(drw.display, pat);
            if (xfont == null) {
                std.debug.print("error, cannot load font from pattern.\n", .{});
                return null;
            }
        } else {
            util.die("no font specified.", .{});
        }

        const font = util.ecallocOne(Fnt) catch util.die("cannot allocate font", .{});
        font.xftFont = xfont.?;
        font.pattern = pattern;
        font.height = @intCast(xfont.?.ascent + xfont.?.descent);
        font.display = drw.display;
        font.next = null;

        return font;
    }

    pub fn initSet(drw: ?*Drw, fonts: []const [*:0]const u8) ?*Fnt {
        const d = drw orelse return null;
        if (fonts.len == 0) return null;

        var ret: ?*Fnt = null;
        var i: usize = 1;
        while (i <= fonts.len) : (i += 1) {
            if (d.init(fonts[fonts.len - i], null)) |cur| {
                cur.next = ret;
                ret = cur;
            }
        }
        d.fonts = ret;
        return ret;
    }

    pub fn deinitSet(font: ?*Fnt) void {
        if (font) |f| {
            f.next.deinitSet();
            f.deinit();
        }
    }

    fn deinit(font: ?*Fnt) void {
        if (font) |f| {
            if (f.pattern) |p| {
                x11.FcPatternDestroy(p);
            }
            x11.XftFontClose(f.display, f.xftFont);
            const allocator = std.heap.c_allocator;
            allocator.destroy(f);
        }
    }
};

pub const Drw = struct {
    width: u32,
    height: u32,
    display: *x11.Display,
    screen: i32,
    rootWindow: x11.Window,
    drawable: x11.Drawable,
    graphicsContext: *x11.GC,
    colorScheme: ?[*]Clr,
    fonts: ?*Fnt,



    pub fn drwCreate(dpy: *x11.Display, screen: i32, root: x11.Window, w: u32, h: u32) ?*Drw {
        const drw = util.ecallocOne(Drw) catch util.die("cannot allocate drw", .{});

        drw.display = dpy;
        drw.screen = screen;
        drw.rootWindow = root;
        drw.width = w;
        drw.height = h;
        drw.drawable = x11.XCreatePixmap(dpy, root, w, h, x11.XDefaultDepth(dpy, screen));
        drw.graphicsContext = x11.XCreateGC(dpy, root, 0, null) orelse {
            util.die("cannot create GC", .{});
        };
        _ = x11.XSetLineAttributes(dpy, drw.graphicsContext, 1, x11.LineSolid, x11.CapButt, x11.JoinMiter);
        drw.colorScheme = null;
        drw.fonts = null;

        return drw;
    }


};

fn utf8Decode(s_in: [*]const u8, u: *i64, err: *i32) i32 {
    const lens = [_]u8{
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 3, 3, 4, 0,
    };
    const leading_mask = [_]u8{ 0x7F, 0x1F, 0x0F, 0x07 };
    const overlong = [_]u32{ 0x0, 0x80, 0x0800, 0x10000 };

    const s = s_in;
    const len: i32 = @intCast(lens[s[0] >> 3]);
    u.* = UTF_INVALID;
    err.* = 1;
    if (len == 0)
        return 1;

    var cp: i64 = @intCast(s[0] & leading_mask[@as(usize, @intCast(len - 1))]);
    var i: i32 = 1;
    while (i < len) : (i += 1) {
        if (s[@intCast(i)] == 0 or (s[@intCast(i)] & 0xC0) != 0x80)
            return i;
        cp = (cp << 6) | @as(i64, @intCast(s[@intCast(i)] & 0x3F));
    }

    if (cp > 0x10FFFF or (cp >> 11) == 0x1B or cp < overlong[@as(usize, @intCast(len - 1))])
        return len;

    err.* = 0;
    u.* = cp;
    return len;
}







pub fn drwResize(drw: ?*Drw, w: u32, h: u32) void {
    const d = drw orelse return;

    d.width = w;
    d.height = h;
    if (d.drawable != 0) {
        _ = x11.XFreePixmap(d.display, d.drawable);
    }
    d.drawable = x11.XCreatePixmap(d.display, d.rootWindow, w, h, x11.XDefaultDepth(d.display, d.screen));
}

pub fn drwFree(drw: ?*Drw) void {
    const d = drw orelse return;
    _ = x11.XFreePixmap(d.display, d.drawable);
    _ = x11.XFreeGC(d.display, d.graphicsContext);
    dd(d.fonts);
    const allocator = std.heap.c_allocator;
    allocator.destroy(d);
}





pub fn drwClrCreate(drw: ?*Drw, dest: *Clr, clrname: [*:0]const u8) void {
    const d = drw orelse return;

    if (!x11.XftColorAllocName(
        d.display,
        x11.XDefaultVisual(d.display, d.screen),
        x11.XDefaultColormap(d.display, d.screen),
        clrname,
        dest,
    )) {
        util.die("error, cannot allocate color '{s}'", .{clrname});
    }
}

pub fn drwScmCreate(drw: ?*Drw, clrnames: []const [*:0]const u8) ?[*]Clr {
    const d = drw orelse return null;
    if (clrnames.len < 2) return null;

    const ret = util.ecalloc(std.heap.c_allocator, Clr, clrnames.len) catch util.die("cannot allocate colors", .{});
    for (clrnames, 0..) |name, i| {
        drwClrCreate(d, &ret[i], name);
    }
    return ret.ptr;
}

pub fn drwSetFontset(drw: ?*Drw, set: ?*Fnt) void {
    if (drw) |d| {
        d.fonts = set;
    }
}

pub fn drwSetScheme(drw: ?*Drw, scm: ?[*]Clr) void {
    if (drw) |d| {
        d.colorScheme = scm;
    }
}

pub fn drwRect(drw: ?*Drw, x: i32, y: i32, w: u32, h: u32, filled: i32, invert: i32) void {
    const d = drw orelse return;
    const scheme = d.colorScheme orelse return;

    const pixel = if (invert != 0) scheme[backgroundColorIndex].pixel else scheme[foregroundColorIndex].pixel;
    _ = x11.XSetForeground(d.display, d.graphicsContext, pixel);

    if (filled != 0) {
        _ = x11.XFillRectangle(d.display, d.drawable, d.graphicsContext, x, y, w, h);
    } else {
        _ = x11.XDrawRectangle(d.display, d.drawable, d.graphicsContext, x, y, w - 1, h - 1);
    }
}

pub fn drwText(
    drw: ?*Drw,
    x: i32,
    y: i32,
    w: u32,
    h: u32,
    lpad: u32,
    text: [*:0]const u8,
    invert: i32,
) i32 {
    const d = drw orelse return 0;
    const scheme = d.colorScheme orelse {
        if (x != 0 or y != 0 or w != 0 or h != 0) return 0;
        return 0;
    };
    const fonts = d.fonts orelse return 0;

    const render = (x != 0 or y != 0 or w != 0 or h != 0);
    var render_w = w;
    var render_x = x;

    var d_xft: ?*x11.XftDraw = null;

    const S = struct {
        var nomatches = [_]u32{0} ** 128;
        var ellipsis_width: u32 = 0;
        var invalid_width: u32 = 0;
    };
    const invalid = "�";

    if (!render) {
        render_w = if (invert != 0) @intCast(invert) else ~@as(u32, @intCast(invert));
    } else {
        const bg_pixel = if (invert != 0) scheme[foregroundColorIndex].pixel else scheme[backgroundColorIndex].pixel;
        _ = x11.XSetForeground(d.display, d.graphicsContext, bg_pixel);
        _ = x11.XFillRectangle(d.display, d.drawable, d.graphicsContext, x, y, w, h);
        if (w < lpad)
            return x + @as(i32, @intCast(w));

        d_xft = x11.XftDrawCreate(
            d.display,
            d.drawable,
            x11.XDefaultVisual(d.display, d.screen),
            x11.XDefaultColormap(d.display, d.screen),
        );
        render_x += @intCast(lpad);
        render_w -= lpad;
    }

    var usedfont: *Fnt = fonts;
    if (S.ellipsis_width == 0 and render) {
        S.ellipsis_width = drwFontsetGetWidth(d, "...");
    }
    if (S.invalid_width == 0 and render) {
        S.invalid_width = drwFontsetGetWidth(d, invalid);
    }

    var text_ptr: [*]const u8 = @ptrCast(text);
    var overflow: i32 = 0;

    while (true) {
        var ew: u32 = 0;
        var ellipsis_x: i32 = 0;
        var ellipsis_w: u32 = 0;
        var ellipsis_len: i32 = 0;
        var utf8strlen: i32 = 0;
        const utf8str = text_ptr;
        var nextfont: ?*Fnt = null;

        while (text_ptr[0] != 0) {
            var utf8codepoint: i64 = 0;
            var utf8err: i32 = 0;
            const utf8charlen = utf8Decode(text_ptr, &utf8codepoint, &utf8err);

            var charexists: i32 = 0;
            var curfont_opt: ?*Fnt = fonts;
            while (curfont_opt) |curfont| : (curfont_opt = curfont.next) {
                charexists = if (x11.XftCharExists(d.display, curfont.xftFont, @intCast(utf8codepoint))) 1 else charexists;
                if (charexists != 0) {
                    var tmpw: u32 = 0;
                    drwFontGetExts(curfont, text_ptr, @intCast(utf8charlen), &tmpw, null);

                    if (ew + S.ellipsis_width <= render_w) {
                        ellipsis_x = render_x + @as(i32, @intCast(ew));
                        ellipsis_w = render_w - ew;
                        ellipsis_len = utf8strlen;
                    }

                    if (ew + tmpw > render_w) {
                        overflow = 1;
                        if (!render) {
                            render_x += @intCast(tmpw);
                        } else {
                            utf8strlen = ellipsis_len;
                        }
                    } else if (curfont == usedfont) {
                        text_ptr += @intCast(utf8charlen);
                        utf8strlen += if (utf8err != 0) 0 else utf8charlen;
                        ew += if (utf8err != 0) 0 else tmpw;
                    } else {
                        nextfont = curfont;
                    }
                    break;
                }
            }

            if (overflow != 0 or charexists == 0 or nextfont != null or utf8err != 0)
                break;
            charexists = 0;
        }

        if (utf8strlen > 0) {
            if (render) {
                const ty = y + @divTrunc(@as(i32, @intCast(h)) - @as(i32, @intCast(usedfont.height)), 2) + usedfont.xftFont.ascent;
                const fg_color = if (invert != 0) &scheme[backgroundColorIndex] else &scheme[foregroundColorIndex];
                x11.XftDrawStringUtf8(
                    d_xft.?,
                    fg_color,
                    usedfont.xftFont,
                    render_x,
                    ty,
                    @ptrCast(utf8str),
                    utf8strlen,
                );
            }
            render_x += @intCast(ew);
            render_w -= ew;
        }

        if (text_ptr[0] == 0 or overflow != 0) {
            break;
        } else if (nextfont) |nf| {
            usedfont = nf;
        } else {
            break;
        }
    }

    if (d_xft) |xft| {
        x11.XftDrawDestroy(xft);
    }

    return render_x + @as(i32, @intCast(if (render) render_w else 0));
}

pub fn drwMap(drw: ?*Drw, win: x11.Window, x: i32, y: i32, w: u32, h: u32) void {
    const d = drw orelse return;
    _ = x11.XCopyArea(d.display, d.drawable, win, d.graphicsContext, x, y, w, h, x, y);
    _ = x11.XSync(d.display, x11.False);
}

pub fn drwFontsetGetWidth(drw: ?*Drw, text: [*:0]const u8) u32 {
    const d = drw orelse return 0;
    if (d.fonts == null) return 0;
    return @intCast(drwText(d, 0, 0, 0, 0, 0, text, 0));
}

pub fn drwFontsetGetWidthClamp(drw: ?*Drw, text: [*:0]const u8, n: u32) u32 {
    var tmp: u32 = 0;
    if (drw) |d| {
        if (d.fonts != null and n != 0) {
            tmp = @intCast(drwText(d, 0, 0, 0, 0, 0, text, @intCast(n)));
        }
    }
    return util.min(n, tmp);
}

pub fn drwFontGetExts(font: ?*Fnt, text: [*]const u8, len: u32, w: ?*u32, h_out: ?*u32) void {
    const f = font orelse return;

    var ext: x11.XGlyphInfo = undefined;
    x11.XftTextExtentsUtf8(f.display, f.xftFont, @ptrCast(text), @intCast(len), &ext);
    if (w) |wp| {
        wp.* = @intCast(ext.xOff);
    }
    if (h_out) |hp| {
        hp.* = f.height;
    }
}

pub fn drwCurCreate(drw: ?*Drw, shape: i32) ?*Cur {
    const d = drw orelse return null;
    const cur = util.ecallocOne(Cur) catch util.die("cannot allocate cursor", .{});
    cur.cursor = x11.XCreateFontCursor(d.display, @intCast(shape));
    return cur;
}

pub fn drwCurFree(drw: ?*Drw, cursor: ?*Cur) void {
    const d = drw orelse return;
    const c = cursor orelse return;
    _ = x11.XFreeCursor(d.display, c.cursor);
    const allocator = std.heap.c_allocator;
    allocator.destroy(c);
}
