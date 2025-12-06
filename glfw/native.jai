#scope_module

#if OS == {
case .WINDOWS;
    // #library,system,link_always "opengl32";
    #library,system,link_always "gdi32";
    #library,system,link_always "user32";
    #library,system,link_always "shell32";

    #import "Windows";
case .MACOS;
    Cocoa :: #library,system,link_always "Cocoa";
    IOKit :: #library,system,link_always "IOKit";
    #import "Objective_C";
    CGDirectDisplayID :: u32; // Cocoa
case .LINUX;
    #library,system,link_always "libm";
    // X11 typedefs
    #import "X11";
    RROutput :: XID;
    RRCrtc   :: XID;
    // Wayland typedefs
    wl_display :: struct {};
    wl_output  :: struct {};
    wl_surface :: struct {};
}

#scope_export

#if OS == {
case .WINDOWS;
    /*! @brief Returns the adapter device name of the specified monitor.
    *
    *  @return The UTF-8 encoded adapter device name (for example `\\.\DISPLAY1`)
    *  of the specified monitor, or `NULL` if an [error](@ref error_handling)
    *  occurred.
    *
    *  @errors Possible errors include @ref GLFW_NOT_INITIALIZED.
    *
    *  @thread_safety This function may be called from any thread.  Access is not
    *  synchronized.
    *
    *  @since Added in version 3.1.
    *
    *  @ingroup native
    */
    glfwGetWin32Adapter :: (monitor: *GLFWmonitor) -> *u8 #foreign glfw;

    /*! @brief Returns the display device name of the specified monitor.
    *
    *  @return The UTF-8 encoded display device name (for example
    *  `\\.\DISPLAY1\Monitor0`) of the specified monitor, or `NULL` if an
    *  [error](@ref error_handling) occurred.
    *
    *  @errors Possible errors include @ref GLFW_NOT_INITIALIZED.
    *
    *  @thread_safety This function may be called from any thread.  Access is not
    *  synchronized.
    *
    *  @since Added in version 3.1.
    *
    *  @ingroup native
    */
    glfwGetWin32Monitor :: (monitor: *GLFWmonitor) -> *u8 #foreign glfw;

    /*! @brief Returns the `HWND` of the specified window.
    *
    *  @return The `HWND` of the specified window, or `NULL` if an
    *  [error](@ref error_handling) occurred.
    *
    *  @errors Possible errors include @ref GLFW_NOT_INITIALIZED.
    *
    *  @remark The `HDC` associated with the window can be queried with the
    *  [GetDC](https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getdc)
    *  function.
    *  @code
    *  HDC dc = GetDC(glfwGetWin32Window(window));
    *  @endcode
    *  This DC is private and does not need to be released.
    *
    *  @thread_safety This function may be called from any thread.  Access is not
    *  synchronized.
    *
    *  @since Added in version 3.0.
    *
    *  @ingroup native
    */
    glfwGetWin32Window :: (window: *GLFWwindow) -> HWND #foreign glfw;

    /*! @brief Returns the `HGLRC` of the specified window.
    *
    *  @return The `HGLRC` of the specified window, or `NULL` if an
    *  [error](@ref error_handling) occurred.
    *
    *  @errors Possible errors include @ref GLFW_NO_WINDOW_CONTEXT and @ref
    *  GLFW_NOT_INITIALIZED.
    *
    *  @remark The `HDC` associated with the window can be queried with the
    *  [GetDC](https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getdc)
    *  function.
    *  @code
    *  HDC dc = GetDC(glfwGetWin32Window(window));
    *  @endcode
    *  This DC is private and does not need to be released.
    *
    *  @thread_safety This function may be called from any thread.  Access is not
    *  synchronized.
    *
    *  @since Added in version 3.0.
    *
    *  @ingroup native
    */
    glfwGetWGLContext :: (window: *GLFWwindow) -> HGLRC #foreign glfw;

