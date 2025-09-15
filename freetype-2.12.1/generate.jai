AT_COMPILE_TIME :: true;

FREETYPE_PATH :: "src/freetype-2.12.1";

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
    if target_android os_target = .ANDROID;
    if target_ios     os_target = .IOS;
    if target_x64     cpu_target = .X64;
    if target_arm     cpu_target = .ARM64;

    lib_directory: string;
    if os_target == {
      case .WINDOWS; lib_directory = "windows";
      case .LINUX;   lib_directory = "linux";
      case .MACOS;   lib_directory = "macos";
      case .IOS;     lib_directory = "ios";
      case .ANDROID; lib_directory = ifx cpu_target == .X64 then "android/x64" else "android/arm64";
      case .PS5;     lib_directory = "ps5";
      case; assert(false);
    }

    success := true;
    if compile {
        make_directory_if_it_does_not_exist(lib_directory, true);
        lib_path := tprint("%/freetype", lib_directory);
        files: [..]string;
        extra: [..]string;
        array_add(*extra, tprint("-I%/include", FREETYPE_PATH));
        array_add(*extra, "-DFT2_BUILD_LIBRARY");

        array_add(*files, .. FREETYPE_FILES);
        if os_target == .WINDOWS {
            array_add(*files, "builds/windows/ftsystem.c");
            array_add(*extra, "-D_CRT_SECURE_NO_WARNINGS");
            array_add(*extra, "/wd4267", "/wd4244"); // suppress the "possible loss of data" warnings
        } else {
            array_add(*files, "builds/unix/ftsystem.c");
            array_add(*extra, "-DHAVE_UNISTD_H", "-DHAVE_FCNTL_H");
        }
        for * files  it.* = tprint("%/%", FREETYPE_PATH, it.*);

        if os_target == {
          case .MACOS;
            lib_path_x64   := tprint("%_x64", lib_path);
            lib_path_arm64 := tprint("%_arm64", lib_path);

            array_resize(*extra, extra.count + 3);
            for i: 3..extra.count-1  extra[i] = extra[i-3];
            extra[0] = "-arch";

            array_add(*extra, "-fPIC");
            
            // arm64
            extra[1] = "arm64";
            extra[2] = "-mmacos-version-min=11.0";  // Earliest version that supports arm64
            success &&= build_cpp_dynamic_lib(lib_path_arm64, .. files, extra=extra, debug=compile_debug);
            success &&= build_cpp_static_lib( lib_path_arm64, .. files, extra=extra, debug=compile_debug);
            // x64
            extra[1] = "x86_64";
            extra[2] = "-mmacos-version-min=10.13"; // Our current x64 min version
            array_add(*extra, "-msse2");
            success &&= build_cpp_dynamic_lib(lib_path_x64, .. files, extra=extra, debug=compile_debug);
            success &&= build_cpp_static_lib( lib_path_x64, .. files, extra=extra, debug=compile_debug);

            // create fat binaries
            success &&= run_command("lipo", "-create", tprint("%.dylib", lib_path_x64), tprint("%.dylib", lib_path_arm64), "-output", tprint("%.dylib", lib_path)).exit_code == 0;
            success &&= run_command("lipo", "-create", tprint("%.a",     lib_path_x64), tprint("%.a",     lib_path_arm64), "-output", tprint("%.a",     lib_path)).exit_code == 0;
          case .IOS;
            lib_path_ios       := lib_path;
            lib_path_x64_sim   := tprint("%_x64_sim", lib_path);
            lib_path_arm64_sim := tprint("%_arm64_sim", lib_path);
            lib_path_fat_sim   := tprint("%_simulator", lib_path);

            array_resize(*extra, extra.count + 6);
            for i: 6..extra.count-1  extra[i] = extra[i-6];
            extra[0] = "-arch";
            extra[2] = "-isysroot";
            extra[4] = "-target";

            array_add(*extra, "-mios-version-min=13.0");

            // iOS
            extra[1] = "arm64";
            extra[3] = get_ios_sdk_path();
            extra[5] = get_ios_target_triple();
            success &&= build_cpp_static_lib(lib_path_ios,       .. files, extra=extra, debug=compile_debug, target=os_target);

            // iOS simulator
            extra[3] = get_ios_sdk_path(simulator=true);
            extra[5] = get_ios_target_triple(simulator=true);
            // arm64
            extra[1] = "arm64";
            success &&= build_cpp_static_lib(lib_path_arm64_sim, .. files, extra=extra, debug=compile_debug, target=os_target);
            // x64
            extra[1] = "x86_64";
            extra[5] = get_ios_target_triple(.X64, simulator=true);
            array_add(*extra, "-msse2");
            success &&= build_cpp_static_lib(lib_path_x64_sim,   .. files, extra=extra, debug=compile_debug, target=os_target);

            // Create fat binary for simulator
            success &&= run_command(
                "lipo", "-create",
                "-output", tprint("%.a", lib_path_fat_sim),
                tprint("%.a", lib_path_x64_sim),
                tprint("%.a", lib_path_arm64_sim),
            ).exit_code == 0;

          case;
            if os_target == .ANDROID {
                _, target_triple_with_sdk := get_android_target_triple(cpu_target);
                array_add(*extra, "-target", target_triple_with_sdk);
            }

            if os_target == .WINDOWS {
            } else {
                if cpu_target == .X64  array_add(*extra, "-msse2");
                array_add(*extra, "-fPIC");
            }

            if os_target == .WINDOWS 
                array_add(*extra, "-DDLL_EXPORT=1");
            if os_target != .PS5 {
                success &&= build_cpp_dynamic_lib(lib_path, .. files, target=os_target, debug=compile_debug, extra=extra);
            }

            if os_target == .WINDOWS  extra.count -= 1; // DLL_EXPORT
            success &&= build_cpp_static_lib(lib_path, .. files, target=os_target, debug=compile_debug, extra=extra);
        }
    }
    if !success  return false;

    freetype_include := tprint("%/include", FREETYPE_PATH);

    options: Generate_Bindings_Options;
    options.os = os_target;
    options.cpu = cpu_target;
    output_name: string;
    {
        using options;

        if os_target == {
          case .ANDROID;  return false;  // Yea, this will fail.
          case .WINDOWS;
            output_name = "windows.jai";
          case .LINUX; #through;
          case .MACOS; #through;
          case .IOS;;
            output_name = "unix.jai";
            generate_library_declarations = false;
            footer = UNIX_FOOTER;
          case;
            assert(false);
        }

        array_add(*library_search_paths, lib_directory);
        sources := string.[
            "freetype/freetype.h",
            "freetype/tttables.h",
        ];

        array_add(*libraries, .{filename="freetype"});
        array_add(*include_paths, freetype_include);
        for source: sources {
            array_add(*source_files,  tprint("%/%", freetype_include, source));
        }
        auto_detect_enum_prefixes = true;
        log_stripped_declarations = false;
        generate_compile_time_struct_checks = false;
    }

    return generate_bindings(options, output_name);
}

