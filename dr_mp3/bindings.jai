//
// This file was auto-generated using the following command:
//
// jai generate.jai - -compile -ios
//



DRMP3_VERSION_MAJOR :: 0;
DRMP3_VERSION_MINOR :: 7;
DRMP3_VERSION_REVISION :: 1;

DRMP3_TRUE :: 1;
DRMP3_FALSE :: 0;

DRMP3_UINT64_MAX :: (cast(drmp3_uint64) 0xFFFFFFFF << 32) | cast(drmp3_uint64) 0xFFFFFFFF;

DRMP3_SUCCESS :: 0;
DRMP3_ERROR :: -1;
DRMP3_INVALID_ARGS :: -2;
DRMP3_INVALID_OPERATION :: -3;
DRMP3_OUT_OF_MEMORY :: -4;
DRMP3_OUT_OF_RANGE :: -5;
DRMP3_ACCESS_DENIED :: -6;
DRMP3_DOES_NOT_EXIST :: -7;
DRMP3_ALREADY_EXISTS :: -8;
DRMP3_TOO_MANY_OPEN_FILES :: -9;
DRMP3_INVALID_FILE :: -10;
DRMP3_TOO_BIG :: -11;
DRMP3_PATH_TOO_LONG :: -12;
DRMP3_NAME_TOO_LONG :: -13;
DRMP3_NOT_DIRECTORY :: -14;
DRMP3_IS_DIRECTORY :: -15;
DRMP3_DIRECTORY_NOT_EMPTY :: -16;
DRMP3_END_OF_FILE :: -17;
DRMP3_NO_SPACE :: -18;
DRMP3_BUSY :: -19;
DRMP3_IO_ERROR :: -20;
DRMP3_INTERRUPT :: -21;
DRMP3_UNAVAILABLE :: -22;
DRMP3_ALREADY_IN_USE :: -23;
DRMP3_BAD_ADDRESS :: -24;
DRMP3_BAD_SEEK :: -25;
DRMP3_BAD_PIPE :: -26;
DRMP3_DEADLOCK :: -27;
DRMP3_TOO_MANY_LINKS :: -28;
DRMP3_NOT_IMPLEMENTED :: -29;
DRMP3_NO_MESSAGE :: -30;
DRMP3_BAD_MESSAGE :: -31;
DRMP3_NO_DATA_AVAILABLE :: -32;
DRMP3_INVALID_DATA :: -33;
DRMP3_TIMEOUT :: -34;
DRMP3_NO_NETWORK :: -35;
DRMP3_NOT_UNIQUE :: -36;
DRMP3_NOT_SOCKET :: -37;
DRMP3_NO_ADDRESS :: -38;
DRMP3_BAD_PROTOCOL :: -39;
DRMP3_PROTOCOL_UNAVAILABLE :: -40;
DRMP3_PROTOCOL_NOT_SUPPORTED :: -41;
DRMP3_PROTOCOL_FAMILY_NOT_SUPPORTED :: -42;
DRMP3_ADDRESS_FAMILY_NOT_SUPPORTED :: -43;
DRMP3_SOCKET_NOT_SUPPORTED :: -44;
DRMP3_CONNECTION_RESET :: -45;
DRMP3_ALREADY_CONNECTED :: -46;
DRMP3_NOT_CONNECTED :: -47;
DRMP3_CONNECTION_REFUSED :: -48;
DRMP3_NO_HOST :: -49;
DRMP3_IN_PROGRESS :: -50;
DRMP3_CANCELLED :: -51;
DRMP3_MEMORY_ALREADY_MAPPED :: -52;
DRMP3_AT_END :: -53;

DRMP3_MAX_PCM_FRAMES_PER_MP3_FRAME :: 1152;
DRMP3_MAX_SAMPLES_PER_FRAME :: DRMP3_MAX_PCM_FRAMES_PER_MP3_FRAME*2;

/* Sized Types */
drmp3_int8 :: s8;
drmp3_uint8 :: u8;
drmp3_int16 :: s16;
drmp3_uint16 :: u16;
drmp3_int32 :: s32;
drmp3_uint32 :: u32;

drmp3_int64 :: s64;
drmp3_uint64 :: u64;

drmp3_uintptr :: drmp3_uint64;

drmp3_bool8 :: drmp3_uint8;
drmp3_bool32 :: drmp3_uint32;

