# Zalloc

Replace malloc, calloc, realloc and free in a c module with a zig allocator. 

## Usage

```sh
zig fetch --save git+https://github.com/D-Berg/zalloc.git
```

```build.zig

const zalloc = @import("zalloc");

pub fn build(b: *std.Build) !void {

    //...

    // add it as a dependency
    const zalloc_dep = b.dependency("zalloc", .{
        .optimize = optimize,
        .target = target,
    });

    // Example c lib, shoutout to md4c
    const md4c_mod = b.addModule("md4c", .{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // this overwrites malloc, calloc, realloc and free in 
    // all c source files in the c module and will only affect that module.
    zalloc.infect(your_c_mod);

    // import the and link zalloc to your exe
    exe_mod.addImport("zalloc", zalloc_dep.module("zalloc"));
    exe_mod.linkLibrary(zalloc_dep.artifact("zalloc"));
}

```

```main.zig

const zalloc = @import("zalloc");

pub fn main() !void {

    // choose a zig allocator
    var debug_allocator: std.heap.DebugAllocator(.{
        .verbose_log = true, // logs allocations and frees, just to show that zalloc actually does something
    }) = .init;
    defer _ = debug_allocator.deinit(); 

    const gpa = debug_allocator.allocator();

    // Specify which allocator the c library will use
    // DO this before calling any of the c functions.
    // Forgetting this will lead to allocations returning null.
    zalloc.allocator = gpa;

    // ...

    // now md4c will use the zigs debug allocator.
    const rc = md4c.md_html(
        markdown.ptr,
        @intCast(markdown.len),
        processHtml,
        null,
        md4c.MD_FLAG_COLLAPSEWHITESPACE,
        0,
    );
    if (rc != 0) return error.FailedToParseMarkdown;
}

```
