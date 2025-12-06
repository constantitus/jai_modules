//
//  Windows build plugin. Does the opposite of what modules/linux_build does.
//
//  To use this, you need to install msvc on linux and provide link.exe in your path.
//  You can install msvc on linux from this repository https://github.com/mstorsjo/msvc-wine
//

get_plugin :: () -> *Metaprogram_Plugin {
    p := New(Metaprogram_Plugin);

    p.before_intercept  = before_intercept;
    p.add_source        = add_source;
    p.message           = message;
    p.finish            = finish;
    p.shutdown          = shutdown;
    return p;
}

before_intercept :: (p: *Metaprogram_Plugin, flags: *Intercept_Flags) {
    options := get_build_options(p.workspace);

    options.os_target = .WINDOWS;
    options.use_custom_link_command = true;

    set_build_options(options, p.workspace);
}

add_source :: (p: *Metaprogram_Plugin) {}

// 'message' is called for each Compiler_Message received by the metaprogram.
message :: (p: *Metaprogram_Plugin, message: *Message) {
    if message.kind == .PHASE {
        mp := cast(*Message_Phase) message;

        if mp.phase == .PRE_WRITE_EXECUTABLE {
            print(".... The executable name will be: '%'\n", mp.executable_name);
        }

        if mp.phase == .READY_FOR_CUSTOM_LINK_COMMAND {
            mp.executable_name = run_windows_link_command(message.workspace, mp);
        }
    }
}

finish :: (p: *Metaprogram_Plugin) {
}

shutdown :: (p: *Metaprogram_Plugin) {
    free(p);
}

#scope_module

#import "Compiler";
#import "Basic";
#import "String";
#import "Process";

#assert(OS == .LINUX || OS == .MACOS);
#import "POSIX";

MSVC_LINKER :: "link.exe";

run_windows_link_command :: (ws: Workspace, m: *Message_Phase) -> string {
    opts := get_build_options(ws);
    output_filename := tprint("%/%", ifx opts.output_path else ".", m.executable_name);

    args: [..]string;

    array_add(*args, MSVC_LINKER, "/nologo");
    array_add(*args, .. m.compiler_generated_object_files);
    array_add(*args, tprint("/OUT:%", output_filename));
    array_add(*args, "/INCREMENTAL:NO", "/MACHINE:AMD64", "/DEBUG");
    array_add(*args, tprint("/IMPLIB:%/%.lib", opts.output_path, opts.output_executable_name));
    if opts.output_type == .DYNAMIC_LIBRARY
        array_add(*args, "/DLL");

    for m.system_libraries {
        // I don't know why, but these seem to generate errors. It compiles fine without them.
        // if compare(it, "ucrt.lib") == 0
        //     continue;
        // if compare(it, "vcruntime.lib") == 0
        //     continue;

        array_add(*args, it);
    }
    array_add(*args, .. m.user_libraries);
    // array_add(*args, "user32.lib"); // Sometimes the compiler doesn't pass this one, I don't know why.

    if opts.text_output_flags & .OUTPUT_LINK_LINE
        log("Running linker: %\n", get_quoted_command_string(args));

    print("%\n", join(.. args, " ",, temp));
    result := run_command(..args);
    if result.exit_code != 0 {
        details: string;
        if result.type == {
        case .FAILED_TO_LAUNCH;
            details = "Could not launch linker.";
        case .SIGNALED;
            details = tprint("Linker caught signal %.", result.signal);
        case;
            details = tprint("Linker exit code %.", result.exit_code);
        }
        log_error("Error: Link step failed! %", details);
        compiler_set_workspace_status(.FAILED, ws);
    }
    compiler_custom_link_command_is_complete(ws);

    return output_filename;
}
