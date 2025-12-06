AT_COMPILE_TIME :: true;

SRC_DIR    :: "source";
// Source:
// ANGLE:        https://chromium.googlesource.com/angle/angle  (chromium/7299 branch)
// astc-encoder: https://chromium.googlesource.com/external/github.com/ARM-software/astc-encoder
// zlib:         https://chromium.googlesource.com/chromium/src/third_party/zlib

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
    compile: bool;
    compile_debug: bool;
    generate: bool;
    os_target := OS;
    for args {
        if it == {
        case "-compile";       compile       = true;
        case "-compile_debug"; compile_debug = true;
        case "-generate";      generate      = true;
        case "-ios";            os_target = .IOS;
        case "-macos";          os_target = .MACOS;
        case "-windows";        os_target = .WINDOWS;
        case "-linux";          os_target = .LINUX;
        }
    }

    directory: string;
    if os_target == {
    case .IOS;      directory = "ios";
    case .MACOS;    directory = "macos";
    case .WINDOWS;  directory = "windows";
    case .LINUX;    directory = "linux";
    case; assert(false, "Unsupported target os %.", os_target);
    }

    success := true;
    if compile {
        make_directory_if_it_does_not_exist(directory);
        extra: [..]string;

        files: [..]string;
        array_add(*files, .. ANGLE_FILES);
        array_add(*files, .. ANGLE_FILES_EGL);
        array_add(*files, .. ANGLE_FILES_GLES);
        array_add(*files, .. ZLIB_FILES);
        array_add(*files, .. ASTCENC_FILES);
        for * files  it.* = tprint("%/%", SRC_DIR, it.*);
        for ANGLE_DEFINES  array_add(*extra, tprint("-D%", it));

        array_add(*extra,
            tprint("-I%/angle/src", SRC_DIR),
            tprint("-I%/angle/src/common/base", SRC_DIR),
            tprint("-I%/angle/src/common/third_party", SRC_DIR),
            tprint("-I%/angle/src/common/third_party/base", SRC_DIR),
            tprint("-I%/angle/src/common/third_party/xxhash", SRC_DIR),
            tprint("-I%/angle/src/third_party/khronos", SRC_DIR),
            tprint("-I%/angle/include", SRC_DIR),
            tprint("-I%/angle/include/KHR", SRC_DIR),
            tprint("-I%/zlib", SRC_DIR),
            tprint("-I%/zlib/google", SRC_DIR),
            tprint("-I%/astc-encoder/Source", SRC_DIR),
            tprint("-I%", SRC_DIR), // for generated headers
        );

        // Build angle
        if os_target == .IOS {
            // Make space at the start of the array
            array_resize(*extra, extra.count + 7);
            for #v2 < i: 7..extra.count-1 { extra[i] = extra[i-7]; }
            extra[0] = "-arch";
            // extra[1] = "";
            extra[2] = "-isysroot";
            // extra[3] = "";
            extra[4] = "-target";
            // extra[5] = "";
            // extra[6] = ""; // -DANGLE_PLATFORM_

            for ANGLE_DEFINES_IOS  array_add(*extra, tprint("-D%", it));

            array_add(*extra,
                "-mios-version-min=16.4", // As per angle and astcenc requirements
                "-fno-objc-arc", // "-fno-objc-msgsend-selector-stubs",
                "-Wno-unused-command-line-argument",
                "-Wno-deprecated", // treating 'c' input as 'c++' when in C++ mode
            );

            for ANGLE_FILES_IOS            array_add(*files, tprint("%/%", SRC_DIR, it));
            for ANGLE_FILES_MACOS_AND_IOS  array_add(*files, tprint("%/%", SRC_DIR, it));

            output := tprint("%/ANGLE", directory);
            output_x64_sim   := tprint("%_x64_sim",   output);
            output_arm64_sim := tprint("%_arm64_sim", output);
            output_fat_sim   := tprint("%_simulator", output);

            // iOS
            extra[1] = "arm64";
            extra[3] = get_ios_sdk_path();
            extra[5] = get_ios_target_triple();
            extra[6] = "-DANGLE_PLATFORM_IOS_FAMILY_SIMULATOR"; // This define is very confusing...

            success &&= build_angle_variant(output, .. files, extra, debug=compile_debug, os_target=os_target);

            // iOS-simulator
            extra[3] = get_ios_sdk_path(simulator=true);
            extra[5] = get_ios_target_triple(simulator=true);
            extra[6] = "-DANGLE_PLATFORM_IOS_FAMILY";

            extra[1] = "arm64";
            success &&= build_angle_variant(output_arm64_sim, .. files, extra, debug=compile_debug, os_target=os_target);

            extra[1] = "x86_64";
            extra[5] = get_ios_target_triple(cpu=.X64, simulator=true);
            success &&= build_angle_variant(output_x64_sim, .. files, extra, debug=compile_debug, os_target=os_target);

            success &&= run_command(
                "lipo", "-create", 
                "-output", tprint("%.a", output_fat_sim),
                tprint("%.a", output_arm64_sim),
                tprint("%.a", output_x64_sim),
                print_captured_output=true
            ).exit_code == 0;

            if !success  return false;
        } else if os_target == .MACOS { // @Untested
            // Make space at the start of the array
            array_resize(*extra, extra.count + 2);
            for #v2 < i: 2..extra.count-1 { extra[i] = extra[i-2]; }
            extra[0] = "-arch";
            // extra[1] = "";

            for ANGLE_DEFINES_MACOS  array_add(*extra, tprint("-D%", it));

            array_add(*extra,
                "-fno-objc-arc", // "-fno-objc-msgsend-selector-stubs",
                "-Wno-unused-command-line-argument",
                "-Wno-deprecated", // treating 'c' input as 'c++' when in C++ mode
            );

            for ANGLE_FILES_MACOS          array_add(*files, tprint("%/%", SRC_DIR, it));
            for ANGLE_FILES_MACOS_AND_IOS  array_add(*files, tprint("%/%", SRC_DIR, it));

            output := tprint("%/ANGLE", directory);
            output_arm64 := tprint("%_arm64", output);
            output_x64   := tprint("%_x64",   output);

            // arm64
            extra[1] = "arm64";
            extra[2] = "-mmacos-version-min=11.0";
            success &&= build_angle_variant(output_arm64, .. files, extra, debug=compile_debug, os_target=os_target);

            // x64
            extra[1] = "x86_64";
            extra[2] = "-mmacos-version-min=11.0";
            success &&= build_angle_variant(output_x64, .. files, extra, debug=compile_debug, os_target=os_target);

            success &&= run_command(
                "lipo", "-create", 
                "-output", tprint("%.a", output),
                tprint("%.a", output_arm64),
                tprint("%.a", output_x64),
                print_captured_output=true
            ).exit_code == 0 ;

            success &&= run_command(
                "lipo", "-create", 
                "-output", tprint("%.dylib", output),
                tprint("%.dylib", output_arm64),
                tprint("%.dylib", output_x64),
                print_captured_output=true
            ).exit_code == 0 ;

        } else if os_target == .WINDOWS {
            for ANGLE_FILES_WINDOWS    array_add(*files, tprint("%/%", SRC_DIR, it));
            for ANGLE_DEFINES_WINDOWS  array_add(*extra, tprint("-D%", it));

            output := tprint("%/ANGLE", directory);
            success &&= build_angle_variant(output, .. files, extra, debug=compile_debug, os_target=os_target);
        } else if os_target == .LINUX {
            for ANGLE_FILES_LINUX    array_add(*files, tprint("%/%", SRC_DIR, it));
            for ANGLE_DEFINES_LINUX  array_add(*extra, tprint("-D%", it));

            output := tprint("%/ANGLE", directory);
            success &&= build_angle_variant(output, .. files, extra, debug=compile_debug, os_target=os_target);
        }
        reset_temporary_storage();
    }

    if generate {
        options: Generate_Bindings_Options;
        using options;

        os = os_target;
        cpu = .ARM64;

        array_add(*library_search_paths, directory);
        array_add(*libraries, .{filename="ANGLE"});
        array_add(*include_paths, tprint("%/angle/include", SRC_DIR));
        for EGL_HEADERS   array_add(*source_files, tprint("%/angle/include/%", SRC_DIR, it));
        for GLES_HEADERS  array_add(*source_files, tprint("%/angle/include/%", SRC_DIR, it));

        generate_library_declarations = false;
        auto_detect_enum_prefixes = true;
        log_stripped_declarations = false;
        generate_compile_time_struct_checks = false;

        visitor = angle_visitor;
        success = generate_bindings(options, "bindings.jai");
    }
    return success;
}

