#if OS == {
case .WINDOWS; #load "generated_windows.jai";
case .LINUX;   #load "generated_linux.jai";
case .MACOS;   #load "generated_macos.jai"; // @Cleanup: macos and ios are identical
case .IOS;     #load "generated_ios.jai";
case .ANDROID; #load "generated_android.jai";
case;          #assert false;
}


#scope_file;
#if OS == .WINDOWS   #import "Windows";
else #if OS_IS_UNIX  #import "POSIX";

#if OS == .MACOS || OS == .IOS {
    // @Cleanup @Macos: Are there required at compile time ? miniaudio should do runtime linking.
    CoreFoundation :: #library,system,link_always "CoreFoundation";
    CoreAudio      :: #library,system,link_always "CoreAudio";
    AudioToolbox   :: #library,system,link_always "AudioToolbox";
    AVFoundation   :: #library,system,link_always "AVFoundation";
}
