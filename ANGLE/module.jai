#module_parameters(DUMP_GL_ERRORS := false);

#load "bindings.jai";

// These are the platform speciffic diffs (we exclude these when generating bindings.jai).
#if OS == {
case .IOS;
    EGLNativeDisplayType :: s32;
    EGLNativePixmapType  :: *void;
    EGLNativeWindowType  :: *void;
case .MACOS;
    EGLNativeDisplayType :: s32;
    EGLNativePixmapType  :: *void;
    EGLNativeWindowType  :: *void;
case .WINDOWS;
    EGLNativeDisplayType :: HDC;
    EGLNativePixmapType  :: HBITMAP;
    EGLNativeWindowType  :: HWND;
case .LINUX;
    EGLNativeDisplayType :: *void;
    EGLNativePixmapType  :: u64;
    EGLNativeWindowType  :: u64;
}

#scope_module
#if OS == {
case .IOS;
    #import "Objective_C";
    #if #exists(TARGET_IOS_SIMULATOR) {
        angle :: #library "ios/ANGLE_simulator";
    } else {
        angle :: #library "ios/ANGLE";
    }

    // These are the frameworks required for ANGLE to work
    #library,system,link_always "Foundation";
    #library,system,link_always "CoreGraphics";
    #library,system,link_always "QuartzCore";
    #library,system,link_always "IOSurface";
    #library,system,link_always "Metal";

    // ANGLE needs libc++
    libcxx :: #library,system,link_always "libc++";
case .MACOS;
    #import "Objective_C";
    angle :: #library "macos/ANGLE";

    // These are the frameworks required for ANGLE to work
    #library,system,link_always "Foundation";
    #library,system,link_always "CoreGraphics";
    #library,system,link_always "QuartzCore";
    #library,system,link_always "IOSurface";
    #library,system,link_always "Metal";

    // ANGLE needs libc++
    libcxx :: #library,system,link_always "libc++";

    #program_export
    __isPlatformVersionAtLeast :: (major: s32, minor: s32) -> s32 #c_call {
        return 1; // Jai's lld-macos is too old ? not sure... @Cleanup @Hack
    }
case .WINDOWS;
    angle :: #library "windows/ANGLE";

    #library,system,link_always "dxgi";
    #library,system,link_always "dxguid";
    #library,system,link_always "d3d11";
    #library,system,link_always "libcpmt"; // c++

    #import "Windows";
case .LINUX;
    angle :: #library "linux/ANGLE";

    #library,system,link_always "vulkan";

    #library,system,link_always "xcb";
    // #library,system,link_always "wayland-client";

    // ANGLE needs libc++.
    // Linux is a bit of a special case where libstdc++ and libgcc_s may not be in the library search
    // path. If that's the case, you're going to have to find it and either add it to the LD_LIBRARY_PATH
    // when compiling or to additional_linker_arguments in your metaprogram.
    libcxx   :: #library,system,link_always "libstdc++";
    libgcc_s :: #library,system,link_always "libgcc_s";

}

#import "Basic";


#scope_export

EGL_DONT_CARE        :: -1;
EGL_UNKNOWN          :: -1;
EGL_DEFAULT_DISPLAY: EGLNativeDisplayType : xx 0;
EGL_NO_CONTEXT:      EGLContext           : null;
EGL_NO_DISPLAY:      EGLDisplay           : null;
EGL_NO_SURFACE:      EGLSurface           : null;
EGL_NO_SYNC:         EGLSync              : null;
EGL_NO_IMAGE:        EGLImage             : null;

EGL_Info :: struct {
    display:  EGLDisplay = EGL_NO_DISPLAY;
    context_: EGLContext = EGL_NO_CONTEXT;

    surface:  EGLSurface = EGL_NO_SURFACE;
    config:   EGLConfig;
}

egl_create_context :: inline (window: EGLNativeWindowType, wanted_msaa: s32 = 0) -> context_: EGLContext, display: EGLDisplay, surface: EGLSurface, choosen_msaa: s32 {
    info, msaa := egl_create_context_new(window, wanted_msaa);
    return info.context_, info.display, info.surface, msaa;
}

