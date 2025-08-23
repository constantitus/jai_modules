AT_COMPILE_TIME :: true;
SOURCE_PATH :: "source";
GLFW_PATH :: "glfw";//-3.4";
LIB_BASE_NAME :: "glfw";
WL_SCANNER :: "wayland-scanner";

#if AT_COMPILE_TIME {
    #run,stallable {
        set_build_options_dc(.{do_output=false});
        options := get_build_options();
        args := options.compile_time_command_line;
        if !generate_bindings(args, options.minimum_os_version) {
            compiler_set_workspace_status(.FAILED);
        }
    }
} else {
    #import "System";

    main :: () {
        set_working_directory(path_strip_filename(get_path_of_running_executable()));
        if !generate_bindings(get_command_line_arguments(), #run get_build_options().minimum_os_version) {
            exit(1);
        }
    }
}

generate_bindings :: (args: [] string, minimum_os_version: type_of(Build_Options.minimum_os_version)) -> bool {
    target_x64     := array_find(args, "-x64");
    target_arm     := array_find(args, "-arm64");
    compile        := array_find(args, "-compile");
    compile_debug  := array_find(args, "-debug");
    no_wayland     := array_find(args, "-no_wayland");

    os_target  := OS;
    cpu_target := CPU;
    if target_x64     cpu_target = .X64;
    if target_arm     cpu_target = .ARM64;

    lib_directory: string;
    if os_target == {
        case .WINDOWS; lib_directory = "windows";
        case .LINUX;   lib_directory = "linux";
        case .MACOS;   lib_directory = "macos";
        case; assert(false);
    }


    if compile {
        source_dir := tprint("%/%/src", SOURCE_PATH, GLFW_PATH);
        source_files: [..]string;
        array_add(*source_files,
            "init.c",
            "platform.c",
            "context.c",
            "monitor.c",
            "window.c",
            "input.c",
            "vulkan.c",

            "null_init.c",
            "null_joystick.c",
            "null_monitor.c",
            "null_window.c",

            "egl_context.c",
            "osmesa_context.c",
        );

        make_directory_if_it_does_not_exist(lib_directory, recursive = true);
        lib_path := tprint("%/%", lib_directory, LIB_BASE_NAME);
        success := true;
        if os_target == {
        case .MACOS;
            lib_path_x64   := tprint("%_x64", lib_path);
            lib_path_arm64 := tprint("%_arm64", lib_path);

            array_add(*source_files,
                "posix_module.c",
                "posix_thread.c",
                "cocoa_init.m",
                "cocoa_joystick.m",
                "cocoa_monitor.m",
                "cocoa_window.m",
                "cocoa_time.c",
                "nsgl_context.m",
            );

            extra: [..]string;
            array_add(*extra,
                "-arch", "",
                "", // -mmacos-version-min
                "-x", "objective-c",
                "-fPIC",
            );

            array_add(*extra,
                "-D_GLFW_COCOA",
                "-D_GLFW_USE_MENUBAR",
                "-D_GLFW_USE_RETINA",
            );


            for * source_files  it.* = tprint("%/%", source_dir, it.*);
            
            array_add(*extra,
                "-framework", "Cocoa",
                "-framework", "IOKit",
                "-framework", "QuartzCore", // Only required in the git version of glfw
            );
            static_extra := cast([]string) extra;
            static_extra.count -= 6;
            
            // arm64
            extra[1] = "arm64";
            extra[2] = "-mmacos-version-min=11.0";  // Earliest version that supports arm64
            success &&= build_cpp_dynamic_lib(lib_path_arm64, .. source_files, extra=extra,        debug=compile_debug);
            success &&= build_cpp_static_lib( lib_path_arm64, .. source_files, extra=static_extra, debug=compile_debug);
            // x64
            extra[1] = "x86_64";
            extra[2] = "-mmacos-version-min=10.13"; // Our current x64 min version
            array_add(*extra, "-msse2", "-mavx2");
            success &&= build_cpp_dynamic_lib(lib_path_x64, .. source_files, extra=extra,        debug=compile_debug);
            success &&= build_cpp_static_lib( lib_path_x64, .. source_files, extra=static_extra, debug=compile_debug);

            // create fat binaries
            run_result := run_command("lipo", "-create", tprint("%.dylib", lib_path_x64), tprint("%.dylib", lib_path_arm64), "-output", tprint("%.dylib", lib_path));
            success &&= (run_result.exit_code == 0);
            run_result  = run_command("lipo", "-create", tprint("%.a",     lib_path_x64), tprint("%.a",     lib_path_arm64), "-output", tprint("%.a",     lib_path));
            success &&= (run_result.exit_code == 0);
        case .LINUX;
            array_add(*source_files,
                "posix_module.c",
                "posix_thread.c",
                "posix_time.c",
                "posix_poll.c",
                "linux_joystick.c",
                "xkb_unicode.c",
            );

            extra: [..] string;
            // array_add(*extra, "-D_GNU_SOURCE");
            if !no_wayland {
                generate_wayland_headers();
                array_add(*extra, "-Isource/wayland");
                array_add(*extra, "-D_GLFW_WAYLAND");
                array_add(*source_files,
                    "wl_init.c",
                    "wl_monitor.c",
                    "wl_window.c",
                );
            } else {
                array_add(*extra, "-DNO_WAYLAND");
            }

            array_add(*extra, "-D_GLFW_X11");
            array_add(*source_files,
                "x11_init.c",
                "x11_monitor.c",
                "x11_window.c",
                "glx_context.c",
            );

            for * source_files  it.* = tprint("%/%", source_dir, it.*);
            success &&= build_cpp_dynamic_lib(lib_path, .. source_files, target = os_target, debug = compile_debug, extra = extra);
            success &&= build_cpp_static_lib( lib_path, .. source_files, target = os_target, debug = compile_debug, extra = extra);
        case .WINDOWS;
            array_add(*source_files,
                "win32_init.c",
                "win32_module.c",
                "win32_monitor.c",
                "win32_window.c",
                "win32_joystick.c",
                "win32_time.c",
                "win32_thread.c",
                "wgl_context.c",
            );
            extra: [..] string;
            array_add(*extra, "-D_GLFW_WIN32");
            array_add(*extra, "-D_CRT_SECURE_NO_WARNINGS");

            for * source_files  it.* = tprint("%/%", source_dir, it.*);
            array_add(*extra,
                "/D_GLFW_BUILD_DLL",
                "opengl32.lib",
                "gdi32.lib",
                "user32.lib",
                "shell32.lib",
            );

            success &&= build_cpp_dynamic_lib(lib_path, .. source_files, target = os_target, debug = compile_debug, extra = extra);
            extra.count -= 5; // Remove the last extras we added for the dll... these need to be in order, otherwise cl.exe overwrites the .lib...
            success &&= build_cpp_static_lib( lib_path, .. source_files, target = os_target, debug = compile_debug, extra = extra);
        }

        if !success     return false;
    }

    options: Generate_Bindings_Options;
    options.os = os_target;
    options.cpu = cpu_target;
    {
        using options;

        array_add(*library_search_paths, lib_directory);
        array_add(*libraries, .{filename=LIB_BASE_NAME});
        array_add(*source_files, tprint("%/glfw.h", SOURCE_PATH));
        if os_target == .MACOS {
            #import "Toolchains/macOS";
            sdk, got := get_macos_sdk_path();
            assert(got);
            array_add(*options.extra_clang_arguments, "-isysroot", sdk);
        }

        generate_library_declarations = false;

        footer = tprint(FOOTER_TEMPLATE, LIB_BASE_NAME);

        auto_detect_enum_prefixes = true;
        log_stripped_declarations = false;
        generate_compile_time_struct_checks = false;
    }

    return generate_bindings(options, "bindings.jai");
}