build_angle_variant :: (output: string, files: .. string, extra: []string, debug: bool, os_target := OS) -> bool {
    auto_release_temp();
    success := true;
    // ANGLE can't be build in a single translation unit, sadly. So we have to do multiple object files
    // and link them, which BuildCpp cannot do atm.
    #import "Thread";
    #import "System";
    ncpus := get_number_of_processors();
    assert(ncpus >= 1);
    ncpus = max(ncpus-1, 2);

    // @Cleanup: Too much stuff in here...
    Data :: struct {
        current_index: s64;
        files: []string;
        extra: []string;
        objs: *[]string;
        cc, cxx: string;
        debug: bool;
        os_target := OS;

        success := true;
    }
    data: Data;

    objs := NewArray(files.count, string,, temp);
    data.files = files;
    data.objs  = *objs;
    data.extra = extra;
    data.debug = debug;
    data.os_target = os_target;

    #if OS == .WINDOWS  #import "Windows";
    else                #import "POSIX";
    data.cc  = to_string(getenv("CC"));
    data.cxx = to_string(getenv("CXX"));
    if !data.cc   data.cc  = ifx os_target == .WINDOWS then "cl.exe" else "clang";
    if !data.cxx  data.cxx = ifx os_target == .WINDOWS then "cl.exe" else "clang++";

    compile_proc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
        using data := cast(*Data) group.data;
        index := cast(s64) work;

        it := files[index];
        i := find_index_from_right(it, ".");
        assert(i > 0);

        basename := slice(it, 0, i);
        out_path: string = ---;
        if os_target == .WINDOWS  out_path = sprint("%.obj", basename);
        else                      out_path = sprint("%.o", basename);
        objs.data[index] = out_path;

        // if file_exists(out_path)  return .CONTINUE;

        args: [..]string;
        array_reserve(*args, extra.count+10);

        if os_target == .WINDOWS  array_add(*args, "/nologo");

        if ends_with(it, ".c") {
            array_add(*args, data.cc);
        } else {
            array_add(*args, data.cxx);
            if os_target == .WINDOWS  array_add(*args, "/std:c++17");
            else                      array_add(*args, "-std=c++17");
        }

        if os_target == .LINUX    array_add(*args, "-fPIC");
        if os_target == .WINDOWS  array_add(*args, "/MT");

        array_add(*args, .. extra);

        if debug {
            if os_target == .WINDOWS  array_add(*args, "/Zi", "-Od");
            else                      array_add(*args, "-g", "-Og");
        } else {
            if os_target == .WINDOWS  array_add(*args, "/Ox");
            else                      array_add(*args, "-O3");
        }

        if os_target == .WINDOWS  array_add(*args, "/c", tprint("/Fo:%", out_path), it);
        else                      array_add(*args, "-c", "-o", out_path, it);

        if !success return .STOP;
        log("%", get_quoted_command_string(args));
        result, output_string, error_string := run_command(..args, capture_and_return_output=true, print_captured_output=true);
        success &&= result.exit_code == 0;

        return ifx success then .CONTINUE else .STOP;
    }

    threads: Thread_Group;
    init(*threads, ncpus, compile_proc);
    threads.data = *data;
    threads.logging = false;
    start(*threads);

    for files  add_work(*threads, cast(*void) it_index);

    remaining := files.count;
    while remaining > 0 {
        sleep_milliseconds(1);
        results := get_completed_work(*threads);
        remaining -= results.count;
        if threads.should_exit || !data.success  break;
    }

    shutdown(*threads);

    if !data.success  return false;

    // Using ar directly because BuildCpp does not like when we don't pass files...
    cmd: [..]string;
    if os_target == .WINDOWS {
        // Make dll (before we make the static lib so it doesn't overwrite it. sigh)
        array_add(*cmd, "link.exe", "/DLL", "user32.lib", "gdi32.lib", "dxguid.lib", "d3d11.lib", "dxgi.lib", tprint("/OUT:%.dll", output));
        array_add(*cmd, .. objs);
        log("%", get_quoted_command_string(cmd));
        success = run_command(.. cmd, print_captured_output=true).exit_code == 0;
        array_reset(*cmd);

        // Make static lib
        array_add(*cmd, "lib.exe", tprint("/OUT:%.lib", output));
        array_add(*cmd, .. objs);
        log("%", get_quoted_command_string(cmd));
        success = run_command(.. cmd, print_captured_output=true).exit_code == 0;
    } else {
        if os_target != .IOS {
            suffix := ifx os_target == .MACOS then "dylib" else "so";
            array_add(*cmd, data.cxx, "-shared", "-o", tprint("%.%", output, suffix));

            if os_target == .MACOS {
                array_add(*cmd, "-arch", extra[1]); // sigh...
                array_add(*cmd,
                    "-framework", "Foundation",
                    "-framework", "CoreFoundation",
                    "-framework", "CoreGraphics",
                    "-framework", "QuartzCore",
                    "-framework", "IOKit",
                    "-framework", "IOSurface",
                    "-framework", "Metal",
                );
            }

            if os_target == .LINUX {
                array_add(*cmd,
                    "-lvulkan",
                    // "-lwayland-client",
                );
            }

            array_add(*cmd, .. objs);
            log("%", get_quoted_command_string(cmd));
            success &&= run_command(.. cmd, print_captured_output=true).exit_code == 0;
            array_reset(*cmd);
        }

        // Make static lib
        ar := to_string(getenv("CC"));
        if !ar  ar = "ar";
        out := tprint("%.a", output);
        file_delete(out); // Because ar appends to existing archives instead of creating new ones.
        array_add(*cmd, ar, "rcs", out);
        array_add(*cmd, .. objs);
        log("%", get_quoted_command_string(cmd));
        success &&= run_command(.. cmd, print_captured_output=true).exit_code == 0;
    }

    return success;
}

#import "Basic";
#import "String";
#import "Thread";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "Process";
#import "Bindings_Generator";
#import "Toolchains/iOS";


EGL_HEADERS :: string.[
    "EGL/egl.h",
    "EGL/eglext.h",
    "EGL/eglext_angle.h",
    "EGL/eglplatform.h"
];

GLES_HEADERS :: string.[
    "GLES2/gl2.h",
    "GLES2/gl2ext.h",
    "GLES2/gl2ext_angle.h",
    "GLES2/gl2platform.h",
    "GLES3/gl3.h",
    "GLES3/gl31.h",
    "GLES3/gl32.h",
    "GLES3/gl3platform.h"
];


angle_visitor :: (decl: *Declaration, parent_decl: *Declaration) -> Declaration_Visit_Result {
    // assert(xx decl.name);

    if begins_with_nocase(decl.name, "khronos_") {
        decl.decl_flags |= .OMIT_FROM_OUTPUT;
        return .STOP;
    }

    if decl.kind == .TYPEDEF {
        typedef := decl.type.type_of_typedef;

        // Strip stupid khronos typedefs.
        if typedef {
            if typedef && begins_with(typedef.name, "khronos_") {
                type := typedef.type;
                int_type: *CType;
                if type.number_flags & .FLOAT {
                    if type.size == 4       int_type = context.generator.type_def_float32;
                    else if type.size == 8  int_type = context.generator.type_def_float64;
                    else assert(false, "% %", decl.name, formatStruct(type, 0, true));
                } else {
                    int_type = get_int_type(type.size, !!(type.number_flags & .SIGNED));
                }
                decl.type = int_type;
            }
        }
    }

    if decl.name == "GLsizei" {
        // Apple defines GLsizei as s32, for some reason. That would conflict with everything
        // else that uses modern opengl and would require a lot of dirty casts, so we'll assume
        // it's u32 since the spec requires it to be unsigned anyway.
        //          -constantitus  2025-07-20
        decl.type = context.generator.type_def_u32;
    }

    // We put these in module.jai so we don't have to generate bindings_*.jai for every platform.
    if decl.name == "EGLNativeDisplayType" ||
       decl.name == "EGLNativePixmapType" ||
       decl.name == "EGLNativeWindowType" {
        decl.decl_flags |= .OMIT_FROM_OUTPUT;
        return .STOP;
    }


    return .RECURSE;
}