/* Result Codes */
drmp3_result :: drmp3_int32;

/* End Inline */
drmp3_version :: (pMajor: *drmp3_uint32, pMinor: *drmp3_uint32, pRevision: *drmp3_uint32) -> void #foreign dr_mp3;
drmp3_version_string :: () -> *u8 #foreign dr_mp3;

/* Allocation Callbacks */
drmp3_allocation_callbacks :: struct {
    pUserData: *void;
    onMalloc:  #type (sz: u64, pUserData: *void) -> *void #c_call;
    onRealloc: #type (p: *void, sz: u64, pUserData: *void) -> *void #c_call;
    onFree:    #type (p: *void, pUserData: *void) -> void #c_call;
}

/*
Low Level Push API
==================
*/
drmp3dec_frame_info :: struct {
    frame_bytes:  s32;
    channels:     s32;
    sample_rate:  s32;
    layer:        s32;
    bitrate_kbps: s32;
}

drmp3dec :: struct {
    mdct_overlap:      [2] [288] float;
    qmf_state:         [960] float;
    reserv:            s32;
    free_format_bytes: s32;
    header:            [4] drmp3_uint8;
    reserv_buf:        [511] drmp3_uint8;
}

/* Initializes a low level decoder. */
drmp3dec_init :: (dec: *drmp3dec) -> void #foreign dr_mp3;

/* Reads a frame from a low level decoder. */
drmp3dec_decode_frame :: (dec: *drmp3dec, mp3: *drmp3_uint8, mp3_bytes: s32, pcm: *void, info: *drmp3dec_frame_info) -> s32 #foreign dr_mp3;

/* Helper for converting between f32 and s16. */
drmp3dec_f32_to_s16 :: (in: *float, out: *drmp3_int16, num_samples: u64) -> void #foreign dr_mp3;

/*
Main API (Pull API)
===================
*/
drmp3_seek_origin :: enum u32 {
    SET :: 0;
    CUR :: 1;
    END :: 2;

    DRMP3_SEEK_SET :: SET;
    DRMP3_SEEK_CUR :: CUR;
    DRMP3_SEEK_END :: END;
}

drmp3_seek_point :: struct {
    seekPosInBytes:     drmp3_uint64; /* Points to the first byte of an MP3 frame. */
    pcmFrameIndex:      drmp3_uint64; /* The index of the PCM frame this seek point targets. */
    mp3FramesToDiscard: drmp3_uint16; /* The number of whole MP3 frames to be discarded before pcmFramesToDiscard. */
    pcmFramesToDiscard: drmp3_uint16; /* The number of leading samples to read and discard. These are discarded after mp3FramesToDiscard. */
}

drmp3_metadata_type :: enum u32 {
    ID3V1 :: 0;
    ID3V2 :: 1;
    APE   :: 2;
    XING  :: 3;
    VBRI  :: 4;

    DRMP3_METADATA_TYPE_ID3V1 :: ID3V1;
    DRMP3_METADATA_TYPE_ID3V2 :: ID3V2;
    DRMP3_METADATA_TYPE_APE   :: APE;
    DRMP3_METADATA_TYPE_XING  :: XING;
    DRMP3_METADATA_TYPE_VBRI  :: VBRI;
}

drmp3_metadata :: struct {
    type:        drmp3_metadata_type;
    pRawData:    *void; /* A pointer to the raw data. */
    rawDataSize: u64;
}

/*
Callback for when data is read. Return value is the number of bytes actually read.

pUserData   [in]  The user data that was passed to drmp3_init(), and family.
pBufferOut  [out] The output buffer.
bytesToRead [in]  The number of bytes to read.

Returns the number of bytes actually read.

A return value of less than bytesToRead indicates the end of the stream. Do _not_ return from this callback until
either the entire bytesToRead is filled or you have reached the end of the stream.
*/
drmp3_read_proc :: #type (pUserData: *void, pBufferOut: *void, bytesToRead: u64) -> u64 #c_call;

/*
Callback for when data needs to be seeked.

pUserData [in] The user data that was passed to drmp3_init(), and family.
offset    [in] The number of bytes to move, relative to the origin. Can be negative.
origin    [in] The origin of the seek.

Returns whether or not the seek was successful.
*/
drmp3_seek_proc :: #type (pUserData: *void, offset: s32, origin: drmp3_seek_origin) -> drmp3_bool32 #c_call;