case .MACOS;
    /*! @brief Returns the `CGDirectDisplayID` of the specified monitor.
    *
    *  @return The `CGDirectDisplayID` of the specified monitor, or
    *  `kCGNullDirectDisplay` if an [error](@ref error_handling) occurred.
    *
    *  @errors Possible errors include @ref GLFW_NOT_INITIALIZED.
    *
    *  @thread_safety This function may be called from any thread.  Access is not
    *  synchronized.
    *
    *  @since Added in version 3.1.
    *
    *  @ingroup native
    */
    glfwGetCocoaMonitor :: (monitor: *GLFWmonitor) -> CGDirectDisplayID #foreign glfw;

    /*! @brief Returns the `NSWindow` of the specified window.
    *
    *  @return The `NSWindow` of the specified window, or `nil` if an
    *  [error](@ref error_handling) occurred.
    *
    *  @errors Possible errors include @ref GLFW_NOT_INITIALIZED.
    *
    *  @thread_safety This function may be called from any thread.  Access is not
    *  synchronized.
    *
    *  @since Added in version 3.0.
    *
    *  @ingroup native
    */
    glfwGetCocoaWindow :: (window: *GLFWwindow) -> id #foreign glfw;

    /*! @brief Returns the `NSOpenGLContext` of the specified window.
    *
    *  @return The `NSOpenGLContext` of the specified window, or `nil` if an
    *  [error](@ref error_handling) occurred.
    *
    *  @errors Possible errors include @ref GLFW_NO_WINDOW_CONTEXT and @ref
    *  GLFW_NOT_INITIALIZED.
    *
    *  @thread_safety This function may be called from any thread.  Access is not
    *  synchronized.
    *
    *  @since Added in version 3.0.
    *
    *  @ingroup native
    */
    glfwGetNSGLContext :: (window: *GLFWwindow) -> id #foreign glfw;