ANGLE_FILES :: string.[
    "angle/src/common/CompiledShaderState.cpp",
    "angle/src/common/Float16ToFloat32.cpp",
    "angle/src/common/MemoryBuffer.cpp",
    "angle/src/common/PackedEGLEnums_autogen.cpp",
    "angle/src/common/PackedEnums.cpp",
    "angle/src/common/PackedGLEnums_autogen.cpp",
    "angle/src/common/PoolAlloc.cpp",
    "angle/src/common/SimpleMutex.cpp",
    "angle/src/common/WorkerThread.cpp",
    "angle/src/common/aligned_memory.cpp",
    "angle/src/common/android_util.cpp",
    "angle/src/common/angle_version_info.cpp",
    "angle/src/common/angleutils.cpp",
    "angle/src/common/debug.cpp",
    "angle/src/common/entry_points_enum_autogen.cpp",
    "angle/src/common/event_tracer.cpp",
    "angle/src/common/gl_enum_utils.cpp",
    "angle/src/common/gl_enum_utils_autogen.cpp",
    "angle/src/common/mathutil.cpp",
    "angle/src/common/matrix_utils.cpp",
    "angle/src/common/platform_helpers.cpp",
    "angle/src/common/string_utils.cpp",
    "angle/src/common/system_utils.cpp",
    "angle/src/common/tls.cpp",
    "angle/src/common/uniform_type_info_autogen.cpp",
    "angle/src/common/utilities.cpp",
    "angle/src/common/base/anglebase/sha1.cc",
    "angle/src/compiler/preprocessor/DiagnosticsBase.cpp",
    "angle/src/compiler/preprocessor/DirectiveHandlerBase.cpp",
    "angle/src/compiler/preprocessor/DirectiveParser.cpp",
    "angle/src/compiler/preprocessor/Input.cpp",
    "angle/src/compiler/preprocessor/Lexer.cpp",
    "angle/src/compiler/preprocessor/Macro.cpp",
    "angle/src/compiler/preprocessor/MacroExpander.cpp",
    "angle/src/compiler/preprocessor/Preprocessor.cpp",
    "angle/src/compiler/preprocessor/Token.cpp",
    "angle/src/compiler/preprocessor/preprocessor_lex_autogen.cpp",
    "angle/src/compiler/preprocessor/preprocessor_tab_autogen.cpp",
    "angle/src/compiler/translator/BaseTypes.cpp",
    "angle/src/compiler/translator/BuiltInFunctionEmulator.cpp",
    "angle/src/compiler/translator/CallDAG.cpp",
    "angle/src/compiler/translator/CodeGen.cpp",
    "angle/src/compiler/translator/CollectVariables.cpp",
    "angle/src/compiler/translator/Compiler.cpp",
    "angle/src/compiler/translator/ConstantUnion.cpp",
    "angle/src/compiler/translator/Declarator.cpp",
    "angle/src/compiler/translator/Diagnostics.cpp",
    "angle/src/compiler/translator/DirectiveHandler.cpp",
    "angle/src/compiler/translator/ExtensionBehavior.cpp",
    "angle/src/compiler/translator/FlagStd140Structs.cpp",
    "angle/src/compiler/translator/FunctionLookup.cpp",
    "angle/src/compiler/translator/HashNames.cpp",
    "angle/src/compiler/translator/ImmutableStringBuilder.cpp",
    "angle/src/compiler/translator/ImmutableString_autogen.cpp",
    "angle/src/compiler/translator/InfoSink.cpp",
    "angle/src/compiler/translator/Initialize.cpp",
    "angle/src/compiler/translator/InitializeDll.cpp",
    "angle/src/compiler/translator/IntermNode.cpp",
    "angle/src/compiler/translator/IntermRebuild.cpp",
    "angle/src/compiler/translator/IsASTDepthBelowLimit.cpp",
    "angle/src/compiler/translator/Name.cpp",
    "angle/src/compiler/translator/Operator.cpp",
    "angle/src/compiler/translator/OutputTree.cpp",
    "angle/src/compiler/translator/ParseContext.cpp",
    "angle/src/compiler/translator/PoolAlloc.cpp",
    "angle/src/compiler/translator/QualifierTypes.cpp",
    "angle/src/compiler/translator/ShaderLang.cpp",
    "angle/src/compiler/translator/ShaderVars.cpp",
    "angle/src/compiler/translator/Symbol.cpp",
    "angle/src/compiler/translator/SymbolTable.cpp",
    "angle/src/compiler/translator/SymbolTable_autogen.cpp",
    "angle/src/compiler/translator/SymbolUniqueId.cpp",
    "angle/src/compiler/translator/Types.cpp",
    "angle/src/compiler/translator/ValidateAST.cpp",
    "angle/src/compiler/translator/ValidateBarrierFunctionCall.cpp",
    "angle/src/compiler/translator/ValidateClipCullDistance.cpp",
    "angle/src/compiler/translator/ValidateGlobalInitializer.cpp",
    "angle/src/compiler/translator/ValidateLimitations.cpp",
    "angle/src/compiler/translator/ValidateMaxParameters.cpp",
    "angle/src/compiler/translator/ValidateOutputs.cpp",
    "angle/src/compiler/translator/ValidateSwitch.cpp",
    "angle/src/compiler/translator/ValidateTypeSizeLimitations.cpp",
    "angle/src/compiler/translator/ValidateVaryingLocations.cpp",
    "angle/src/compiler/translator/VariablePacker.cpp",
    "angle/src/compiler/translator/blocklayout.cpp",
    "angle/src/compiler/translator/glslang_lex_autogen.cpp",
    "angle/src/compiler/translator/glslang_tab_autogen.cpp",
    "angle/src/compiler/translator/util.cpp",
    "angle/src/compiler/translator/glsl/BuiltInFunctionEmulatorGLSL.cpp",
    "angle/src/compiler/translator/glsl/ExtensionGLSL.cpp",
    "angle/src/compiler/translator/glsl/OutputESSL.cpp",
    "angle/src/compiler/translator/glsl/OutputGLSL.cpp",
    "angle/src/compiler/translator/glsl/OutputGLSLBase.cpp",
    "angle/src/compiler/translator/glsl/TranslatorESSL.cpp",
    "angle/src/compiler/translator/glsl/TranslatorGLSL.cpp",
    "angle/src/compiler/translator/glsl/VersionGLSL.cpp",
    "angle/src/compiler/translator/tree_ops/ClampFragDepth.cpp",
    "angle/src/compiler/translator/tree_ops/ClampIndirectIndices.cpp",
    "angle/src/compiler/translator/tree_ops/ClampPointSize.cpp",
    "angle/src/compiler/translator/tree_ops/DeclareAndInitBuiltinsForInstancedMultiview.cpp",
    "angle/src/compiler/translator/tree_ops/DeclarePerVertexBlocks.cpp",
    "angle/src/compiler/translator/tree_ops/DeferGlobalInitializers.cpp",
    "angle/src/compiler/translator/tree_ops/EmulateGLFragColorBroadcast.cpp",
    "angle/src/compiler/translator/tree_ops/EmulateMultiDrawShaderBuiltins.cpp",
    "angle/src/compiler/translator/tree_ops/FoldExpressions.cpp",
    "angle/src/compiler/translator/tree_ops/ForcePrecisionQualifier.cpp",
    "angle/src/compiler/translator/tree_ops/InitializeVariables.cpp",
    "angle/src/compiler/translator/tree_ops/MonomorphizeUnsupportedFunctions.cpp",
    "angle/src/compiler/translator/tree_ops/PreTransformTextureCubeGradDerivatives.cpp",
    "angle/src/compiler/translator/tree_ops/PruneEmptyCases.cpp",
    "angle/src/compiler/translator/tree_ops/PruneInfiniteLoops.cpp",
    "angle/src/compiler/translator/tree_ops/PruneNoOps.cpp",
    "angle/src/compiler/translator/tree_ops/RecordConstantPrecision.cpp",
    "angle/src/compiler/translator/tree_ops/ReduceInterfaceBlocks.cpp",
    "angle/src/compiler/translator/tree_ops/RemoveArrayLengthMethod.cpp",
    "angle/src/compiler/translator/tree_ops/RemoveAtomicCounterBuiltins.cpp",
    "angle/src/compiler/translator/tree_ops/RemoveDynamicIndexing.cpp",
    "angle/src/compiler/translator/tree_ops/RemoveInactiveInterfaceVariables.cpp",
    "angle/src/compiler/translator/tree_ops/RemoveInvariantDeclaration.cpp",
    "angle/src/compiler/translator/tree_ops/RemoveUnreferencedVariables.cpp",
    "angle/src/compiler/translator/tree_ops/RemoveUnusedFramebufferFetch.cpp",
    "angle/src/compiler/translator/tree_ops/RescopeGlobalVariables.cpp",
    "angle/src/compiler/translator/tree_ops/RewriteArrayOfArrayOfOpaqueUniforms.cpp",
    "angle/src/compiler/translator/tree_ops/RewriteAtomicCounters.cpp",
    "angle/src/compiler/translator/tree_ops/RewriteDfdy.cpp",
    "angle/src/compiler/translator/tree_ops/RewritePixelLocalStorage.cpp",
    "angle/src/compiler/translator/tree_ops/RewriteStructSamplers.cpp",
    "angle/src/compiler/translator/tree_ops/RewriteTexelFetchOffset.cpp",
    "angle/src/compiler/translator/tree_ops/ScalarizeVecAndMatConstructorArgs.cpp",
    "angle/src/compiler/translator/tree_ops/SeparateDeclarations.cpp",
    "angle/src/compiler/translator/tree_ops/SeparateStructFromUniformDeclarations.cpp",
    "angle/src/compiler/translator/tree_ops/SimplifyLoopConditions.cpp",
    "angle/src/compiler/translator/tree_ops/SplitSequenceOperator.cpp",
    "angle/src/compiler/translator/tree_ops/glsl/RegenerateStructNames.cpp",
    "angle/src/compiler/translator/tree_ops/glsl/RewriteRepeatedAssignToSwizzled.cpp",
    "angle/src/compiler/translator/tree_ops/glsl/UseInterfaceBlockFields.cpp",
    "angle/src/compiler/translator/tree_util/DriverUniform.cpp",
    "angle/src/compiler/translator/tree_util/FindFunction.cpp",
    "angle/src/compiler/translator/tree_util/FindMain.cpp",
    "angle/src/compiler/translator/tree_util/FindPreciseNodes.cpp",
    "angle/src/compiler/translator/tree_util/FindSymbolNode.cpp",
    "angle/src/compiler/translator/tree_util/IntermNodePatternMatcher.cpp",
    "angle/src/compiler/translator/tree_util/IntermNode_util.cpp",
    "angle/src/compiler/translator/tree_util/IntermTraverse.cpp",
    "angle/src/compiler/translator/tree_util/ReplaceArrayOfMatrixVarying.cpp",
    "angle/src/compiler/translator/tree_util/ReplaceClipCullDistanceVariable.cpp",
    "angle/src/compiler/translator/tree_util/ReplaceShadowingVariables.cpp",
    "angle/src/compiler/translator/tree_util/ReplaceVariable.cpp",
    "angle/src/compiler/translator/tree_util/RewriteSampleMaskVariable.cpp",
    "angle/src/compiler/translator/tree_util/RunAtTheBeginningOfShader.cpp",
    "angle/src/compiler/translator/tree_util/RunAtTheEndOfShader.cpp",
    "angle/src/compiler/translator/tree_util/SpecializationConstant.cpp",
    "angle/src/gpu_info_util/SystemInfo.cpp",
    "angle/src/libANGLE/AttributeMap.cpp",
    "angle/src/libANGLE/BlobCache.cpp",
    "angle/src/libANGLE/Buffer.cpp",
    "angle/src/libANGLE/Caps.cpp",
    "angle/src/libANGLE/Compiler.cpp",
    "angle/src/libANGLE/Config.cpp",
    "angle/src/libANGLE/Context.cpp",
    "angle/src/libANGLE/ContextMutex.cpp",
    "angle/src/libANGLE/Context_gles_1_0.cpp",
    "angle/src/libANGLE/Debug.cpp",
    "angle/src/libANGLE/Device.cpp",
    "angle/src/libANGLE/Display.cpp",
    "angle/src/libANGLE/EGLSync.cpp",
    "angle/src/libANGLE/Error.cpp",
    "angle/src/libANGLE/Fence.cpp",
    "angle/src/libANGLE/Framebuffer.cpp",
    "angle/src/libANGLE/FramebufferAttachment.cpp",
    "angle/src/libANGLE/GLES1Renderer.cpp",
    "angle/src/libANGLE/GLES1State.cpp",
    "angle/src/libANGLE/GlobalMutex.cpp",
    "angle/src/libANGLE/HandleAllocator.cpp",
    "angle/src/libANGLE/Image.cpp",
    "angle/src/libANGLE/ImageIndex.cpp",
    "angle/src/libANGLE/IndexRangeCache.cpp",
    "angle/src/libANGLE/LoggingAnnotator.cpp",
    "angle/src/libANGLE/MemoryObject.cpp",
    "angle/src/libANGLE/MemoryProgramCache.cpp",
    "angle/src/libANGLE/MemoryShaderCache.cpp",
    "angle/src/libANGLE/Observer.cpp",
    "angle/src/libANGLE/Overlay.cpp",
    "angle/src/libANGLE/OverlayWidgets.cpp",
    "angle/src/libANGLE/Overlay_autogen.cpp",
    "angle/src/libANGLE/Overlay_font_autogen.cpp",
    "angle/src/libANGLE/PixelLocalStorage.cpp",
    "angle/src/libANGLE/Platform.cpp",
    "angle/src/libANGLE/Program.cpp",
    "angle/src/libANGLE/ProgramExecutable.cpp",
    "angle/src/libANGLE/ProgramLinkedResources.cpp",
    "angle/src/libANGLE/ProgramPipeline.cpp",
    "angle/src/libANGLE/Query.cpp",
    "angle/src/libANGLE/Renderbuffer.cpp",
    "angle/src/libANGLE/ResourceManager.cpp",
    "angle/src/libANGLE/Sampler.cpp",
    "angle/src/libANGLE/Semaphore.cpp",
    "angle/src/libANGLE/Shader.cpp",
    "angle/src/libANGLE/ShareGroup.cpp",
    "angle/src/libANGLE/State.cpp",
    "angle/src/libANGLE/Stream.cpp",
    "angle/src/libANGLE/Surface.cpp",
    "angle/src/libANGLE/Texture.cpp",
    "angle/src/libANGLE/Thread.cpp",
    "angle/src/libANGLE/TransformFeedback.cpp",
    "angle/src/libANGLE/Uniform.cpp",
    "angle/src/libANGLE/VaryingPacking.cpp",
    "angle/src/libANGLE/VertexArray.cpp",
    "angle/src/libANGLE/VertexAttribute.cpp",
    "angle/src/libANGLE/angletypes.cpp",
    "angle/src/libANGLE/es3_copy_conversion_table_autogen.cpp",
    "angle/src/libANGLE/format_map_autogen.cpp",
    "angle/src/libANGLE/formatutils.cpp",
    "angle/src/libANGLE/gles_extensions_autogen.cpp",
    "angle/src/libANGLE/queryconversions.cpp",
    "angle/src/libANGLE/queryutils.cpp",
    "angle/src/libANGLE/validationEGL.cpp",
    "angle/src/libANGLE/validationES.cpp",
    "angle/src/libANGLE/validationES1.cpp",
    "angle/src/libANGLE/validationES2.cpp",
    "angle/src/libANGLE/validationES3.cpp",
    "angle/src/libANGLE/validationES31.cpp",
    "angle/src/libANGLE/validationES32.cpp",
    "angle/src/libANGLE/validationESEXT.cpp",
    "angle/src/libANGLE/capture/FrameCapture_mock.cpp",
    "angle/src/libANGLE/capture/serialize_mock.cpp",
    "angle/src/libANGLE/renderer/BufferImpl.cpp",
    "angle/src/libANGLE/renderer/ContextImpl.cpp",
    "angle/src/libANGLE/renderer/DeviceImpl.cpp",
    "angle/src/libANGLE/renderer/DisplayImpl.cpp",
    "angle/src/libANGLE/renderer/EGLReusableSync.cpp",
    "angle/src/libANGLE/renderer/EGLSyncImpl.cpp",
    "angle/src/libANGLE/renderer/Format_table_autogen.cpp",
    "angle/src/libANGLE/renderer/FramebufferImpl.cpp",
    "angle/src/libANGLE/renderer/ImageImpl.cpp",
    "angle/src/libANGLE/renderer/ProgramImpl.cpp",
    "angle/src/libANGLE/renderer/ProgramPipelineImpl.cpp",
    "angle/src/libANGLE/renderer/QueryImpl.cpp",
    "angle/src/libANGLE/renderer/RenderbufferImpl.cpp",
    "angle/src/libANGLE/renderer/ShaderImpl.cpp",
    "angle/src/libANGLE/renderer/SurfaceImpl.cpp",
    "angle/src/libANGLE/renderer/TextureImpl.cpp",
    "angle/src/libANGLE/renderer/TransformFeedbackImpl.cpp",
    "angle/src/libANGLE/renderer/VertexArrayImpl.cpp",
    "angle/src/libANGLE/renderer/driver_utils.cpp",
    "angle/src/libANGLE/renderer/load_functions_table_autogen.cpp",
    "angle/src/libANGLE/renderer/renderer_utils.cpp",
    "angle/src/image_util/AstcDecompressor.cpp",
    "angle/src/image_util/copyimage.cpp",
    "angle/src/image_util/imageformats.cpp",
    "angle/src/image_util/loadimage_astc.cpp",
    "angle/src/image_util/loadimage_etc.cpp",
    "angle/src/image_util/loadimage_paletted.cpp",
    "angle/src/image_util/loadimage.cpp",
    "angle/src/image_util/storeimage_paletted.cpp",
    "angle/src/common/third_party/xxhash/xxhash.c",
];