/*
Callback for retrieving the current cursor position.

pUserData [in]  The user data that was passed to drmp3_init(), and family.
pCursor   [out] The cursor position in bytes from the start of the stream.

Returns whether or not the cursor position was successfully retrieved.
*/
drmp3_tell_proc :: #type (pUserData: *void, pCursor: *drmp3_int64) -> drmp3_bool32 #c_call;

/*
Callback for when metadata is read.

Only the raw data is provided. The client is responsible for parsing the contents of the data themsevles.
*/
drmp3_meta_proc :: #type (pUserData: *void, pMetadata: *drmp3_metadata) -> void #c_call;

drmp3_config :: struct {
    channels:   drmp3_uint32;
    sampleRate: drmp3_uint32;
}

drmp3 :: struct {
    decoder:                      drmp3dec;
    channels:                     drmp3_uint32;
    sampleRate:                   drmp3_uint32;
    onRead:                       drmp3_read_proc;
    onSeek:                       drmp3_seek_proc;
    onMeta:                       drmp3_meta_proc;
    pUserData:                    *void;
    pUserDataMeta:                *void;
    allocationCallbacks:          drmp3_allocation_callbacks;
    mp3FrameChannels:             drmp3_uint32; /* The number of channels in the currently loaded MP3 frame. Internal use only. */
    mp3FrameSampleRate:           drmp3_uint32; /* The sample rate of the currently loaded MP3 frame. Internal use only. */
    pcmFramesConsumedInMP3Frame:  drmp3_uint32;
    pcmFramesRemainingInMP3Frame: drmp3_uint32;
    pcmFrames:                    [9216] drmp3_uint8; /* <-- Multipled by sizeof(float) to ensure there's enough room for DR_MP3_FLOAT_OUTPUT. */
    currentPCMFrame:              drmp3_uint64; /* The current PCM frame, globally. */
    streamCursor:                 drmp3_uint64; /* The current byte the decoder is sitting on in the raw stream. */
    streamLength:                 drmp3_uint64; /* The length of the stream in bytes. dr_mp3 will not read beyond this. If a ID3v1 or APE tag is present, this will be set to the first byte of the tag. */
    streamStartOffset:            drmp3_uint64; /* The offset of the start of the MP3 data. This is used for skipping ID3v2 and VBR tags. */
    pSeekPoints:                  *drmp3_seek_point; /* NULL by default. Set with drmp3_bind_seek_table(). Memory is owned by the client. dr_mp3 will never attempt to free this pointer. */
    seekPointCount:               drmp3_uint32; /* The number of items in pSeekPoints. When set to 0 assumes to no seek table. Defaults to zero. */
    delayInPCMFrames:             drmp3_uint32;
    paddingInPCMFrames:           drmp3_uint32;
    totalPCMFrameCount:           drmp3_uint64; /* Set to DRMP3_UINT64_MAX if the length is unknown. Includes delay and padding. */
    isVBR:                        drmp3_bool32;
    isCBR:                        drmp3_bool32;
    dataSize:                     u64;
    dataCapacity:                 u64;
    dataConsumed:                 u64;
    pData:                        *drmp3_uint8;
    atEnd:                        drmp3_bool32;
    memory:                       struct {
        pData:          *drmp3_uint8;
        dataSize:       u64;
        currentReadPos: u64;
    }; /* Only used for decoders that were opened against a block of memory. */
}

/*
Initializes an MP3 decoder.

onRead    [in]           The function to call when data needs to be read from the client.
onSeek    [in]           The function to call when the read position of the client data needs to move.
onTell    [in]           The function to call when the read position of the client data needs to be retrieved.
pUserData [in, optional] A pointer to application defined data that will be passed to onRead and onSeek.

Returns true if successful; false otherwise.

Close the loader with drmp3_uninit().

See also: drmp3_init_file(), drmp3_init_memory(), drmp3_uninit()
*/
drmp3_init :: (pMP3: *drmp3, onRead: drmp3_read_proc, onSeek: drmp3_seek_proc, onTell: drmp3_tell_proc, onMeta: drmp3_meta_proc, pUserData: *void, pAllocationCallbacks: *drmp3_allocation_callbacks) -> drmp3_bool32 #foreign dr_mp3;

