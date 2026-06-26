//! Replaces (infects) your c codes malloc and free (and friends)
//! with a zig allocator.
const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

pub const std_options: std.Options = .{
    .log_level = .err,
};
const log = std.log.scoped(.zalloc);

pub var io: ?std.Io = null;
pub var allocator: ?Allocator = null;

var mutex: std.Io.Mutex = .init;

const alignment = @alignOf(std.c.max_align_t);
const header_offset = std.mem.alignForward(usize, @sizeOf(usize), alignment);

export fn zmalloc(size: usize) callconv(.c) ?*align(alignment) anyopaque {
    mutex.lock(io.?) catch return null;
    defer mutex.unlock(io.?);

    if (allocator == null) {
        @branchHint(.unlikely);
        return null;
    }
    const gpa = allocator.?;

    if (size == 0) {
        return null;
    }

    if (gpa.alignedAlloc(u8, .fromByteUnits(alignment), size + header_offset)) |ptr| {
        @branchHint(.likely);
        return getPtr(@as([]align(alignment) u8, @ptrCast(@alignCast(ptr))), size);
    } else |err| {
        @branchHint(.unlikely);
        log.err("zmalloc: {t}", .{err});
        return null;
    }
}

export fn zrealloc(maybe_ptr: ?*anyopaque, new_size: usize) callconv(.c) ?*align(alignment) anyopaque {
    mutex.lock(io.?) catch return null;
    defer mutex.unlock(io.?);

    if (allocator == null) {
        @branchHint(.unlikely);
        return null;
    }
    const gpa = allocator.?;

    if (maybe_ptr) |ptr| {
        if (gpa.realloc(getSlice(anyopaqueToAlignedU8Ptr(ptr)), new_size + header_offset)) |slice| {
            @branchHint(.likely);
            return getPtr(@alignCast(slice), new_size);
        } else |err| {
            @branchHint(.unlikely);
            log.err("zrealloc: {t}", .{err});
        }
    } else {
        if (gpa.alignedAlloc(u8, .fromByteUnits(alignment), new_size + header_offset)) |slice| {
            @branchHint(.likely);
            return getPtr(@alignCast(slice), new_size);
        } else |err| {
            @branchHint(.unlikely);
            log.err("zrealloc: {t}", .{err});
        }
    }

    return null;
}

export fn zcalloc(num: usize, size: usize) callconv(.c) ?*align(alignment) anyopaque {
    mutex.lock(io.?) catch return null;
    defer mutex.unlock(io.?);

    if (allocator == null) {
        @branchHint(.unlikely);
        return null;
    }
    const gpa = allocator.?;

    if (gpa.alignedAlloc(u8, .fromByteUnits(alignment), num * size + header_offset)) |slice| {
        @branchHint(.likely);
        @memset(slice, 0);
        return getPtr(@alignCast(slice), num * size);
    } else |err| {
        @branchHint(.unlikely);
        log.err("zcalloc: {t}", .{err});
        return null;
    }
}

export fn zfree(maybe_ptr: ?*anyopaque) callconv(.c) void {
    mutex.lock(io.?) catch return;
    defer mutex.unlock(io.?);

    if (allocator) |gpa| {
        @branchHint(.likely);
        if (maybe_ptr) |ptr| {
            @branchHint(.likely);
            const slice = getSlice(anyopaqueToAlignedU8Ptr(ptr));
            gpa.free(slice);
        }
    }
}

inline fn anyopaqueToAlignedU8Ptr(ptr: *anyopaque) [*]align(alignment) u8 {
    return @ptrCast(@alignCast(ptr));
}

/// `ptr` is expected to have been created by `zmalloc`, `zrealloc` or `zcalloc`
/// calling this function otherwise will probably lead to seg fault
fn getSlice(ptr: [*]align(alignment) u8) []align(alignment) u8 {
    var slice: []align(alignment) u8 = undefined;
    slice.ptr = ptr - header_offset;
    const len_of_allocation = std.mem.bytesToValue(usize, slice.ptr[0..@sizeOf(usize)]);
    slice.len = len_of_allocation + header_offset;

    return slice;
}

/// sets the first bytes of the slice to the `size` of the allocation
fn getPtr(slice: []align(alignment) u8, size: usize) [*]align(alignment) u8 {
    @memcpy(slice[0..@sizeOf(usize)], std.mem.toBytes(size)[0..]);
    return slice.ptr + header_offset;
}

test "c free" {
    io = std.testing.io;
    allocator = std.testing.allocator;
    const test_free = @extern(*const fn () callconv(.c) c_int, .{ .name = "test_free" });
    try std.testing.expectEqual(0, test_free());
}

test "c malloc" {
    io = std.testing.io;
    allocator = std.testing.allocator;
    const test_malloc = @extern(*const fn () callconv(.c) c_int, .{ .name = "test_malloc" });
    try std.testing.expectEqual(0, test_malloc());
}

test "c realloc" {
    io = std.testing.io;
    allocator = std.testing.allocator;
    const test_realloc = @extern(*const fn () callconv(.c) c_int, .{ .name = "test_realloc" });
    try std.testing.expectEqual(0, test_realloc());
}

test "c calloc" {
    io = std.testing.io;
    allocator = std.testing.allocator;
    const test_calloc = @extern(*const fn () callconv(.c) c_int, .{ .name = "test_calloc" });
    try std.testing.expectEqual(0, test_calloc());
}

test "c threads" {
    io = std.testing.io;
    allocator = std.testing.allocator;
    const test_threading = @extern(*const fn (n_threds: c_int) callconv(.c) c_int, .{ .name = "test_threading" });
    try std.testing.expectEqual(0, test_threading(4));
}