ZLIB_FILES :: string.[
    "zlib/google/compression_utils_portable.cc",
    "zlib/adler32.c",
    "zlib/compress.c",
    "zlib/cpu_features.c",
    "zlib/crc_folding.c",
    "zlib/crc32.c",
    "zlib/deflate.c",
    "zlib/gzclose.c",
    "zlib/gzlib.c",
    "zlib/gzread.c",
    "zlib/gzwrite.c",
    "zlib/infback.c",
    "zlib/inffast.c",
    "zlib/inflate.c",
    "zlib/inftrees.c",
    "zlib/trees.c",
    "zlib/uncompr.c",
    "zlib/zutil.c",
];

ASTCENC_FILES :: string.[
    "astc-encoder/Source/astcenc_averages_and_directions.cpp",
    "astc-encoder/Source/astcenc_block_sizes.cpp",
    "astc-encoder/Source/astcenc_color_quantize.cpp",
    "astc-encoder/Source/astcenc_color_unquantize.cpp",
    "astc-encoder/Source/astcenc_compress_symbolic.cpp",
    "astc-encoder/Source/astcenc_compute_variance.cpp",
    "astc-encoder/Source/astcenc_decompress_symbolic.cpp",
    "astc-encoder/Source/astcenc_diagnostic_trace.cpp",
    "astc-encoder/Source/astcenc_entry.cpp",
    "astc-encoder/Source/astcenc_find_best_partitioning.cpp",
    "astc-encoder/Source/astcenc_ideal_endpoints_and_weights.cpp",
    "astc-encoder/Source/astcenc_image.cpp",
    "astc-encoder/Source/astcenc_integer_sequence.cpp",
    "astc-encoder/Source/astcenc_mathlib.cpp",
    "astc-encoder/Source/astcenc_mathlib_softfloat.cpp",
    "astc-encoder/Source/astcenc_partition_tables.cpp",
    "astc-encoder/Source/astcenc_percentile_tables.cpp",
    "astc-encoder/Source/astcenc_pick_best_endpoint_format.cpp",
    "astc-encoder/Source/astcenc_platform_isa_detection.cpp",
    "astc-encoder/Source/astcenc_quantization.cpp",
    "astc-encoder/Source/astcenc_symbolic_physical.cpp",
    "astc-encoder/Source/astcenc_weight_align.cpp",
    "astc-encoder/Source/astcenc_weight_quant_xfer_tables.cpp",
];