/*
Initializes an MP3 decoder from a block of memory.

This does not create a copy of the data. It is up to the application to ensure the buffer remains valid for
the lifetime of the drmp3 object.

The buffer should contain the contents of the entire MP3 file.
*/
drmp3_init_memory_with_metadata :: (pMP3: *drmp3, pData: *void, dataSize: u64, onMeta: drmp3_meta_proc, pUserDataMeta: *void, pAllocationCallbacks: *drmp3_allocation_callbacks) -> drmp3_bool32 #foreign dr_mp3;
drmp3_init_memory :: (pMP3: *drmp3, pData: *void, dataSize: u64, pAllocationCallbacks: *drmp3_allocation_callbacks) -> drmp3_bool32 #foreign dr_mp3;

/*
Initializes an MP3 decoder from a file.

This holds the internal FILE object until drmp3_uninit() is called. Keep this in mind if you're caching drmp3
objects because the operating system may restrict the number of file handles an application can have open at
any given time.
*/
drmp3_init_file_with_metadata :: (pMP3: *drmp3, pFilePath: *u8, onMeta: drmp3_meta_proc, pUserDataMeta: *void, pAllocationCallbacks: *drmp3_allocation_callbacks) -> drmp3_bool32 #foreign dr_mp3;
drmp3_init_file_with_metadata_w :: (pMP3: *drmp3, pFilePath: *s32, onMeta: drmp3_meta_proc, pUserDataMeta: *void, pAllocationCallbacks: *drmp3_allocation_callbacks) -> drmp3_bool32 #foreign dr_mp3;

drmp3_init_file :: (pMP3: *drmp3, pFilePath: *u8, pAllocationCallbacks: *drmp3_allocation_callbacks) -> drmp3_bool32 #foreign dr_mp3;
drmp3_init_file_w :: (pMP3: *drmp3, pFilePath: *s32, pAllocationCallbacks: *drmp3_allocation_callbacks) -> drmp3_bool32 #foreign dr_mp3;

/*
Uninitializes an MP3 decoder.
*/
drmp3_uninit :: (pMP3: *drmp3) -> void #foreign dr_mp3;

/*
Reads PCM frames as interleaved 32-bit IEEE floating point PCM.

Note that framesToRead specifies the number of PCM frames to read, _not_ the number of MP3 frames.
*/
drmp3_read_pcm_frames_f32 :: (pMP3: *drmp3, framesToRead: drmp3_uint64, pBufferOut: *float) -> drmp3_uint64 #foreign dr_mp3;

/*
Reads PCM frames as interleaved signed 16-bit integer PCM.

Note that framesToRead specifies the number of PCM frames to read, _not_ the number of MP3 frames.
*/
drmp3_read_pcm_frames_s16 :: (pMP3: *drmp3, framesToRead: drmp3_uint64, pBufferOut: *drmp3_int16) -> drmp3_uint64 #foreign dr_mp3;

/*
Seeks to a specific frame.

Note that this is _not_ an MP3 frame, but rather a PCM frame.
*/
drmp3_seek_to_pcm_frame :: (pMP3: *drmp3, frameIndex: drmp3_uint64) -> drmp3_bool32 #foreign dr_mp3;

/*
Calculates the total number of PCM frames in the MP3 stream. Cannot be used for infinite streams such as internet
radio. Runs in linear time. Returns 0 on error.
*/
drmp3_get_pcm_frame_count :: (pMP3: *drmp3) -> drmp3_uint64 #foreign dr_mp3;

/*
Calculates the total number of MP3 frames in the MP3 stream. Cannot be used for infinite streams such as internet
radio. Runs in linear time. Returns 0 on error.
*/
drmp3_get_mp3_frame_count :: (pMP3: *drmp3) -> drmp3_uint64 #foreign dr_mp3;

/*
Calculates the total number of MP3 and PCM frames in the MP3 stream. Cannot be used for infinite streams such as internet
radio. Runs in linear time. Returns 0 on error.

This is equivalent to calling drmp3_get_mp3_frame_count() and drmp3_get_pcm_frame_count() except that it's more efficient.
*/
drmp3_get_mp3_and_pcm_frame_count :: (pMP3: *drmp3, pMP3FrameCount: *drmp3_uint64, pPCMFrameCount: *drmp3_uint64) -> drmp3_bool32 #foreign dr_mp3;

