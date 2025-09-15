#if defined(_WIN32)
# define _GLFW_WIN32
// # define GLFW_EXPOSE_NATIVE_WIN32
// # define GLFW_EXPOSE_NATIVE_WGL
#endif

#if defined(__linux__)
# if !defined(NO_WAYLAND)
#  define _GLFW_WAYLAND
// #  define GLFW_EXPOSE_NATIVE_WAYLAND
# endif
# define _GLFW_X11
// # define GLFW_EXPOSE_NATIVE_X11
// # define GLFW_EXPOSE_NATIVE_GLX
#endif

#if defined(__APPLE__)
# define _GLFW_COCOA
# define _GLFW_USE_MENUBAR
# define _GLFW_USE_RETINA
// # define GLFW_EXPOSE_NATIVE_COCOA
// # define GLFW_EXPOSE_NATIVE_NSGL
#endif

// #define GLFW_EXPOSE_NATIVE_EGL
// #define GLFW_EXPOSE_NATIVE_OSMESA

#include "glfw/include/GLFW/glfw3.h"
// #include "glfw/include/GLFW/glfw3native.h"
