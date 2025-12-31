// See LICENSE file for copyright and license details.
const std = @import("std");

pub fn die(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print(fmt ++ "\n", args);
    std.process.exit(1);
}

pub fn ecalloc(allocator: std.mem.Allocator, comptime T: type, n: usize) ![]T {
    const slice = try allocator.alloc(T, n);
    const bytes: [*]u8 = @ptrCast(slice.ptr);
    @memset(bytes[0..(n * @sizeOf(T))], 0);
    return slice;
}

pub fn ecallocOne(comptime T: type) !*T {
    const ptr = try std.heap.c_allocator.create(T);
    const bytes: [*]u8 = @ptrCast(ptr);
    @memset(bytes[0..@sizeOf(T)], 0);
    return ptr;
}

pub inline fn max(a: anytype, b: anytype) @TypeOf(a, b) {
    return if (a > b) a else b;
}

pub inline fn min(a: anytype, b: anytype) @TypeOf(a, b) {
    return if (a < b) a else b;
}

pub inline fn between(x: anytype, a: anytype, b: anytype) bool {
    return (a <= x and x <= b);
}

pub inline fn length(array: anytype) usize {
    const info = @typeInfo(@TypeOf(array));
    return switch (info) {
        .array => |arr| arr.len,
        .pointer => |ptr| switch (ptr.size) {
            .One => switch (@typeInfo(ptr.child)) {
                .array => |arr| arr.len,
                else => @compileError("length requires array type"),
            },
            else => @compileError("length requires array type"),
        },
        else => @compileError("length requires array type"),
    };
}
