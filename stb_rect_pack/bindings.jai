//
// This file was auto-generated using the following command:
//
// jai generate.jai - -compile -ios
//



STB_RECT_PACK_VERSION :: 1;

STBRP__MAXVAL :: 0x7fffffff;

stbrp_coord :: s32;

// Mostly for internal use, but this is the maximum supported coordinate value.
stbrp_pack_rects :: (_context: *stbrp_context, rects: *stbrp_rect, num_rects: s32) -> s32 #foreign stb_rect_pack;

// Assign packed locations to rectangles. The rectangles are of type
// 'stbrp_rect' defined below, stored in the array 'rects', and there
// are 'num_rects' many of them.
//
// Rectangles which are successfully packed have the 'was_packed' flag
// set to a non-zero value and 'x' and 'y' store the minimum location
// on each axis (i.e. bottom-left in cartesian coordinates, top-left
// if you imagine y increasing downwards). Rectangles which do not fit
// have the 'was_packed' flag set to 0.
//
// You should not try to access the 'rects' array from another thread
// while this function is running, as the function temporarily reorders
// the array while it executes.
//
// To pack into another rectangle, you need to call stbrp_init_target
// again. To continue packing into the same rectangle, you can call
// this function again. Calling this multiple times with multiple rect
// arrays will probably produce worse packing results than calling it
// a single time with the full rectangle array, but the option is
// available.
//
// The function returns 1 if all of the rectangles were successfully
// packed and 0 otherwise.
stbrp_rect :: struct {
    // reserved for your use:
    id:         s32;

    // input:
    w:          stbrp_coord;
    // input:
    h:          stbrp_coord;

    // output:
    x:          stbrp_coord;
    // output:
    y:          stbrp_coord;
    was_packed: s32; // non-zero if valid packing
}

stbrp_init_target :: (_context: *stbrp_context, width: s32, height: s32, nodes: *stbrp_node, num_nodes: s32) -> void #foreign stb_rect_pack;

// Initialize a rectangle packer to:
//    pack a rectangle that is 'width' by 'height' in dimensions
//    using temporary storage provided by the array 'nodes', which is 'num_nodes' long
//
// You must call this function every time you start packing into a new target.
//
// There is no "shutdown" function. The 'nodes' memory must stay valid for
// the following stbrp_pack_rects() call (or calls), but can be freed after
// the call (or calls) finish.
//
// Note: to guarantee best results, either:
//       1. make sure 'num_nodes' >= 'width'
//   or  2. call stbrp_allow_out_of_mem() defined below with 'allow_out_of_mem = 1'
//
// If you don't do either of the above things, widths will be quantized to multiples
// of small integers to guarantee the algorithm doesn't run out of temporary storage.
//
// If you do #2, then the non-quantized algorithm will be used, but the algorithm
// may run out of temporary storage and be unable to pack some rectangles.
stbrp_setup_allow_out_of_mem :: (_context: *stbrp_context, allow_out_of_mem: s32) -> void #foreign stb_rect_pack;

// Optionally call this function after init but before doing any packing to
// change the handling of the out-of-temp-memory scenario, described above.
// If you call init again, this will be reset to the default (false).
stbrp_setup_heuristic :: (_context: *stbrp_context, heuristic: s32) -> void #foreign stb_rect_pack;

// Optionally select which packing heuristic the library should use. Different
// heuristics will produce better/worse results for different data sets.
// If you call init again, this will be reset to the default.
STBRP_HEURISTIC_Skyline :: enum u32 {
    default       :: 0;
    BL_sortHeight :: 0;
    BF_sortHeight :: 1;

    STBRP_HEURISTIC_Skyline_default       :: default;
    STBRP_HEURISTIC_Skyline_BL_sortHeight :: BL_sortHeight;
    STBRP_HEURISTIC_Skyline_BF_sortHeight :: BF_sortHeight;
}

//////////////////////////////////////////////////////////////////////////////
//
// the details of the following structures don't matter to you, but they must
// be visible so you can handle the memory allocations for them
stbrp_node :: struct {
    x:    stbrp_coord;
    y:    stbrp_coord;
    next: *stbrp_node;
}

stbrp_context :: struct {
    width:       s32;
    height:      s32;
    align:       s32;
    init_mode:   s32;
    heuristic:   s32;
    num_nodes:   s32;
    active_head: *stbrp_node;
    free_head:   *stbrp_node;
    extra:       [2] stbrp_node; // we allocate two extra nodes so optimal user-node-count is 'width' not 'width+2'
}

#scope_file


#if OS == .WINDOWS {
    stb_rect_pack :: #library "windows/stb_rect_pack";
} else #if OS == .LINUX {
    stb_rect_pack :: #library "linux/stb_rect_pack";
} else #if OS == .MACOS {
    stb_rect_pack :: #library "macos/stb_rect_pack";
} else #if OS == .ANDROID {
    #if CPU == .X64 {
        stb_rect_pack :: #library "android/x64/stb_rect_pack";
    } else #if CPU == .ARM64 {
        stb_rect_pack :: #library "android/arm64/stb_rect_pack";
    }
} else #if OS == .IOS {
    #if #exists(TARGET_IOS_SIMULATOR) {
        stb_rect_pack :: #library,no_dll "ios/stb_rect_pack_simulator";
    } else {
        stb_rect_pack :: #library,no_dll "ios/stb_rect_pack";
    }
} else #if OS == .PS5 {
    stb_rect_pack :: #library "ps5/stb_rect_pack";
} else {
    #assert false;
}

