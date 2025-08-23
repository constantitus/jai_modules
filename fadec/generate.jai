// This library has a lot of one-liner helper macros which we are not getting in this module. We should
// probably try to convert them to jai macros somehow.

AT_COMPILE_TIME :: true;

LIB_NAME :: "fadec";
SRC_PATH :: "source/fadec";
// encode2 is off-by-default to reduce size and compile-time

SRC_FILES :: string.[
    "decode.c",
    "format.c",
    "encode.c",
    // "encode2.c",
];

HEADERS :: string.[
    "fadec.h",
    "fadec-enc.h",
    // "fadec-enc2.h",
];

PYTHON3 :: "python3";

pre_compile_step :: () -> bool {
    success := true;

    run :: (command: .. string) -> bool #expand {
        log("%", get_quoted_command_string(command));
        result := run_command(.. command, capture_and_return_output=true, print_captured_output=true);
        return result.exit_code == 0;
    }

    parseinstrs := tprint("%/parseinstrs.py", SRC_PATH);
    instrs_txt := tprint("%/instrs.txt", SRC_PATH);
    success &&= run(PYTHON3, parseinstrs, "decode",  instrs_txt, tprint("%/fadec-decode-public.inc",  SRC_PATH), tprint("%/fadec-decode-private.inc",  SRC_PATH), "--32", "--64");
    success &&= run(PYTHON3, parseinstrs, "encode",  instrs_txt, tprint("%/fadec-encode-public.inc",  SRC_PATH), tprint("%/fadec-encode-private.inc",  SRC_PATH), "--32", "--64");
    // success &&= run(PYTHON3, parseinstrs, "encode2", instrs_txt, tprint("%/fadec-encode2-public.inc", SRC_PATH), tprint("%/fadec-encode2-private.inc", SRC_PATH), "--32", "--64");

    return success;
}

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
      case; assert(false);
    }

    success := true;
    if compile {
        if !pre_compile_step()  return false;

        make_directory_if_it_does_not_exist(lib_directory, true);
        lib_path := tprint("%/%", lib_directory, LIB_NAME);
        files: [..]string;
        extra: [..]string;
        array_add(*extra, tprint("-I%", SRC_PATH));

        array_add(*files, .. SRC_FILES);
        for * files  it.* = tprint("%/%", SRC_PATH, it.*);

        if os_target == .WINDOWS {
            array_add(*extra,
                "/std:c11",
                "/D_CRT_SECURE_NO_WARNINGS",
                "/wd4018", // - Signed/unsigned comparison
                "/wd4146", // - Unary minus operator applied to unsigned type, result still unsigned
                "/wd4244", // - Possible loss of data in conversion from integer type to smaller integer type
                "/wd4245", // - Signed/unsigned assignment
                "/wd4267", // - Possible loss of data in conversion from size_t to smaller type
                "/wd4310", // - Possible loss of data in conversion of constant value to smaller type
            );
        } else {
            array_add(*extra, "-std=c11", "-Wno-overlength-strings");
        }

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

            success &&= build_cpp_dynamic_lib(lib_path, .. files, target=os_target, debug=compile_debug, extra=extra,
                library_files = ifx os_target == .WINDOWS then string.[
                    // This library does not provide us with a macro that we can define as __declspec(dllexport),
                    // but we know what symbols we want anyway. @Hack: We pass these as library_files because
                    // they need to go to the linker. This is kind of awful.
                    "/EXPORT:fd_decode",
                    "/EXPORT:fd_format",
                    "/EXPORT:fd_format_abs",
                    "/EXPORT:fdi_name",
                    "/EXPORT:fe_enc64_impl",
                ]
            );
            success &&= build_cpp_static_lib( lib_path, .. files, target=os_target, debug=compile_debug, extra=extra);
        }
    }
    if !success  return false;

    options: Generate_Bindings_Options;
    options.os = os_target;
    options.cpu = cpu_target;
    output_name: string;
    {
        using options;

        output_name = "bindings.jai";
        generate_library_declarations = false;
        footer = tprint(FOOTER, LIB_NAME);

        array_add(*library_search_paths, lib_directory);

        array_add(*libraries, .{filename=LIB_NAME});
        array_add(*include_paths, SRC_PATH);
        for HEADERS  array_add(*source_files,  tprint("%/%", SRC_PATH, it));
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

FOOTER :: #string END

#if OS == {
case .WINDOWS; %1 :: #library "windows/%1";
case .LINUX;   %1 :: #library "linux/%1";
case .MACOS;   %1 :: #library "macos/%1";
case .IOS;
    #if #exists(TARGET_IOS_SIMULATOR) {
        %1 :: #library "ios/%1_simulator";
    } else {
        %1 :: #library "ios/%1";
    }
case .ANDROID;
    #if CPU == .X64 {
        %1 :: #library "android/x64/%1";
    } else #if CPU == .ARM64 {
        %1 :: #library "android/arm64/%1";
    }
case;
    #assert false;
}

END;