generate_wayland_headers :: () {
    wl_src_dir := tprint("%/%/deps/wayland", SOURCE_PATH, GLFW_PATH);
    wl_inc_dir := "source/wayland";
    make_directory_if_it_does_not_exist(wl_inc_dir);

    files := [2]string.[
        .["wayland",                         "wayland-client-protocol"],
	    .["xdg-shell",                       "xdg-shell-client-protocol"],
	    .["xdg-decoration-unstable-v1",      "xdg-decoration-unstable-v1-client-protocol"],
	    .["viewporter",                      "viewporter-client-protocol"],
	    .["relative-pointer-unstable-v1",    "relative-pointer-unstable-v1-client-protocol"],
	    .["pointer-constraints-unstable-v1", "pointer-constraints-unstable-v1-client-protocol"],
	    .["fractional-scale-v1",             "fractional-scale-v1-client-protocol"],
	    .["xdg-activation-v1",               "xdg-activation-v1-client-protocol"],
	    .["idle-inhibit-unstable-v1",        "idle-inhibit-unstable-v1-client-protocol"],
    ];

    success := true;
    for f: files {
        xml := tprint("%/%.xml", wl_src_dir, f[0]);

        a := string.[WL_SCANNER, "client-header", xml, tprint("%/%.h", wl_inc_dir, f[1])];
        b := string.[WL_SCANNER, "private-code", xml, tprint("%/%-code.h", wl_inc_dir, f[1])];

        // log("%", join(.. a, separator=" "));
        success &&= run_command(.. a, print_captured_output=true).exit_code == 0;

        // log("%", join(.. b, separator=" "));
        success &&= run_command(.. b, print_captured_output=true).exit_code == 0;
    }

    if !success  log_error("wayland-scanner commands failed. Make sure you have it installed on your system, otherwise pass -no_wayland.");
}

FOOTER_TEMPLATE :: #string END

#if OS == {
case .WINDOWS;  %1 :: #library "windows/%1";
case .LINUX;    %1 :: #library "linux/%1";
case .MACOS;    %1 :: #library "macos/%1";
}

END

#import "Basic";
#import "String";
#import "Bindings_Generator";
#import "BuildCpp";
#import "Compiler";
#import "File";
#import "Process";
