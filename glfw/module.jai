



#if OS == .WINDOWS {
    #library,system,link_always "opengl32";
    #library,system,link_always "gdi32";
    #library,system,link_always "user32";
    #library,system,link_always "shell32";
} else #if OS == .MACOS {
    Cocoa :: #library,system,link_always "Cocoa";
    IOKit :: #library,system,link_always "IOKit";
} else #if OS == .LINUX {
    #library,system,link_always "m"; // c math
}

#load "bindings.jai";