ANGLE_FILES_IOS :: string.[
    "angle/src/gpu_info_util/SystemInfo_ios.cpp",
    "angle/src/libANGLE/renderer/driver_utils_ios.mm",
];

ANGLE_FILES_MACOS :: string.[
    "angle/src/gpu_info_util/SystemInfo_macos.mm",
    "angle/src/common/gl/cgl/FunctionsCGL.cpp",
    "angle/src/libANGLE/renderer/gl/cgl/ContextCGL.cpp",
    "angle/src/libANGLE/renderer/gl/cgl/DeviceCGL.cpp",
    "angle/src/libANGLE/renderer/gl/cgl/DisplayCGL.mm",
    "angle/src/libANGLE/renderer/gl/cgl/IOSurfaceSurfaceCGL.cpp",
    "angle/src/libANGLE/renderer/gl/cgl/PbufferSurfaceCGL.cpp",
    "angle/src/libANGLE/renderer/gl/cgl/WindowSurfaceCGL.mm",
];

ANGLE_FILES_MACOS_AND_IOS :: string.[
    "angle/src/common/apple_platform_utils.mm",
    "angle/src/common/system_utils_posix.cpp",
    "angle/src/compiler/translator/msl/AstHelpers.cpp",
    "angle/src/compiler/translator/msl/ConstantNames.cpp",
    "angle/src/compiler/translator/msl/DiscoverDependentFunctions.cpp",
    "angle/src/compiler/translator/msl/DiscoverEnclosingFunctionTraverser.cpp",
    "angle/src/compiler/translator/msl/DriverUniformMetal.cpp",
    "angle/src/compiler/translator/msl/EmitMetal.cpp",
    "angle/src/compiler/translator/msl/IdGen.cpp",
    "angle/src/compiler/translator/msl/Layout.cpp",
    "angle/src/compiler/translator/msl/MapFunctionsToDefinitions.cpp",
    "angle/src/compiler/translator/msl/MapSymbols.cpp",
    "angle/src/compiler/translator/msl/ModifyStruct.cpp",
    "angle/src/compiler/translator/msl/Pipeline.cpp",
    "angle/src/compiler/translator/msl/ProgramPrelude.cpp",
    "angle/src/compiler/translator/msl/RewritePipelines.cpp",
    "angle/src/compiler/translator/msl/SymbolEnv.cpp",
    "angle/src/compiler/translator/msl/ToposortStructs.cpp",
    "angle/src/compiler/translator/msl/TranslatorMSL.cpp",
    "angle/src/compiler/translator/msl/UtilsMSL.cpp",
    "angle/src/compiler/translator/tree_ops/glsl/apple/AddAndTrueToLoopCondition.cpp",
    "angle/src/compiler/translator/tree_ops/glsl/apple/RewriteDoWhile.cpp",
    "angle/src/compiler/translator/tree_ops/glsl/apple/RewriteRowMajorMatrices.cpp",
    "angle/src/compiler/translator/tree_ops/glsl/apple/RewriteUnaryMinusOperatorFloat.cpp",
    "angle/src/compiler/translator/tree_ops/glsl/apple/UnfoldShortCircuitAST.cpp",
    "angle/src/compiler/translator/tree_ops/msl/AddExplicitTypeCasts.cpp",
    "angle/src/compiler/translator/tree_ops/msl/ConvertUnsupportedConstructorsToFunctionCalls.cpp",
    "angle/src/compiler/translator/tree_ops/msl/FixTypeConstructors.cpp",
    "angle/src/compiler/translator/tree_ops/msl/GuardFragDepthWrite.cpp",
    "angle/src/compiler/translator/tree_ops/msl/HoistConstants.cpp",
    "angle/src/compiler/translator/tree_ops/msl/IntroduceVertexIndexID.cpp",
    "angle/src/compiler/translator/tree_ops/msl/RewriteCaseDeclarations.cpp",
    "angle/src/compiler/translator/tree_ops/msl/RewriteInterpolants.cpp",
    "angle/src/compiler/translator/tree_ops/msl/RewriteOutArgs.cpp",
    "angle/src/compiler/translator/tree_ops/msl/RewriteUnaddressableReferences.cpp",
    "angle/src/compiler/translator/tree_ops/msl/SeparateCompoundExpressions.cpp",
    "angle/src/compiler/translator/tree_ops/msl/TransposeRowMajorMatrices.cpp",
    "angle/src/compiler/translator/tree_ops/msl/WrapMain.cpp",
    "angle/src/gpu_info_util/SystemInfo_apple.mm",
    "angle/src/libANGLE/renderer/driver_utils_mac.mm",
    "angle/src/libANGLE/renderer/metal/BufferMtl.mm",
    "angle/src/libANGLE/renderer/metal/CompilerMtl.mm",
    "angle/src/libANGLE/renderer/metal/ContextMtl.mm",
    "angle/src/libANGLE/renderer/metal/DeviceMtl.mm",
    "angle/src/libANGLE/renderer/metal/DisplayMtl.mm",
    "angle/src/libANGLE/renderer/metal/FrameBufferMtl.mm",
    "angle/src/libANGLE/renderer/metal/IOSurfaceSurfaceMtl.mm",
    "angle/src/libANGLE/renderer/metal/ImageMtl.mm",
    "angle/src/libANGLE/renderer/metal/ProgramExecutableMtl.mm",
    "angle/src/libANGLE/renderer/metal/ProgramMtl.mm",
    "angle/src/libANGLE/renderer/metal/ProvokingVertexHelper.mm",
    "angle/src/libANGLE/renderer/metal/QueryMtl.mm",
    "angle/src/libANGLE/renderer/metal/RenderBufferMtl.mm",
    "angle/src/libANGLE/renderer/metal/RenderTargetMtl.mm",
    "angle/src/libANGLE/renderer/metal/SamplerMtl.mm",
    "angle/src/libANGLE/renderer/metal/ShaderMtl.mm",
    "angle/src/libANGLE/renderer/metal/SurfaceMtl.mm",
    "angle/src/libANGLE/renderer/metal/SyncMtl.mm",
    "angle/src/libANGLE/renderer/metal/TextureMtl.mm",
    "angle/src/libANGLE/renderer/metal/TransformFeedbackMtl.mm",
    "angle/src/libANGLE/renderer/metal/VertexArrayMtl.mm",
    "angle/src/libANGLE/renderer/metal/blocklayoutMetal.cpp",
    "angle/src/libANGLE/renderer/metal/mtl_buffer_manager.mm",
    "angle/src/libANGLE/renderer/metal/mtl_buffer_pool.mm",
    "angle/src/libANGLE/renderer/metal/mtl_command_buffer.mm",
    "angle/src/libANGLE/renderer/metal/mtl_common.mm",
    "angle/src/libANGLE/renderer/metal/mtl_context_device.mm",
    "angle/src/libANGLE/renderer/metal/mtl_format_table_autogen.mm",
    "angle/src/libANGLE/renderer/metal/mtl_format_utils.mm",
    "angle/src/libANGLE/renderer/metal/mtl_library_cache.mm",
    "angle/src/libANGLE/renderer/metal/mtl_msl_utils.mm",
    "angle/src/libANGLE/renderer/metal/mtl_occlusion_query_pool.mm",
    "angle/src/libANGLE/renderer/metal/mtl_pipeline_cache.mm",
    "angle/src/libANGLE/renderer/metal/mtl_render_utils.mm",
    "angle/src/libANGLE/renderer/metal/mtl_resources.mm",
    "angle/src/libANGLE/renderer/metal/mtl_state_cache.mm",
    "angle/src/libANGLE/renderer/metal/mtl_utils.mm",
    "angle/src/libANGLE/renderer/metal/renderermtl_utils.cpp",
    "angle/src/libANGLE/renderer/gl/BlitGL.cpp",
    "angle/src/libANGLE/renderer/gl/BufferGL.cpp",
    "angle/src/libANGLE/renderer/gl/ClearMultiviewGL.cpp",
    "angle/src/libANGLE/renderer/gl/CompilerGL.cpp",
    "angle/src/libANGLE/renderer/gl/ContextGL.cpp",
    "angle/src/libANGLE/renderer/gl/DispatchTableGL_autogen.cpp",
    "angle/src/libANGLE/renderer/gl/DisplayGL.cpp",
    "angle/src/libANGLE/renderer/gl/FenceNVGL.cpp",
    "angle/src/libANGLE/renderer/gl/FramebufferGL.cpp",
    "angle/src/libANGLE/renderer/gl/FunctionsGL.cpp",
    "angle/src/libANGLE/renderer/gl/ImageGL.cpp",
    "angle/src/libANGLE/renderer/gl/MemoryObjectGL.cpp",
    "angle/src/libANGLE/renderer/gl/ProgramExecutableGL.cpp",
    "angle/src/libANGLE/renderer/gl/ProgramGL.cpp",
    "angle/src/libANGLE/renderer/gl/ProgramPipelineGL.cpp",
    "angle/src/libANGLE/renderer/gl/QueryGL.cpp",
    "angle/src/libANGLE/renderer/gl/RenderbufferGL.cpp",
    "angle/src/libANGLE/renderer/gl/RendererGL.cpp",
    "angle/src/libANGLE/renderer/gl/SamplerGL.cpp",
    "angle/src/libANGLE/renderer/gl/SemaphoreGL.cpp",
    "angle/src/libANGLE/renderer/gl/ShaderGL.cpp",
    "angle/src/libANGLE/renderer/gl/StateManagerGL.cpp",
    "angle/src/libANGLE/renderer/gl/SurfaceGL.cpp",
    "angle/src/libANGLE/renderer/gl/SyncGL.cpp",
    "angle/src/libANGLE/renderer/gl/TextureGL.cpp",
    "angle/src/libANGLE/renderer/gl/TransformFeedbackGL.cpp",
    "angle/src/libANGLE/renderer/gl/VertexArrayGL.cpp",
    "angle/src/libANGLE/renderer/gl/formatutilsgl.cpp",
    "angle/src/libANGLE/renderer/gl/null_functions.cpp",
    "angle/src/libangle/renderer/gl/renderergl_utils.cpp",

    // Using these macos files on ios because the ios one is missing functions (?)
    "angle/src/common/system_utils_apple.cpp",
    "angle/src/common/system_utils_mac.cpp",
    // "angle/src/common/system_utils_ios.mm",
];