/*
Calculates the seekpoints based on PCM frames. This is slow.

pSeekpoint count is a pointer to a uint32 containing the seekpoint count. On input it contains the desired count.
On output it contains the actual count. The reason for this design is that the client may request too many
seekpoints, in which case dr_mp3 will return a corrected count.

Note that seektable seeking is not quite sample exact when the MP3 stream contains inconsistent sample rates.
*/
drmp3_calculate_seek_points :: (pMP3: *drmp3, pSeekPointCount: *drmp3_uint32, pSeekPoints: *drmp3_seek_point) -> drmp3_bool32 #foreign dr_mp3;

/*
Binds a seek table to the decoder.

This does _not_ make a copy of pSeekPoints - it only references it. It is up to the application to ensure this
remains valid while it is bound to the decoder.

Use drmp3_calculate_seek_points() to calculate the seek points.
*/
drmp3_bind_seek_table :: (pMP3: *drmp3, seekPointCount: drmp3_uint32, pSeekPoints: *drmp3_seek_point) -> drmp3_bool32 #foreign dr_mp3;

/*
Opens an decodes an entire MP3 stream as a single operation.

On output pConfig will receive the channel count and sample rate of the stream.

Free the returned pointer with drmp3_free().
*/
drmp3_open_and_read_pcm_frames_f32 :: (onRead: drmp3_read_proc, onSeek: drmp3_seek_proc, onTell: drmp3_tell_proc, pUserData: *void, pConfig: *drmp3_config, pTotalFrameCount: *drmp3_uint64, pAllocationCallbacks: *drmp3_allocation_callbacks) -> *float #foreign dr_mp3;
drmp3_open_and_read_pcm_frames_s16 :: (onRead: drmp3_read_proc, onSeek: drmp3_seek_proc, onTell: drmp3_tell_proc, pUserData: *void, pConfig: *drmp3_config, pTotalFrameCount: *drmp3_uint64, pAllocationCallbacks: *drmp3_allocation_callbacks) -> *drmp3_int16 #foreign dr_mp3;

drmp3_open_memory_and_read_pcm_frames_f32 :: (pData: *void, dataSize: u64, pConfig: *drmp3_config, pTotalFrameCount: *drmp3_uint64, pAllocationCallbacks: *drmp3_allocation_callbacks) -> *float #foreign dr_mp3;
drmp3_open_memory_and_read_pcm_frames_s16 :: (pData: *void, dataSize: u64, pConfig: *drmp3_config, pTotalFrameCount: *drmp3_uint64, pAllocationCallbacks: *drmp3_allocation_callbacks) -> *drmp3_int16 #foreign dr_mp3;

drmp3_open_file_and_read_pcm_frames_f32 :: (filePath: *u8, pConfig: *drmp3_config, pTotalFrameCount: *drmp3_uint64, pAllocationCallbacks: *drmp3_allocation_callbacks) -> *float #foreign dr_mp3;
drmp3_open_file_and_read_pcm_frames_s16 :: (filePath: *u8, pConfig: *drmp3_config, pTotalFrameCount: *drmp3_uint64, pAllocationCallbacks: *drmp3_allocation_callbacks) -> *drmp3_int16 #foreign dr_mp3;

/*
Allocates a block of memory on the heap.
*/
drmp3_malloc :: (sz: u64, pAllocationCallbacks: *drmp3_allocation_callbacks) -> *void #foreign dr_mp3;

/*
Frees any memory that was allocated by a public drmp3 API.
*/
drmp3_free :: (p: *void, pAllocationCallbacks: *drmp3_allocation_callbacks) -> void #foreign dr_mp3;

#scope_file


#if OS == {
case .LINUX;    dr_mp3 :: #library "linux/dr_mp3";
case .WINDOWS;  dr_mp3 :: #library "windows/dr_mp3";
case .MACOS;    dr_mp3 :: #library "macos/dr_mp3";
case .IOS;
    SIMULATOR :: true;
    #if SIMULATOR  1dr_mp3 :: #library "ios/dr_mp3_simulator";
    else           1dr_mp3 :: #library "ios/dr_mp3";
case .ANDROID;
    #if CPU == .ARM64  dr_mp3 :: #library "android/arm64/dr_mp3";
    #if CPU == .X64    dr_mp3 :: #library "android/x64/dr_mp3";
}