case .LINUX;
    /*! @brief Returns the `Display` used by GLFW.
    *
    *  @return The `Display` used by GLFW, or `NULL` if an
    *  [error](@ref error_handling) occurred.
    *
    *  @errors Possible errors include @ref GLFW_NOT_INITIALIZED.
    *
    *  @thread_safety This function may be called from any thread.  Access is not
    *  synchronized.
    *
    *  @since Added in version 3.0.
    *
    *  @ingroup native
    */
    glfwGetX11Display :: () -> *Display #foreign glfw;

    /*! @brief Returns the `RRCrtc` of the specified monitor.
    *
    *  @return The `RRCrtc` of the specified monitor, or `None` if an
    *  [error](@ref error_handling) occurred.
    *
    *  @errors Possible errors include @ref GLFW_NOT_INITIALIZED.
    *
    *  @thread_safety This function may be called from any thread.  Access is not
    *  synchronized.
    *
    *  @since Added in version 3.1.
    *
    *  @ingroup native
    */
    glfwGetX11Adapter :: (monitor: *GLFWmonitor) -> RRCrtc #foreign glfw;

    /*! @brief Returns the `RROutput` of the specified monitor.
    *
    *  @return The `RROutput` of the specified monitor, or `None` if an
    *  [error](@ref error_handling) occurred.
    *
    *  @errors Possible errors include @ref GLFW_NOT_INITIALIZED.
    *
    *  @thread_safety This function may be called from any thread.  Access is not
    *  synchronized.
    *
    *  @since Added in version 3.1.
    *
    *  @ingroup native
    */
    glfwGetX11Monitor :: (monitor: *GLFWmonitor) -> RROutput #foreign glfw;

    /*! @brief Returns the `Window` of the specified window.
    *
    *  @return The `Window` of the specified window, or `None` if an
    *  [error](@ref error_handling) occurred.
    *
    *  @errors Possible errors include @ref GLFW_NOT_INITIALIZED.
    *
    *  @thread_safety This function may be called from any thread.  Access is not
    *  synchronized.
    *
    *  @since Added in version 3.0.
    *
    *  @ingroup native
    */
    glfwGetX11Window :: (window: *GLFWwindow) -> Window #foreign glfw;

    /*! @brief Sets the current primary selection to the specified string.
    *
    *  @param[in] string A UTF-8 encoded string.
    *
    *  @errors Possible errors include @ref GLFW_NOT_INITIALIZED and @ref
    *  GLFW_PLATFORM_ERROR.
    *
    *  @pointer_lifetime The specified string is copied before this function
    *  returns.
    *
    *  @thread_safety This function must only be called from the main thread.
    *
    *  @sa @ref clipboard
    *  @sa glfwGetX11SelectionString
    *  @sa glfwSetClipboardString
    *
    *  @since Added in version 3.3.
    *
    *  @ingroup native
    */
    glfwSetX11SelectionString :: (_string: *u8) -> void #foreign glfw;

    /*! @brief Returns the contents of the current primary selection as a string.
    *
    *  If the selection is empty or if its contents cannot be converted, `NULL`
    *  is returned and a @ref GLFW_FORMAT_UNAVAILABLE error is generated.
    *
    *  @return The contents of the selection as a UTF-8 encoded string, or `NULL`
    *  if an [error](@ref error_handling) occurred.
    *
    *  @errors Possible errors include @ref GLFW_NOT_INITIALIZED and @ref
    *  GLFW_PLATFORM_ERROR.
    *
    *  @pointer_lifetime The returned string is allocated and freed by GLFW. You
    *  should not free it yourself. It is valid until the next call to @ref
    *  glfwGetX11SelectionString or @ref glfwSetX11SelectionString, or until the
    *  library is terminated.
    *
    *  @thread_safety This function must only be called from the main thread.
    *
    *  @sa @ref clipboard
    *  @sa glfwSetX11SelectionString
    *  @sa glfwGetClipboardString
    *
    *  @since Added in version 3.3.
    *
    *  @ingroup native
    */
    glfwGetX11SelectionString :: () -> *u8 #foreign glfw;

    /*! @brief Returns the `GLXContext` of the specified window.
    *
    *  @return The `GLXContext` of the specified window, or `NULL` if an
    *  [error](@ref error_handling) occurred.
    *
    *  @errors Possible errors include @ref GLFW_NO_WINDOW_CONTEXT and @ref
    *  GLFW_NOT_INITIALIZED.
    *
    *  @thread_safety This function may be called from any thread.  Access is not
    *  synchronized.
    *
    *  @since Added in version 3.0.
    *
    *  @ingroup native
    */
    glfwGetGLXContext :: (window: *GLFWwindow) -> GLXContext #foreign glfw;

    /*! @brief Returns the `GLXWindow` of the specified window.
    *
    *  @return The `GLXWindow` of the specified window, or `None` if an
    *  [error](@ref error_handling) occurred.
    *
    *  @errors Possible errors include @ref GLFW_NO_WINDOW_CONTEXT and @ref
    *  GLFW_NOT_INITIALIZED.
    *
    *  @thread_safety This function may be called from any thread.  Access is not
    *  synchronized.
    *
    *  @since Added in version 3.2.
    *
    *  @ingroup native
    */
    glfwGetGLXWindow :: (window: *GLFWwindow) -> GLXWindow #foreign glfw;

    /*! @brief Returns the `struct wl_display*` used by GLFW.
    *
    *  @return The `struct wl_display*` used by GLFW, or `NULL` if an
    *  [error](@ref error_handling) occurred.
    *
    *  @errors Possible errors include @ref GLFW_NOT_INITIALIZED.
    *
    *  @thread_safety This function may be called from any thread.  Access is not
    *  synchronized.
    *
    *  @since Added in version 3.2.
    *
    *  @ingroup native
    */
    glfwGetWaylandDisplay :: () -> *wl_display #foreign glfw;

    /*! @brief Returns the `struct wl_output*` of the specified monitor.
    *
    *  @return The `struct wl_output*` of the specified monitor, or `NULL` if an
    *  [error](@ref error_handling) occurred.
    *
    *  @errors Possible errors include @ref GLFW_NOT_INITIALIZED.
    *
    *  @thread_safety This function may be called from any thread.  Access is not
    *  synchronized.
    *
    *  @since Added in version 3.2.
    *
    *  @ingroup native
    */
    glfwGetWaylandMonitor :: (monitor: *GLFWmonitor) -> *wl_output #foreign glfw;

    /*! @brief Returns the main `struct wl_surface*` of the specified window.
    *
    *  @return The main `struct wl_surface*` of the specified window, or `NULL` if
    *  an [error](@ref error_handling) occurred.
    *
    *  @errors Possible errors include @ref GLFW_NOT_INITIALIZED.
    *
    *  @thread_safety This function may be called from any thread.  Access is not
    *  synchronized.
    *
    *  @since Added in version 3.2.
    *
    *  @ingroup native
    */
    glfwGetWaylandWindow :: (window: *GLFWwindow) -> *wl_surface #foreign glfw;
}