ANGLE_FILES_WINDOWS :: string.[
    "angle/src/common/system_utils_win.cpp",
    "angle/src/common/system_utils_win32.cpp",
    "angle/src/compiler/translator/hlsl/ASTMetadataHLSL.cpp",
    "angle/src/compiler/translator/hlsl/AtomicCounterFunctionHLSL.cpp",
    "angle/src/compiler/translator/hlsl/BuiltInFunctionEmulatorHLSL.cpp",
    "angle/src/compiler/translator/hlsl/ImageFunctionHLSL.cpp",
    "angle/src/compiler/translator/hlsl/OutputHLSL.cpp",
    "angle/src/compiler/translator/hlsl/ResourcesHLSL.cpp",
    "angle/src/compiler/translator/hlsl/ShaderStorageBlockFunctionHLSL.cpp",
    "angle/src/compiler/translator/hlsl/ShaderStorageBlockOutputHLSL.cpp",
    "angle/src/compiler/translator/hlsl/StructureHLSL.cpp",
    "angle/src/compiler/translator/hlsl/TextureFunctionHLSL.cpp",
    "angle/src/compiler/translator/hlsl/TranslatorHLSL.cpp",
    "angle/src/compiler/translator/hlsl/UtilsHLSL.cpp",
    "angle/src/compiler/translator/hlsl/blocklayoutHLSL.cpp",
    "angle/src/compiler/translator/hlsl/emulated_builtin_functions_hlsl_autogen.cpp",
    "angle/src/compiler/translator/tree_ops/hlsl/AddDefaultReturnStatements.cpp",
    "angle/src/compiler/translator/tree_ops/hlsl/AggregateAssignArraysInSSBOs.cpp",
    "angle/src/compiler/translator/tree_ops/hlsl/AggregateAssignStructsInSSBOs.cpp",
    "angle/src/compiler/translator/tree_ops/hlsl/ArrayReturnValueToOutParameter.cpp",
    "angle/src/compiler/translator/tree_ops/hlsl/BreakVariableAliasingInInnerLoops.cpp",
    "angle/src/compiler/translator/tree_ops/hlsl/ExpandIntegerPowExpressions.cpp",
    "angle/src/compiler/translator/tree_ops/hlsl/RecordUniformBlocksWithLargeArrayMember.cpp",
    "angle/src/compiler/translator/tree_ops/hlsl/RemoveSwitchFallThrough.cpp",
    "angle/src/compiler/translator/tree_ops/hlsl/RewriteAtomicFunctionExpressions.cpp",
    "angle/src/compiler/translator/tree_ops/hlsl/RewriteElseBlocks.cpp",
    "angle/src/compiler/translator/tree_ops/hlsl/RewriteExpressionsWithShaderStorageBlock.cpp",
    "angle/src/compiler/translator/tree_ops/hlsl/RewriteUnaryMinusOperatorInt.cpp",
    "angle/src/compiler/translator/tree_ops/hlsl/SeparateArrayConstructorStatements.cpp",
    "angle/src/compiler/translator/tree_ops/hlsl/SeparateArrayInitialization.cpp",
    "angle/src/compiler/translator/tree_ops/hlsl/SeparateExpressionsReturningArrays.cpp",
    "angle/src/compiler/translator/tree_ops/hlsl/UnfoldShortCircuitToIf.cpp",
    "angle/src/compiler/translator/tree_ops/hlsl/WrapSwitchStatementsInBlocks.cpp",
    "angle/src/gpu_info_util/SystemInfo_win.cpp",
    "angle/src/libANGLE/renderer/d3d_format.cpp",
    "angle/src/libANGLE/renderer/dxgi_format_map_autogen.cpp",
    "angle/src/libANGLE/renderer/dxgi_support_table_autogen.cpp",
    "angle/src/libANGLE/renderer/d3d/BufferD3D.cpp",
    "angle/src/libANGLE/renderer/d3d/CompilerD3D.cpp",
    "angle/src/libANGLE/renderer/d3d/DisplayD3D.cpp",
    "angle/src/libANGLE/renderer/d3d/DynamicHLSL.cpp",
    "angle/src/libANGLE/renderer/d3d/DynamicImage2DHLSL.cpp",
    "angle/src/libANGLE/renderer/d3d/EGLImageD3D.cpp",
    "angle/src/libANGLE/renderer/d3d/FramebufferD3D.cpp",
    "angle/src/libANGLE/renderer/d3d/HLSLCompiler.cpp",
    "angle/src/libANGLE/renderer/d3d/ImageD3D.cpp",
    "angle/src/libANGLE/renderer/d3d/IndexBuffer.cpp",
    "angle/src/libANGLE/renderer/d3d/IndexDataManager.cpp",
    "angle/src/libANGLE/renderer/d3d/NativeWindowD3D.cpp",
    "angle/src/libANGLE/renderer/d3d/ProgramD3D.cpp",
    "angle/src/libANGLE/renderer/d3d/ProgramExecutableD3D.cpp",
    "angle/src/libANGLE/renderer/d3d/RenderTargetD3D.cpp",
    "angle/src/libANGLE/renderer/d3d/RenderbufferD3D.cpp",
    "angle/src/libANGLE/renderer/d3d/RendererD3D.cpp",
    "angle/src/libANGLE/renderer/d3d/ShaderD3D.cpp",
    "angle/src/libANGLE/renderer/d3d/ShaderExecutableD3D.cpp",
    "angle/src/libANGLE/renderer/d3d/SurfaceD3D.cpp",
    "angle/src/libANGLE/renderer/d3d/SwapChainD3D.cpp",
    "angle/src/libANGLE/renderer/d3d/TextureD3D.cpp",
    "angle/src/libANGLE/renderer/d3d/VertexBuffer.cpp",
    "angle/src/libANGLE/renderer/d3d/VertexDataManager.cpp",
    "angle/src/libANGLE/renderer/d3d/driver_utils_d3d.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/Blit11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/Buffer11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/Clear11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/Context11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/DebugAnnotator11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/Device11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/ExternalImageSiblingImpl11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/Fence11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/Framebuffer11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/Image11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/IndexBuffer11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/InputLayoutCache.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/MappedSubresourceVerifier11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/PixelTransfer11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/Program11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/ProgramPipeline11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/Query11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/RenderStateCache.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/RenderTarget11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/Renderer11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/ResourceManager11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/ShaderExecutable11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/StateManager11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/StreamProducerD3DTexture.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/SwapChain11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/TextureStorage11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/TransformFeedback11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/Trim11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/VertexArray11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/VertexBuffer11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/formatutils11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/renderer11_utils.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/texture_format_table.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/texture_format_table_autogen.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/converged/CompositorNativeWindow11.cpp",
    "angle/src/libANGLE/renderer/d3d/d3d11/win32/NativeWindow11Win32.cpp",
];