#import "Toolchains/Android";
#import "Toolchains/iOS";
#import "Basic";
#import "BuildCpp";
#import "Bindings_Generator";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "Process";
#import "String";

UNIX_FOOTER :: #string END
#if OS == .LINUX {
    freetype :: #library "linux/freetype";
} else #if OS == .MACOS {
    freetype :: #library "macos/freetype";
} else #if OS == .IOS {
    #if #exists(TARGET_IOS_SIMULATOR) {
        freetype :: #library "ios/freetype_simulator";
    } else {
        freetype :: #library "ios/freetype";
    }
} else #if OS == .ANDROID {
    #if CPU == .X64 {
        freetype :: #library "android/x64/freetype";
    } else #if CPU == .ARM64 {
        freetype :: #library "android/arm64/freetype";
    }
} else {
    #assert false;
}
END;

FREETYPE_FILES :: string.[
    "src/base/ftbase.c",
    "src/base/ftbbox.c",
    "src/base/ftbdf.c",
    "src/base/ftbitmap.c",
    "src/base/ftcid.c",
    "src/autofit/autofit.c",
    "src/base/ftfstype.c",
    "src/base/ftglyph.c",
    "src/base/ftgxval.c",
    "src/base/ftgasp.c",
    "src/base/ftmm.c",
    "src/base/ftotval.c",
    "src/base/ftinit.c",
    "src/base/ftpatent.c",
    "src/base/ftstroke.c",
    "src/base/ftpfr.c",
    "src/base/ftsynth.c",
    "src/base/fttype1.c",
    "src/base/ftwinfnt.c",
    "src/bdf/bdf.c",
    "src/bzip2/ftbzip2.c",
    "src/cache/ftcache.c",
    "src/cff/cff.c",
    "src/lzw/ftlzw.c",
    "src/pcf/pcf.c",
    "src/gzip/ftgzip.c",
    "src/pfr/pfr.c",
    "src/cid/type1cid.c",
    "src/psaux/psaux.c",
    "src/pshinter/pshinter.c",
    "src/psnames/psnames.c",
    "src/raster/raster.c",
    "src/svg/svg.c",
    "src/sdf/sdf.c",
    "src/sfnt/sfnt.c",
    "src/smooth/smooth.c",
    "src/truetype/truetype.c",
    "src/type1/type1.c",
    "src/type42/type42.c",
    "src/winfonts/winfnt.c",
    "src/base/ftdebug.c",
];

