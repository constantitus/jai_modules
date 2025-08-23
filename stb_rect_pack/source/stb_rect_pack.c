#ifdef WIN32
#define __EXPORT __declspec(dllexport)
#else
#define __EXPORT
#endif

#define STBRPDEF extern __EXPORT

#define STB_RECT_PACK_IMPLEMENTATION
#include "stb_rect_pack.h"