ANGLE_FILES_LINUX :: string.[
    "angle/src/common/system_utils_linux.cpp",
    "angle/src/common/system_utils_posix.cpp",
    "angle/src/common/linux/dma_buf_utils.cpp",
    "angle/src/common/spirv/spirv_instruction_builder_autogen.cpp",
    "angle/src/common/spirv/spirv_instruction_parser_autogen.cpp",
    "angle/src/common/vulkan/libvulkan_loader.cpp",
    "angle/src/common/vulkan/vulkan_icd.cpp",
    "angle/src/compiler/translator/spirv/BuildSPIRV.cpp",
    "angle/src/compiler/translator/spirv/BuiltinsWorkaround.cpp",
    "angle/src/compiler/translator/spirv/OutputSPIRV.cpp",
    "angle/src/compiler/translator/spirv/TranslatorSPIRV.cpp",
    "angle/src/compiler/translator/tree_ops/spirv/ClampGLLayer.cpp",
    "angle/src/compiler/translator/tree_ops/spirv/EmulateAdvancedBlendEquations.cpp",
    "angle/src/compiler/translator/tree_ops/spirv/EmulateDithering.cpp",
    "angle/src/compiler/translator/tree_ops/spirv/EmulateFragColorData.cpp",
    "angle/src/compiler/translator/tree_ops/spirv/EmulateFramebufferFetch.cpp",
    "angle/src/compiler/translator/tree_ops/spirv/EmulateYUVBuiltIns.cpp",
    "angle/src/compiler/translator/tree_ops/spirv/FlagSamplersWithTexelFetch.cpp",
    "angle/src/compiler/translator/tree_ops/spirv/ReswizzleYUVOps.cpp",
    "angle/src/compiler/translator/tree_ops/spirv/RewriteInterpolateAtOffset.cpp",
    "angle/src/compiler/translator/tree_ops/spirv/RewriteR32fImages.cpp",
    "angle/src/compiler/translator/tree_ops/spirv/RewriteSamplerExternalTexelFetch.cpp",
    "angle/src/gpu_info_util/SystemInfo_linux.cpp",
    "angle/src/gpu_info_util/SystemInfo_vulkan.cpp",
    "angle/src/libANGLE/renderer/vulkan/AllocatorHelperPool.cpp",
    "angle/src/libANGLE/renderer/vulkan/BufferVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/CommandQueue.cpp",
    "angle/src/libANGLE/renderer/vulkan/CompilerVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/ContextVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/DebugAnnotatorVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/DeviceVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/DisplayVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/FenceNVVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/FramebufferVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/ImageVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/MemoryObjectVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/MemoryTracking.cpp",
    "angle/src/libANGLE/renderer/vulkan/OverlayVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/PersistentCommandPool.cpp",
    "angle/src/libANGLE/renderer/vulkan/ProgramExecutableVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/ProgramPipelineVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/ProgramVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/QueryVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/RenderTargetVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/RenderbufferVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/SamplerVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/SecondaryCommandBuffer.cpp",
    "angle/src/libANGLE/renderer/vulkan/SecondaryCommandPool.cpp",
    "angle/src/libANGLE/renderer/vulkan/SemaphoreVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/ShaderInterfaceVariableInfoMap.cpp",
    "angle/src/libANGLE/renderer/vulkan/ShaderVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/ShareGroupVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/Suballocation.cpp",
    "angle/src/libANGLE/renderer/vulkan/SurfaceVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/SyncVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/TextureVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/TransformFeedbackVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/UtilsVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/VertexArrayVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/VkImageImageSiblingVk.cpp",
    "angle/src/libANGLE/renderer/vulkan/VulkanSecondaryCommandBuffer.cpp",
    "angle/src/libANGLE/renderer/vulkan/spv_utils.cpp",
    "angle/src/libANGLE/renderer/vulkan/vk_cache_utils.cpp",
    "angle/src/libANGLE/renderer/vulkan/vk_caps_utils.cpp",
    "angle/src/libANGLE/renderer/vulkan/vk_format_table_autogen.cpp",
    "angle/src/libANGLE/renderer/vulkan/vk_format_utils.cpp",
    "angle/src/libANGLE/renderer/vulkan/vk_helpers.cpp",
    "angle/src/libANGLE/renderer/vulkan/vk_internal_shaders_autogen.cpp",
    "angle/src/libANGLE/renderer/vulkan/vk_mandatory_format_support_table_autogen.cpp",
    "angle/src/libANGLE/renderer/vulkan/vk_ref_counted_event.cpp",
    "angle/src/libANGLE/renderer/vulkan/vk_renderer.cpp",
    "angle/src/libANGLE/renderer/vulkan/vk_resource.cpp",
    "angle/src/libANGLE/renderer/vulkan/vk_utils.cpp",
    "angle/src/libANGLE/renderer/vulkan/vk_mem_alloc_wrapper.cpp",
    "angle/src/libANGLE/renderer/vulkan/linux/DeviceVkLinux.cpp",
    "angle/src/libANGLE/renderer/vulkan/linux/DisplayVkLinux.cpp",
    "angle/src/libANGLE/renderer/vulkan/linux/DisplayVkOffscreen.cpp",
    "angle/src/libANGLE/renderer/vulkan/linux/DmaBufImageSiblingVkLinux.cpp",
    "angle/src/libANGLE/renderer/vulkan/linux/xcb/DisplayVkXcb.cpp",
    "angle/src/libANGLE/renderer/vulkan/linux/xcb/WindowSurfaceVkXcb.cpp",
    // "angle/src/libANGLE/renderer/vulkan/linux/wayland/DisplayVkWayland.cpp",
    // "angle/src/libANGLE/renderer/vulkan/linux/wayland/WindowSurfaceVkWayland.cpp",
    "angle/src/libANGLE/renderer/vulkan/linux/headless/DisplayVkHeadless.cpp",
    "angle/src/libANGLE/renderer/vulkan/linux/headless/WindowSurfaceVkHeadless.cpp",
    "angle/src/libANGLE/renderer/vulkan/linux/gbm/DisplayVkGbm.cpp",
    "angle/src/libANGLE/renderer/vulkan/linux/display/DisplayVkSimple.cpp",
    "angle/src/libANGLE/renderer/vulkan/linux/display/WindowSurfaceVkSimple.cpp",
    "angle/src/libANGLE/renderer/vulkan/android/vk_android_utils.cpp",
    // "angle/src/third_party/volk/volk.c",
    "vma.cpp", 
];

