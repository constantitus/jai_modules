AT_COMPILE_TIME :: true;

SOURCE_PATH :: "source";
LIB_BASE_NAME :: "miniaudio";

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
    target_android := array_find(args, "-android");
    target_ios     := array_find(args, "-ios");
    target_x64     := array_find(args, "-x64");
    target_arm     := array_find(args, "-arm64");
    compile        := array_find(args, "-compile");
    compile_debug  := array_find(args, "-debug");

    os_target  := OS;
    cpu_target := CPU;
    if target_android os_target  = .ANDROID;
    if target_ios     os_target  = .IOS;
    if target_x64     cpu_target = .X64;
    if target_arm     cpu_target = .ARM64;

    lib_directory: string;
    if os_target == {
        case .WINDOWS;
            lib_directory = "windows";
        case .LINUX;
            lib_directory = "linux";
        case .IOS; 
            lib_directory = "ios";
        case .MACOS;
            lib_directory = "macos";
        case .ANDROID;
            lib_directory = ifx cpu_target == .X64 then "android/x64" else "android/arm64";
        case .PS5;
            lib_directory = "ps5";
        case;
            assert(false);
    }

    if compile {
        source_file := tprint("%/miniaudio.c", SOURCE_PATH);

        make_directory_if_it_does_not_exist(lib_directory, recursive = true);
        lib_path := tprint("%/%", lib_directory, LIB_BASE_NAME);
        success := true;
        if os_target == .MACOS {
            lib_path_x64   := tprint("%_x64", lib_path);
            lib_path_arm64 := tprint("%_arm64", lib_path);

            extra: [..]string;
            array_add(*extra,
                "-arch", "",
                "",
                "-x", "objective-c",
                "-fPIC",
            );
            
            // arm64
            extra[1] = "arm64";
            extra[2] = "-mmacos-version-min=11.0";  // Earliest version that supports arm64
            success &&= build_cpp_dynamic_lib(lib_path_arm64, source_file, extra=extra, debug=compile_debug);
            success &&= build_cpp_static_lib( lib_path_arm64, source_file, extra=extra, debug=compile_debug);
            // x64
            extra[1] = "x86_64";
            extra[2] = "-mmacos-version-min=10.13"; // Our current x64 min version
            array_add(*extra, "-msse2", "-mavx2");
            success &&= build_cpp_dynamic_lib(lib_path_x64, source_file, extra=extra, debug=compile_debug);
            success &&= build_cpp_static_lib( lib_path_x64, source_file, extra=extra, debug=compile_debug);

            // create fat binaries
            success &&= run_command("lipo", "-create", tprint("%.dylib", lib_path_x64), tprint("%.dylib", lib_path_arm64), "-output", tprint("%.dylib", lib_path)).exit_code == 0;
            success &&= run_command("lipo", "-create", tprint("%.a",     lib_path_x64), tprint("%.a",     lib_path_arm64), "-output", tprint("%.a",     lib_path)).exit_code == 0;
        } else if os_target == .IOS {
            lib_path_ios       := lib_path;
            lib_path_x64_sim   := tprint("%_x64_sim", lib_path);
            lib_path_arm64_sim := tprint("%_arm64_sim", lib_path);
            lib_path_fat_sim   := tprint("%_simulator", lib_path);

            extra: [..]string;
            array_add(*extra,
                "-arch", "",
                "-isysroot", "",
                "-target", "",
                "-mios-version-min=13.0",
                "-x", "objective-c",
                "-DMA_NO_RUNTIME_LINKING",
                // Due to the way miniaudio links to frameworks at runtime, your application may not pass Apple's
                // notarization process. To fix this there are two options. The first is to compile with
                // `-DMA_NO_RUNTIME_LINKING` which in turn will require linking with
                // `-framework CoreFoundation -framework CoreAudio -framework AudioToolbox`.
            );

            // iOS
            extra[1] = "arm64";
            extra[3] = get_ios_sdk_path();
            extra[5] = get_ios_target_triple();
            success &&= build_cpp_static_lib(lib_path_ios,       source_file, extra=extra, debug=compile_debug, target=os_target);

            // iOS simulator
            extra[3] = get_ios_sdk_path(simulator=true);
            extra[5] = get_ios_target_triple(simulator=true);

            extra[1] = "arm64";
            success &&= build_cpp_static_lib(lib_path_arm64_sim, source_file, extra=extra, debug=compile_debug, target=os_target);

            extra[1] = "x86_64";
            extra[5] = get_ios_target_triple(.X64, simulator=true);
            array_add(*extra, "-msse2", "-mavx2");
            success &&= build_cpp_static_lib(lib_path_x64_sim,   source_file, extra=extra, debug=compile_debug, target=os_target);

            // Create fat binary for simulator
            success &&= run_command(
                "lipo", "-create",
                tprint("%.a", lib_path_x64_sim),
                tprint("%.a", lib_path_arm64_sim),
                "-output", tprint("%.a", lib_path_fat_sim),
            ).exit_code == 0;
        } else {
            extra: [..] string;

            if os_target == .ANDROID {
                _, target_triple_with_sdk := get_android_target_triple(cpu_target);
                array_add(*extra, "-target", target_triple_with_sdk);
            }

            if os_target == .WINDOWS {
                array_add(*extra, "-DWIN32_LEAN_AND_MEAN", "-DMA_API=__declspec(dllexport)");
            } else {
                if cpu_target == .X64  array_add(*extra, "-msse2", "-mavx2");
                array_add(*extra, "-fPIC");
            }

            if os_target != .PS5 {
                success &&= build_cpp_dynamic_lib(lib_path, source_file, target = os_target, debug = compile_debug, extra = extra);
            }
            success &&= build_cpp_static_lib(lib_path, source_file, target = os_target, debug = compile_debug, extra = extra);
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
        array_add(*source_files, tprint("%/miniaudio.h", SOURCE_PATH));

        generate_library_declarations = false;

        if os_target == .ANDROID {
            // The only difference seems to be pointers to wchar_t which are wrong anyway...
            lib_directory = path_strip_filename(lib_directory);
            lib_directory.count -= 1; // minus the "/"
            footer = tprint(ANDROID_FOOTER_TEMPLATE, LIB_BASE_NAME, lib_directory);
        } else if os_target == .IOS {
            footer = tprint(IOS_FOOTER_TEMPLATE, LIB_BASE_NAME, lib_directory);
        } else {
            footer = tprint(FOOTER_TEMPLATE, LIB_BASE_NAME, lib_directory);
        }

        auto_detect_enum_prefixes = true;
        log_stripped_declarations = false;
        generate_compile_time_struct_checks = false;
    }

    output_filename := tprint("generated_%.jai", lib_directory);
    return generate_bindings(options, output_filename);
}

FOOTER_TEMPLATE :: #string END

%1 :: #library "%2/%1";

END;

IOS_FOOTER_TEMPLATE :: #string END

#if #exists(TARGET_IOS_SIMULATOR) {
    %1 :: #library "%2/%1_simulator";
} else {
    %1 :: #library "%2/%1";
}

END;

ANDROID_FOOTER_TEMPLATE :: #string END

#if CPU == .ARM64  %1 :: #library "%2/arm64/%1";
#if CPU == .X64    %1 :: #library "%2/x64/%1";

END;

#import "Basic";
#import "String";
#import "Bindings_Generator";
#import "BuildCpp";
#import "Compiler";
#import "File";
#import "Process";
#import "Toolchains/Android";
#import "Toolchains/iOS";
