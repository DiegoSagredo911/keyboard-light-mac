//
//  AudioCaptureEngine.m
//  keyboard light mac
//

#import "AudioCaptureEngine.h"
#import "AudioAnalyzer.h"
#import "KeyboardController.h"
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <CoreGraphics/CoreGraphics.h>

@implementation AudioDeviceInfo
@end

@interface AudioCaptureEngine () <SCStreamOutput, SCStreamDelegate>
@end

@implementation AudioCaptureEngine {
    AVAudioEngine *_audioEngine;
    SCStream *_scStream;
    dispatch_queue_t _audioQueue;
    dispatch_source_t _watchdogTimer;
    BOOL _isRunning;
}

+ (instancetype)sharedEngine {
    static AudioCaptureEngine *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[AudioCaptureEngine alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sourceType = AudioSourceTypeMicrophone;
        _selectedDeviceID = 0;
        _isRunning = NO;
        _audioQueue = dispatch_queue_create("com.keyboardlight.audioqueue", DISPATCH_QUEUE_SERIAL);
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleConfigurationChange:)
                                                     name:AVAudioEngineConfigurationChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopWatchdogTimer];
}

+ (BOOL)hasScreenCapturePermission {
    return CGPreflightScreenCaptureAccess();
}

+ (void)requestScreenCapturePermission {
    CGRequestScreenCaptureAccess();
}

+ (NSArray<AudioDeviceInfo *> *)availableInputDevices {
    NSMutableArray<AudioDeviceInfo *> *devices = [NSMutableArray array];
    
    AudioObjectPropertyAddress prop = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    
    UInt32 dataSize = 0;
    OSStatus status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &prop, 0, NULL, &dataSize);
    if (status != noErr || dataSize == 0) return devices;
    
    UInt32 deviceCount = dataSize / sizeof(AudioDeviceID);
    AudioDeviceID *deviceIDs = (AudioDeviceID *)malloc(dataSize);
    status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &prop, 0, NULL, &dataSize, deviceIDs);
    if (status != noErr) {
        free(deviceIDs);
        return devices;
    }
    
    for (UInt32 i = 0; i < deviceCount; i++) {
        AudioDeviceID devID = deviceIDs[i];
        
        AudioObjectPropertyAddress streamProp = {
            kAudioDevicePropertyStreamConfiguration,
            kAudioDevicePropertyScopeInput,
            kAudioObjectPropertyElementMain
        };
        UInt32 streamSize = 0;
        if (AudioObjectGetPropertyDataSize(devID, &streamProp, 0, NULL, &streamSize) != noErr || streamSize == 0) {
            continue;
        }
        
        AudioBufferList *bufferList = (AudioBufferList *)malloc(streamSize);
        if (AudioObjectGetPropertyData(devID, &streamProp, 0, NULL, &streamSize, bufferList) == noErr) {
            int inputChannels = 0;
            for (UInt32 j = 0; j < bufferList->mNumberBuffers; j++) {
                inputChannels += bufferList->mBuffers[j].mNumberChannels;
            }
            
            if (inputChannels > 0) {
                CFStringRef devName = NULL;
                UInt32 nameSize = sizeof(devName);
                AudioObjectPropertyAddress nameProp = {
                    kAudioObjectPropertyName,
                    kAudioObjectPropertyScopeGlobal,
                    kAudioObjectPropertyElementMain
                };
                AudioObjectGetPropertyData(devID, &nameProp, 0, NULL, &nameSize, &devName);
                
                CFStringRef devUID = NULL;
                UInt32 uidSize = sizeof(devUID);
                AudioObjectPropertyAddress uidProp = {
                    kAudioDevicePropertyDeviceUID,
                    kAudioObjectPropertyScopeGlobal,
                    kAudioObjectPropertyElementMain
                };
                AudioObjectGetPropertyData(devID, &uidProp, 0, NULL, &uidSize, &devUID);
                
                AudioDeviceInfo *info = [[AudioDeviceInfo alloc] init];
                info.deviceID = devID;
                info.name = devName ? (__bridge NSString *)devName : [NSString stringWithFormat:@"Device %u", devID];
                info.uid = devUID ? (__bridge NSString *)devUID : @"";
                [devices addObject:info];
                
                if (devName) CFRelease(devName);
                if (devUID) CFRelease(devUID);
            }
        }
        free(bufferList);
    }
    
    free(deviceIDs);
    return devices;
}

- (BOOL)isRunning {
    return _isRunning;
}

- (void)setSourceType:(AudioSourceType)type deviceID:(AudioDeviceID)devID {
    BOOL wasRunning = _isRunning;
    if (wasRunning) {
        [self stop];
    }
    _sourceType = type;
    _selectedDeviceID = devID;
    if (wasRunning) {
        [self start];
    }
}

