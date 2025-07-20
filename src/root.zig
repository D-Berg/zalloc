//! Replaces (infects) your c codes malloc and free (and friends)
//! with a zig allocator.
const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
pub const std_options: std.Options = .{
    .log_level = .err,
};
const log = std.log.scoped(.zalloc);

pub var allocator: ?Allocator = null;

var mutex: std.Thread.Mutex = .{};

export fn zmalloc(size: usize) callconv(.c) ?[*]u8 {
    mutex.lock();
    defer mutex.unlock();

    if (allocator) |gpa| {
        if (gpa.alloc(u8, size + @sizeOf(usize))) |slice| {
            return getPtr(slice, size);
        } else |err| {
            log.err("malloc: {s}", .{@errorName(err)});
        }
    }
    return null;
}

export fn zrealloc(maybe_ptr: ?[*]u8, new_size: usize) callconv(.c) ?[*]u8 {
    mutex.lock();
    defer mutex.unlock();

    if (allocator) |gpa| {
        if (maybe_ptr) |ptr| {
            if (gpa.realloc(getSlice(ptr), new_size + @sizeOf(usize))) |slice| {
                return getPtr(slice, new_size);
            } else |err| {
                log.err("realloc: {s}", .{@errorName(err)});
            }
        } else {
            if (gpa.alloc(u8, new_size + @sizeOf(usize))) |slice| {
                return getPtr(slice, new_size);
            } else |err| {
                log.err("realloc: {s}", .{@errorName(err)});
            }
        }
    }

    return null;
}

export fn zcalloc(num: usize, size: usize) callconv(.c) ?[*]u8 {
    mutex.lock();
    defer mutex.unlock();

    if (allocator) |gpa| {
        if (gpa.alloc(u8, num * size + @sizeOf(usize))) |slice| {
            @memset(slice, 0);
            return getPtr(slice, num * size);
        } else |err| {
            log.err("zcalloc: {s}", .{@errorName(err)});
        }
    }

    return null;
}

export fn zfree(maybe_ptr: ?[*]u8) callconv(.c) void {
    mutex.lock();
    defer mutex.unlock();

    if (allocator) |gpa| {
        if (maybe_ptr) |ptr| {
            const slice = getSlice(ptr);
            gpa.free(slice);
        }
    }
}

/// `ptr` is expected to have been created by `zmalloc`, `zrealloc` or `zcalloc`
/// calling this function otherwise will probably lead to seg fault
fn getSlice(ptr: [*]u8) []u8 {
    var slice: []u8 = undefined;
    slice.ptr = ptr - @sizeOf(usize);
    const len_of_allocation = std.mem.bytesToValue(usize, slice.ptr[0..@sizeOf(usize)]);
    slice.len = len_of_allocation + @sizeOf(usize);

    return slice;
}

/// sets the first bytes of the slice to the `size` of the allocation
fn getPtr(slice: []u8, size: usize) [*]u8 {
    @memcpy(slice[0..@sizeOf(usize)], std.mem.toBytes(size)[0..]);
    return slice.ptr + @sizeOf(usize);
}

test "malloc and free" {
    allocator = std.testing.allocator;

    const ptr = zmalloc(10) orelse return error.NullPtr;
    defer zfree(ptr);

    var string: []u8 = undefined;
    string.ptr = ptr;
    string.len = 10;
    @memcpy(string[0..], "helloworld");

    try std.testing.expectEqualStrings("helloworld", string);
}

test "realloc" {
    // std.testing.log_level = .debug;
    allocator = std.testing.allocator;
    const ptr = zmalloc(10) orelse return error.NullPtr;

    const realloc_ptr = zrealloc(ptr, 20) orelse return error.NullPtr;
    defer zfree(realloc_ptr);
}

fn testMallocAndFree(id: u8) !void {
    const ptr = zmalloc(10) orelse return error.NullPtr;
    defer zfree(ptr);

    var string: []u8 = undefined;
    string.ptr = ptr;
    string.len = 10;
    @memcpy(string[0..10], "helloworld");

    log.debug("{s}{d}", .{ string, id });
}

test "multithreading" {
    // std.testing.log_level = .debug;
    const test_allocator = std.testing.allocator;
    allocator = test_allocator;
    var threads: [10]std.Thread = undefined;

    for (0..threads.len) |i| {
        threads[i] = try std.Thread.spawn(
            .{},
            testMallocAndFree,
            .{@as(u8, @intCast(i))},
        );
    }

    for (threads) |t| {
        t.join();
    }
}

test "c free" {
    allocator = std.testing.allocator;
    const test_free = @extern(*const fn () callconv(.c) c_int, .{ .name = "test_free" });
    try std.testing.expectEqual(0, test_free());
}

test "c malloc" {
    allocator = std.testing.allocator;
    const test_malloc = @extern(*const fn () callconv(.c) c_int, .{ .name = "test_malloc" });
    try std.testing.expectEqual(0, test_malloc());
}

test "c realloc" {
    allocator = std.testing.allocator;
    const test_realloc = @extern(*const fn () callconv(.c) c_int, .{ .name = "test_realloc" });
    try std.testing.expectEqual(0, test_realloc());
}

test "c calloc" {
    allocator = std.testing.allocator;
    const test_calloc = @extern(*const fn () callconv(.c) c_int, .{ .name = "test_calloc" });
    try std.testing.expectEqual(0, test_calloc());
}

test "c threads" {
    allocator = std.testing.allocator;
    const test_threading = @extern(*const fn (n_threds: c_int) callconv(.c) c_int, .{ .name = "test_threading" });
    try std.testing.expectEqual(0, test_threading(4));
}
