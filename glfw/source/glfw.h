#if defined(_WIN32)
# define _GLFW_WIN32
#endif

#if defined(__linux__)
# if !defined(NO_WAYLAND)
#  define _GLFW_WAYLAND
# endif
# define _GLFW_X11
#endif

#if defined(__APPLE__)
# define _GLFW_COCOA
# define _GLFW_USE_MENUBAR
# define _GLFW_USE_RETINA
#endif

#include "glfw/include/GLFW/glfw3.h"