- (void)startWatchdogTimer {
    if (_watchdogTimer) return;
    _watchdogTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_watchdogTimer, dispatch_time(DISPATCH_TIME_NOW, 0), 25 * NSEC_PER_MSEC, 5 * NSEC_PER_MSEC);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_watchdogTimer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf->_isRunning) return;
        float b = [[AudioAnalyzer sharedAnalyzer] forceCheckTimeout];
        [[KeyboardController sharedController] setBrightness:b];
    });
    dispatch_resume(_watchdogTimer);
}

- (void)stopWatchdogTimer {
    if (_watchdogTimer) {
        dispatch_source_cancel(_watchdogTimer);
        _watchdogTimer = nil;
    }
}

- (void)handleConfigurationChange:(NSNotification *)note {
    NSLog(@"[AudioCaptureEngine] Audio hardware configuration changed!");
    if (_isRunning && _sourceType != AudioSourceTypeSystemAudio) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self->_isRunning) {
                [self stop];
                [self start];
            }
        });
    }
}

- (BOOL)start {
    if (_isRunning) return YES;
    
    BOOL success = NO;
    if (_sourceType == AudioSourceTypeSystemAudio) {
        success = [self startSystemAudioCapture];
    } else {
        success = [self startMicrophoneCapture];
    }
    
    if (success) {
        [self startWatchdogTimer];
    }
    return success;
}

- (void)stop {
    if (!_isRunning) return;
    [self stopWatchdogTimer];
    
    if (_audioEngine) {
        [[_audioEngine inputNode] removeTapOnBus:0];
        [_audioEngine stop];
        _audioEngine = nil;
    }
    
    if (_scStream) {
        [_scStream stopCaptureWithCompletionHandler:nil];
        _scStream = nil;
    }
    
    [[AudioAnalyzer sharedAnalyzer] reset];
    [[KeyboardController sharedController] restoreOriginalBrightness];
    _isRunning = NO;
}

#pragma mark - Microphone / CoreAudio Capture

- (BOOL)startMicrophoneCapture {
    NSError *error = nil;
    _audioEngine = [[AVAudioEngine alloc] init];
    AVAudioInputNode *inputNode = [_audioEngine inputNode];
    
    if (_selectedDeviceID != 0) {
        AudioUnit audioUnit = inputNode.audioUnit;
        if (audioUnit) {
            AudioUnitSetProperty(audioUnit,
                                 kAudioOutputUnitProperty_CurrentDevice,
                                 kAudioUnitScope_Global,
                                 0,
                                 &_selectedDeviceID,
                                 sizeof(_selectedDeviceID));
        }
    }
    
    AVAudioFormat *format = [inputNode outputFormatForBus:0];
    if (format.sampleRate == 0 || format.channelCount == 0) {
        format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:1];
    }
    
    __weak typeof(self) weakSelf = self;
    [inputNode installTapOnBus:0 bufferSize:512 format:format block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf->_isRunning) return;
        
        float *const *channelData = buffer.floatChannelData;
        if (!channelData) return;
        
        float *samples = channelData[0];
        NSUInteger count = buffer.frameLength;
        double srate = format.sampleRate;
        
        float bright = [[AudioAnalyzer sharedAnalyzer] processAudioSamples:samples count:count sampleRate:srate];
        [[KeyboardController sharedController] setBrightness:bright];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([strongSelf.delegate respondsToSelector:@selector(audioCaptureDidOutputLevel:brightness:isBeat:)]) {
                float level = [[AudioAnalyzer sharedAnalyzer] currentAudioLevel];
                BOOL isBeat = [[AudioAnalyzer sharedAnalyzer] isBeatDetected];
                [strongSelf.delegate audioCaptureDidOutputLevel:level brightness:bright isBeat:isBeat];
            }
        });
    }];
    
    if (![_audioEngine startAndReturnError:&error]) {
        NSLog(@"[AudioCaptureEngine] Error starting AVAudioEngine: %@", error);
        if ([self.delegate respondsToSelector:@selector(audioCaptureDidFailWithError:)]) {
            [self.delegate audioCaptureDidFailWithError:[error localizedDescription]];
        }
        return NO;
    }
    
    _isRunning = YES;
    return YES;
}

#pragma mark - ScreenCaptureKit System Audio

