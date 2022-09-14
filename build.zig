const std = @import("std");

const page_size = 65536; // in bytes

pub fn build(b: *std.build.Builder) void {
    // Adds the option -Drelease=[bool] to create a release build, which we set to be ReleaseSmall by default.
    b.setPreferredReleaseMode(.ReleaseSmall);
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const raytracer_step = b.step("raytracer", "Compiles raytracer.zig");
    const raytracer_lib = b.addSharedLibrary("raytracer", "./raytracer.zig", .unversioned);
    raytracer_lib.setBuildMode(mode);
    raytracer_lib.setTarget(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
        .abi = .musl,
    });
    raytracer_lib.setOutputDir(".");

    // https://github.com/ziglang/zig/issues/8633
    raytracer_lib.import_memory = true; // import linear memory from the environment
    raytracer_lib.initial_memory = 32 * page_size; // initial size of the linear memory (1 page = 64kB)
    raytracer_lib.max_memory = 512 * page_size; // maximum size of the linear memory
    raytracer_lib.global_base = 6560; // offset in linear memory to place global data

    raytracer_lib.install();
    raytracer_step.dependOn(&raytracer_lib.step);
}