ANGLE_FILES_EGL :: string.[
    "angle/src/libEGL/egl_loader_autogen.cpp",
    "angle/src/libEGL/libEGL_autogen.cpp",
];

ANGLE_FILES_GLES :: string.[
    "angle/src/libGLESv2/egl_ext_stubs.cpp",
    "angle/src/libGLESv2/egl_stubs.cpp",
    "angle/src/libGLESv2/egl_stubs_getprocaddress_autogen.cpp",
    "angle/src/libGLESv2/entry_points_egl_autogen.cpp",
    "angle/src/libGLESv2/entry_points_egl_ext_autogen.cpp",
    "angle/src/libGLESv2/entry_points_gles_1_0_autogen.cpp",
    "angle/src/libGLESv2/entry_points_gles_2_0_autogen.cpp",
    "angle/src/libGLESv2/entry_points_gles_3_0_autogen.cpp",
    "angle/src/libGLESv2/entry_points_gles_3_1_autogen.cpp",
    "angle/src/libGLESv2/entry_points_gles_3_2_autogen.cpp",
    "angle/src/libGLESv2/entry_points_gles_ext_autogen.cpp",
    "angle/src/libGLESv2/global_state.cpp",
    "angle/src/libGLESv2/libGLESv2_autogen.cpp",
];

ANGLE_DEFINES :: string.[
    "ANGLE_CAPTURE_ENABLED=0",
    "ANGLE_ENABLE_ESSL=1",
    "ANGLE_ENABLE_GLSL=1",
    "ANGLE_IS_64_BIT_CPU=1",
    "ANGLE_STANDALONE_BUILD=1",
    "ANGLE_STATIC=1",

    "ANGLE_ENABLE_GL_NULL=1",
    "ANGLE_ENABLE_EAGL=1",
    "GLES_SILENCE_DEPRECATION=1",

    "GL_SILENCE_DEPRECATION=1",

    "USE_AURA=1",
    "_HAS_EXCEPTIONS=0",
    "NDEBUG=1",
    "ANGLE_ENABLE_SHARE_CONTEXT_LOCK=1",
    "ANGLE_ENABLE_CONTEXT_MUTEX=1",
    "ANGLE_OUTSIDE_WEBKIT=1",

    // ANGLE
    "LIBANGLE_IMPLEMENTATION=1",

    // EGL
    "EGL_EGL_PROTOTYPES=1",
    "EGL_EGLEXT_PROTOTYPES=1",
    "GL_GLES_PROTOTYPES=1",
    "GL_GLEXT_PROTOTYPES=1",

    // GLES
    "LIBGLESV2_IMPLEMENTATION=1",

];

ANGLE_DEFINES_IOS :: string.[
    "ANGLE_PLATFORM_APPLE=1",
    "ANGLE_ENABLE_METAL=1",
];

ANGLE_DEFINES_MACOS :: string.[
    "ANGLE_PLATFORM_MACOS=1",
    "ANGLE_IS_MAC=1",
    "ANGLE_ENABLE_OPENGL=1",
    "ANGLE_ENABLE_METAL=1",
    "ANGLE_ENABLE_GL_DESKTOP_BACKEND=1",
    "ANGLE_ENABLE_CGL=1",
];

ANGLE_DEFINES_WINDOWS :: string.[
    "ANGLE_PLATFORM_WINDOWS=1",
    "ANGLE_IS_WIN=1",
    "ANGLE_WINDOWS_NO_FUTEX=1",
    "ANGLE_ENABLE_D3D11=1",
    "ANGLE_ENABLE_D3D11_COMPOSITOR_NATIVE_WINDOW=1",
    "ANGLE_ENABLE_HLSL=1",
    "ANGLE_PRELOADED_D3DCOMPILER_MODULE_NAMES={\"d2dcompiler_47.dll\",\"d2dcompiler_46.dll\",\"d2dcompiler_43.dll\"}",
    "NOMINMAX=1",
    "X86_WINDOWS=1",
    "WINVER=0x0A00",
    "_WIN32_WINNT=0x0A00",
    "ANGLE_EXPORT=__declspec(dllexport)",
    "ANGLE_UTIL_EXPORT=__declspec(dllexport)",
    "EGLAPI=__declspec(dllexport)",
    "GL_API=__declspec(dllexport)",
    "GL_APICALL=__declspec(dllexport)",
];

ANGLE_DEFINES_LINUX :: string.[
    "ANGLE_PLATFORM_LINUX=1",
    "ANGLE_ENABLE_VULKAN=1",
    "ANGLE_USE_VULKAN=1",
    "ANGLE_USE_PTHREADS=1",
    "ANGLE_IS_LINUX=1",
    "ANGLE_USE_X11",
    // "ANGLE_USE_WAYLAND",
    "_FILE_OFFSET_BITS=64",
    // "ANGLE_SHARED_LIBVULKAN=1",
    // "VK_NO_PROTOTYPES=1",
    "_POSIX_C_SOURCE=200112L",
    // "VK_KHR_WAYLAND_SURFACE_EXTENSION_NAME=VK_KHR_wayland_surface",
    // "VK_USE_PLATFORM_WAYLAND_KHR",
    "VK_KHR_XCB_SURFACE_EXTENSION_NAME=VK_KHR_xcb_surface",
    "VK_USE_PLATFORM_XCB_KHR",
    "ANGLE_VK_MOCK_ICD_JSON=\"$angle_data_dir/VkICD_mock_icd.json\"", // ???
];
