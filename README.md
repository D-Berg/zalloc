# Zalloc

Replace malloc, calloc, realloc and free in a c module with a zig allocator. 
Usefull in order to use zigs debug allocator when interacting with C code to check for memory leaks,
double frees and all its features. In Release modes it is probably just unnecessary if you pass it 
the gpa from juice main.

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
    zalloc.infect(md4c_mod);

    // import the and link zalloc to your exe
    exe_mod.addImport("zalloc", zalloc_dep.module("zalloc"));
    exe_mod.linkLibrary(zalloc_dep.artifact("zalloc"));
}

```

```main.zig

const zalloc = @import("zalloc");

pub fn main(init: std.Io.Init) !void {
    // Specify which allocator the c library will use
    // DO this before calling any of the c functions.
    // Forgetting this will lead to allocations returning null.
    zalloc.allocator = init.gpa;
    zalloc.io = init.io;

    // ...

    // now md4c will use zigs debug allocator.
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