// _new as in "new api".
egl_create_context_new :: (window: EGLNativeWindowType, wanted_msaa: s32 = 0, display := EGL_NO_DISPLAY) -> info: EGL_Info, choosen_msaa: s32 {
    egl_display := display;
    // if egl_display == EGL_NO_DISPLAY {
        egl_display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
        assert(egl_display != EGL_NO_DISPLAY);
    // }

    egl_major, egl_minor: EGLint;
    egl_result := eglInitialize(egl_display, *egl_major, *egl_minor);
    if egl_result != EGL_TRUE {
        log_error("Failed to initialize EGL (%).", egl_print_error());
        exit(1);
    }
    log("Egl initialized with version: %.%", egl_major, egl_minor);

    config: EGLConfig;
    attempted_msaa := wanted_msaa;
    while 1 {
        attribs := EGLint.[
            EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
            // EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
            EGL_RED_SIZE,       8,
            EGL_GREEN_SIZE,     8,
            EGL_BLUE_SIZE,      8,
            EGL_ALPHA_SIZE,     8,
            EGL_DEPTH_SIZE,     16,
            EGL_STENCIL_SIZE,   EGL_DONT_CARE,
            EGL_SAMPLE_BUFFERS, cast(s32) ifx attempted_msaa then 1 else 0,
            EGL_SAMPLES,        attempted_msaa,
            EGL_NONE
        ];
        num_configs: EGLint;
        eglChooseConfig(egl_display, attribs.data, null, 0, *num_configs);

        if num_configs > 0 {
            supported_configs := NewArray(num_configs, EGLConfig, false);
            defer array_free(supported_configs);
            eglChooseConfig(egl_display, attribs.data, supported_configs.data, num_configs, *num_configs);

            // MGLKit from MetalANGLE just choose the first config without caring about msaa or anything else...
            config = supported_configs[0];
        } else if attempted_msaa > 0 {
            // Try a lower MSAA setting
            attempted_msaa >> 1;
            continue;
        }
        break;
    }
    if config == null {
        log_error("Failed to select EGL config (%).", egl_print_error());
        exit(1);
    }

    choosen_msaa: s32;
    eglGetConfigAttrib(egl_display, config, EGL_SAMPLES, *choosen_msaa);

    attribs := EGLint.[
        EGL_CONTEXT_MAJOR_VERSION, 3,
        EGL_CONTEXT_MINOR_VERSION, 0,
        EGL_NONE
    ];
    egl_context := eglCreateContext(egl_display, config, null, attribs.data);
    if egl_context == EGL_NO_CONTEXT {
        log_error("Failed to create EGL context (%).", egl_print_error());
        exit(1);
    }

    info := EGL_Info.{
        display  = egl_display,
        context_ = egl_context,
        config   = config,
    };

    egl_create_surface(*info, window);

    return info, choosen_msaa;
}

egl_create_surface :: (info: *EGL_Info, window: EGLNativeWindowType) -> bool {
    assert(info.surface == EGL_NO_SURFACE);
    assert(info.display != EGL_NO_DISPLAY);
    assert(info.context_ != EGL_NO_CONTEXT);

    creation_attribs := EGLint.[
        EGL_GL_COLORSPACE_KHR, EGL_GL_COLORSPACE_LINEAR_KHR,
        EGL_NONE
    ];
    info.surface = eglCreateWindowSurface(info.display, info.config, window, creation_attribs.data);
    if info.surface == EGL_NO_SURFACE {
        log_error("Failed to create EGL window surface (%).", egl_print_error());
        exit(1);
    }

    make_current_result := eglMakeCurrent(info.display, info.surface, info.surface, info.context_);
    if make_current_result == EGL_FALSE {
        log_error("Failed to make EGL context current (%).", egl_print_error());
        exit(1);
    }

    return true;
}

egl_destroy_surface :: (info: *EGL_Info) -> bool {
    assert(info.display != EGL_NO_DISPLAY);
    assert(info.surface != EGL_NO_SURFACE);

    result := eglDestroySurface(info.display, info.surface);
    if !result {
        log_error("Failed to destroy egl surface");
    }

    info.surface = EGL_NO_SURFACE;
    return result == EGL_TRUE;
}