- (BOOL)startSystemAudioCapture {
    if (![AudioCaptureEngine hasScreenCapturePermission]) {
        [AudioCaptureEngine requestScreenCapturePermission];
        if ([self.delegate respondsToSelector:@selector(audioCapturePermissionNeeded:)]) {
            [self.delegate audioCapturePermissionNeeded:@"Screen Recording (Grabación de Pantalla y Audio del Sistema)"];
        }
        return NO;
    }
    
    __weak typeof(self) weakSelf = self;
    [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent * _Nullable shareableContent, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (error || !shareableContent || shareableContent.displays.count == 0) {
            NSLog(@"[AudioCaptureEngine] ScreenCaptureKit error: %@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([strongSelf.delegate respondsToSelector:@selector(audioCaptureDidFailWithError:)]) {
                    [strongSelf.delegate audioCaptureDidFailWithError:error ? error.localizedDescription : @"No displays found"];
                }
            });
            return;
        }
        
        SCDisplay *display = shareableContent.displays.firstObject;
        SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:display excludingWindows:@[]];
        
        SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
        config.capturesAudio = YES;
        config.sampleRate = 48000;
        config.channelCount = 2;
        config.excludesCurrentProcessAudio = YES;
        // Keep dimensions minimal for audio-only
        config.width = 4;
        config.height = 4;
        config.minimumFrameInterval = CMTimeMake(1, 10);
        
        strongSelf->_scStream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:strongSelf];
        
        NSError *streamError = nil;
        [strongSelf->_scStream addStreamOutput:strongSelf type:SCStreamOutputTypeAudio sampleHandlerQueue:strongSelf->_audioQueue error:&streamError];
        if (streamError) {
            NSLog(@"[AudioCaptureEngine] Error adding audio stream output: %@", streamError);
            return;
        }
        
        [strongSelf->_scStream startCaptureWithCompletionHandler:^(NSError * _Nullable startError) {
            if (startError) {
                NSLog(@"[AudioCaptureEngine] Error starting SCStream: %@", startError);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([strongSelf.delegate respondsToSelector:@selector(audioCaptureDidFailWithError:)]) {
                        [strongSelf.delegate audioCaptureDidFailWithError:startError.localizedDescription];
                    }
                });
            } else {
                strongSelf->_isRunning = YES;
                [strongSelf startWatchdogTimer];
                NSLog(@"[AudioCaptureEngine] ScreenCaptureKit audio capture started successfully!");
            }
        }];
    }];
    
    return YES;
}

#pragma mark - SCStreamOutput

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
    if (type != SCStreamOutputTypeAudio || !_isRunning) return;
    
    AudioBufferList audioBufferList;
    CMBlockBufferRef blockBuffer = NULL;
    
    OSStatus status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
        sampleBuffer,
        NULL,
        &audioBufferList,
        sizeof(audioBufferList),
        NULL,
        NULL,
        0,
        &blockBuffer
    );
    
    if (status != noErr || audioBufferList.mNumberBuffers == 0) {
        if (blockBuffer) CFRelease(blockBuffer);
        return;
    }
    
    void *dataPtr = audioBufferList.mBuffers[0].mData;
    UInt32 byteSize = audioBufferList.mBuffers[0].mDataByteSize;
    if (!dataPtr || byteSize == 0) {
        if (blockBuffer) CFRelease(blockBuffer);
        return;
    }
    
    CMAudioFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    const AudioStreamBasicDescription *asbd = formatDesc ? CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) : NULL;
    
    BOOL isFloat = YES;
    if (asbd) {
        isFloat = (asbd->mFormatFlags & kAudioFormatFlagIsFloat) != 0;
    }
    
    float *floatSamples = NULL;
    NSUInteger sampleCount = 0;
    float localBuffer[1024];
    float *allocatedBuffer = NULL;
    
    if (isFloat) {
        floatSamples = (float *)dataPtr;
        sampleCount = byteSize / sizeof(float);
    } else {
        int16_t *intSamples = (int16_t *)dataPtr;
        sampleCount = byteSize / sizeof(int16_t);
        if (sampleCount <= 1024) {
            floatSamples = localBuffer;
        } else {
            allocatedBuffer = (float *)malloc(sampleCount * sizeof(float));
            floatSamples = allocatedBuffer;
        }
        for (NSUInteger i = 0; i < sampleCount; i++) {
            floatSamples[i] = (float)intSamples[i] / 32768.0f;
        }
    }
    
    double srate = (asbd && asbd->mSampleRate > 0) ? asbd->mSampleRate : 48000.0;
    float bright = [[AudioAnalyzer sharedAnalyzer] processAudioSamples:floatSamples count:sampleCount sampleRate:srate];
    [[KeyboardController sharedController] setBrightness:bright];
    
    if (allocatedBuffer) {
        free(allocatedBuffer);
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && [strongSelf.delegate respondsToSelector:@selector(audioCaptureDidOutputLevel:brightness:isBeat:)]) {
            float level = [[AudioAnalyzer sharedAnalyzer] currentAudioLevel];
            BOOL isBeat = [[AudioAnalyzer sharedAnalyzer] isBeatDetected];
            [strongSelf.delegate audioCaptureDidOutputLevel:level brightness:bright isBeat:isBeat];
        }
    });
    
    if (blockBuffer) {
        CFRelease(blockBuffer);
    }
}

- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
    NSLog(@"[AudioCaptureEngine] SCStream stopped: %@", error);
    if (_isRunning) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self->_isRunning) {
                [self startSystemAudioCapture];
            }
        });
    }
}

@end
