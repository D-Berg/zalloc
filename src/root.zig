const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
pub const std_options: std.Options = .{
    .log_level = .err,
};
const log = std.log.scoped(.infector);

pub var allocator: ?Allocator = null;

var mutex: std.Thread.Mutex = .{};

export fn zmalloc(size: usize) callconv(.c) ?*anyopaque {
    mutex.lock();
    defer mutex.unlock();

    if (allocator) |gpa| {
        if (gpa.alloc(u8, size + @sizeOf(usize))) |slice| {
            return getAnyopaque(slice, size);
        } else |err| {
            log.err("malloc: {s}", .{@errorName(err)});
        }
    }
    return null;
}

export fn zrealloc(maybe_ptr: ?*anyopaque, new_size: usize) callconv(.c) ?*anyopaque {
    mutex.lock();
    defer mutex.unlock();

    if (allocator) |gpa| {
        if (maybe_ptr) |ptr| {
            if (gpa.realloc(getSlice(ptr), new_size + @sizeOf(usize))) |slice| {
                return getAnyopaque(slice, new_size);
            } else |err| {
                log.err("Failed to realloc: {s}", .{@errorName(err)});
            }
        } else {
            if (gpa.alloc(u8, new_size + @sizeOf(usize))) |slice| {
                return getAnyopaque(slice, new_size);
            } else |err| {
                log.err("realloc: {s}", .{@errorName(err)});
            }
        }
    }

    return null;
}

export fn zcalloc(num: usize, size: usize) callconv(.c) ?*anyopaque {
    mutex.lock();
    defer mutex.unlock();

    if (allocator) |gpa| {
        if (gpa.alloc(u8, num * size + @sizeOf(usize))) |slice| {
            @memset(slice, 0);
            return getAnyopaque(slice, num * size);
        } else |err| {
            log.err("Calloc failed: {s}", .{@errorName(err)});
        }
    }

    return null;
}

export fn zfree(maybe_ptr: ?*anyopaque) callconv(.c) void {
    mutex.lock();
    defer mutex.unlock();

    if (allocator) |gpa| {
        if (maybe_ptr) |ptr| {
            const slice = getSlice(ptr);
            gpa.free(slice);
        }
    }
}

fn getSlice(ptr: *anyopaque) []u8 {
    var slice: []u8 = undefined;
    slice.ptr = @as([*]u8, @ptrCast(ptr)) - @sizeOf(usize);
    slice.len = std.mem.bytesToValue(usize, slice.ptr[0..@sizeOf(usize)]) + @sizeOf(usize);

    return slice;
}

/// sets the first 8 bytes of the slice to the size of the allocation
fn getAnyopaque(slice: []u8, size: usize) *anyopaque {
    @memcpy(slice[0..@sizeOf(usize)], std.mem.toBytes(size)[0..]);
    return slice.ptr + @sizeOf(usize);
}

test "malloc and free" {
    allocator = std.testing.allocator;

    const maybe_ptr = zmalloc(10);
    defer if (maybe_ptr) |ptr| {
        zfree(ptr);
    };

    var string: []u8 = undefined;
    string.ptr = @ptrCast(maybe_ptr);
    string.len = 10;
    @memcpy(string[0..], "helloworld");

    try std.testing.expectEqualStrings("helloworld", string);
}

test "realloc" {
    // std.testing.log_level = .debug;
    allocator = std.testing.allocator;
    const malloc_ptr = zmalloc(10);

    const realloc_ptr = zrealloc(malloc_ptr, 20);
    defer zfree(realloc_ptr);
}

fn testMallocAndFree(id: u8) void {
    const maybe_ptr = zmalloc(10);
    defer if (maybe_ptr) |ptr| {
        zfree(ptr);
    };

    var string: []u8 = undefined;
    string.ptr = @ptrCast(maybe_ptr);
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