// Try convert an error returned by eglGetError to readable string. 
egl_error_to_string :: (error: EGLint) -> error: string, description: string {
    if error == {
        case EGL_SUCCESS;              return "EGL_SUCCESS"            , "The last function succeeded without error.";
        case EGL_NOT_INITIALIZED;      return "EGL_NOT_INITIALIZED"    , "EGL is not initialized, or could not be initialized, for the specified EGL display connection.";
        case EGL_BAD_ACCESS;           return "EGL_BAD_ACCESS"         , "EGL cannot access a requested resource (for example a context is bound in another thread).";
        case EGL_BAD_ALLOC;            return "EGL_BAD_ALLOC"          , "EGL failed to allocate resources for the requested operation.";
        case EGL_BAD_ATTRIBUTE;        return "EGL_BAD_ATTRIBUTE"      , "An unrecognized attribute or attribute value was passed in the attribute list.";
        case EGL_BAD_CONTEXT;          return "EGL_BAD_CONTEXT"        , "An EGLContext argument does not name a valid EGL rendering context.";
        case EGL_BAD_CONFIG;           return "EGL_BAD_CONFIG"         , "An EGLConfig argument does not name a valid EGL frame buffer configuration.";
        case EGL_BAD_CURRENT_SURFACE;  return "EGL_BAD_CURRENT_SURFACE", "The current surface of the calling thread is a window, pixel buffer or pixmap that is no longer valid.";
        case EGL_BAD_DISPLAY;          return "EGL_BAD_DISPLAY"        , "An EGLDisplay argument does not name a valid EGL display connection.";
        case EGL_BAD_SURFACE;          return "EGL_BAD_SURFACE"        , "An EGLSurface argument does not name a valid surface (window, pixel buffer or pixmap) configured for GL rendering.";
        case EGL_BAD_MATCH;            return "EGL_BAD_MATCH"          , "Arguments are inconsistent (for example, a valid context requires buffers not supplied by a valid surface).";
        case EGL_BAD_PARAMETER;        return "EGL_BAD_PARAMETER"      , "One or more argument values are invalid.";
        case EGL_BAD_NATIVE_PIXMAP;    return "EGL_BAD_NATIVE_PIXMAP"  , "A NativePixmapType argument does not refer to a valid native pixmap.";
        case EGL_BAD_NATIVE_WINDOW;    return "EGL_BAD_NATIVE_WINDOW"  , "A NativeWindowType argument does not refer to a valid native window.";
        case EGL_CONTEXT_LOST;         return "EGL_CONTEXT_LOST"       , "A power management event has occurred. The application must destroy all contexts and reinitialise OpenGL ES state and objects to continue rendering.";
    }

    // return tprint("Unknown error %", error); // Is it good form to tprint from a look up like this?
    return "Unknown error", "";
}

egl_get_error_string :: () -> string, string #expand {
    error, description := egl_error_to_string(eglGetError());
    return error, description;
}

egl_print_error :: () -> string {
    error, description := egl_error_to_string(eglGetError());
    return tprint("% - %", error, description);
}

// @CopyPasta from modules/GL
DumpShaderInfoLog :: (shader: GLuint, name: string) {
    BUFFER_SIZE :: 4096;
    buffer: [BUFFER_SIZE] u8 = ---;
    buffer.data[0] = 0;

    length_result: GLsizei = 0;
    glGetShaderInfoLog(shader, BUFFER_SIZE, *length_result, buffer.data);

    if length_result > 0 {
        s: string;
        s.count = length_result;
        s.data = buffer.data;
        log("ShaderInfoLog for '%': %\n", name, s);
    }
}

DumpProgramInfoLog :: (program: GLuint, name: string) {
    BUFFER_SIZE :: 4096;
    buffer: [BUFFER_SIZE] u8 = ---;
    buffer.data[0] = 0;

    length_result: GLsizei = 0;
    glGetProgramInfoLog(program, BUFFER_SIZE, *length_result, buffer.data);

    if length_result > 0 {
        s: string;
        s.count = length_result;
        s.data = buffer.data;
        log("ProgramInfoLog for '%': %\n", name, s);
    }
}

#if DUMP_GL_ERRORS {
    DumpGLErrors :: (tag: string, loc := #caller_location) -> bool {
        had_error := false;

        if glGetDebugMessageLogARB {
            while true {
                Source, Type, ID: GLuint;
                Length: GLint;

                BUFFER_SIZE :: 4096;
                Buffer: [BUFFER_SIZE] u8;
                Severity: GLenum;

                if glGetDebugMessageLogARB(1, size_of(type_of(Buffer)), xx *Source, xx *Type, *ID, *Severity, xx *Length, Buffer.data) {
                    GL_DEBUG_TYPE_ERROR_ARB :: 0x824C;
                    HIGH   :: 0x9146;
                    MEDIUM :: 0x9147;
                    //                if Type == GL_DEBUG_TYPE_ERROR_ARB {
                    if (Severity == MEDIUM) || (Severity == HIGH) {
                        s: string;
                        s.count = Length-1;  // The Length includes a terminating 0, apparently.
                        s.data = Buffer.data;

                        log("[%] %:%: %\n", tag, loc.fully_pathed_filename, loc.line_number, s);

                        // @@ Is there a way to print this only if the above function is not filtered? Tag print line to also include trace?
                        //trace : []string = Debug.backtrace();
                        //defer Debug.free_backtrace(trace);
                        //for trace { print("    %", it); if it_index > 4 break; }

                        had_error = true;
                    }
                } else {
                    break;
                }
            }
        } else {
            while true {
                error := glGetError();
                if error == GL_NO_ERROR break;

                had_error = true;
                log("[%] %:%: GL error 0x%\n", tag, loc.fully_pathed_filename, loc.line_number, formatInt(error, base = 16, minimum_digits = 4));
            }
        }

        return had_error;
    }
} else {
    DumpGLErrors :: inline (#discard tag: string, #discard loc := #caller_location) -> bool {
        return false;  // @Hack
    }
}
