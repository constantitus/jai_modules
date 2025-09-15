#ifdef WIN32
#define __EXPORT __declspec(dllexport)
#else
#define __EXPORT
#endif

// fuck
// #define STBRP_DEF extern __EXPORT

#define STB_RECT_PACK_IMPLEMENTATION
#include "stb_rect_pack.h"
