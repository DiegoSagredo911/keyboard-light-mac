//
//  KeyboardController.m
//  keyboard light mac
//

#import "KeyboardController.h"
#import <objc/runtime.h>

@interface KeyboardBrightnessClient : NSObject
- (NSArray *)copyKeyboardBacklightIDs;
- (float)brightnessForKeyboard:(unsigned long long)keyboardID;
- (BOOL)setBrightness:(float)brightness forKeyboard:(unsigned long long)keyboardID;
- (BOOL)setBrightness:(float)brightness fadeSpeed:(int)speed commit:(BOOL)commit forKeyboard:(unsigned long long)keyboardID;
- (BOOL)enableAutoBrightness:(BOOL)enable forKeyboard:(unsigned long long)keyboardID;
- (BOOL)isAutoBrightnessEnabledForKeyboard:(unsigned long long)keyboardID;
- (BOOL)suspendIdleDimming:(BOOL)suspend forKeyboard:(unsigned long long)keyboardID;
- (BOOL)isIdleDimmingSuspendedOnKeyboard:(unsigned long long)keyboardID;
@end

@implementation KeyboardController {
    KeyboardBrightnessClient *_client;
    NSMutableArray<NSNumber *> *_keyboardIDs;
    float _originalBrightness;
    BOOL _originalAutoBrightness;
    float _lastSetBrightness;
    BOOL _hasOriginal;
    BOOL _hardwareSettingsOverridden;
}

+ (instancetype)sharedController {
    static KeyboardController *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[KeyboardController alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _keyboardIDs = [NSMutableArray array];
        _lastSetBrightness = -1.0f;
        _hasOriginal = NO;
        _hardwareSettingsOverridden = NO;
        [self setupClient];
    }
    return self;
}

- (void)setupClient {
    Class clientClass = NSClassFromString(@"KeyboardBrightnessClient");
    if (clientClass) {
        _client = [[clientClass alloc] init];
        NSArray *ids = [_client copyKeyboardBacklightIDs];
        if (ids && ids.count > 0) {
            [_keyboardIDs removeAllObjects];
            [_keyboardIDs addObjectsFromArray:ids];
            unsigned long long primaryID = [_keyboardIDs.firstObject unsignedLongLongValue];
            if (!_hasOriginal) {
                _originalBrightness = [_client brightnessForKeyboard:primaryID];
                _originalAutoBrightness = [_client isAutoBrightnessEnabledForKeyboard:primaryID];
                _hasOriginal = YES;
            }
        }
    }
}

- (BOOL)isAvailable {
    return _client != nil && _keyboardIDs.count > 0;
}

- (float)originalBrightness {
    return _originalBrightness;
}

- (BOOL)originalAutoBrightness {
    return _originalAutoBrightness;
}

- (float)currentBrightness {
    if (!self.isAvailable) return 0.0f;
    unsigned long long primaryID = [_keyboardIDs.firstObject unsignedLongLongValue];
    return [_client brightnessForKeyboard:primaryID];
}

- (void)overrideHardwareSettingsIfNeeded {
    if (_hardwareSettingsOverridden || !self.isAvailable) return;
    for (NSNumber *kbdNum in _keyboardIDs) {
        unsigned long long kbdID = [kbdNum unsignedLongLongValue];
        // 1. Prevent macOS from turning off keyboard light due to lack of typing/idle
        [_client suspendIdleDimming:YES forKeyboard:kbdID];
        // 2. Prevent ambient light sensor from overriding manual keyboard brightness
        [_client enableAutoBrightness:NO forKeyboard:kbdID];
    }
    _hardwareSettingsOverridden = YES;
}

- (void)turnOff {
    if (!self.isAvailable) return;
    [self overrideHardwareSettingsIfNeeded];
    _lastSetBrightness = -1.0f;
    for (NSNumber *kbdNum in _keyboardIDs) {
        unsigned long long kbdID = [kbdNum unsignedLongLongValue];
        [_client setBrightness:0.0f forKeyboard:kbdID];
    }
    _lastSetBrightness = 0.0f;
}

- (BOOL)setBrightness:(float)brightness {
    if (!self.isAvailable) return NO;
    [self overrideHardwareSettingsIfNeeded];
    
    // Clamp to [0.0, 1.0]
    if (brightness < 0.0f) brightness = 0.0f;
    if (brightness > 1.0f) brightness = 1.0f;
    
    // Don't spam hardware if change is minuscule (< 0.005)
    if (fabsf(brightness - _lastSetBrightness) < 0.005f) {
        return YES;
    }
    
    _lastSetBrightness = brightness;
    BOOL success = YES;
    for (NSNumber *kbdNum in _keyboardIDs) {
        unsigned long long kbdID = [kbdNum unsignedLongLongValue];
        BOOL ok = [_client setBrightness:brightness forKeyboard:kbdID];
        if (!ok) {
            // If connection to CoreBrightness dropped, reinitialize
            [self setupClient];
            [_client setBrightness:brightness forKeyboard:kbdID];
            success = NO;
        }
    }
    return success;
}

- (BOOL)fadeToBrightness:(float)brightness duration:(NSTimeInterval)duration {
    if (!self.isAvailable) return NO;
    [self overrideHardwareSettingsIfNeeded];
    int steps = (int)(duration * 60.0);
    if (steps < 1) steps = 1;
    
    float start = self.currentBrightness;
    float delta = (brightness - start) / (float)steps;
    useconds_t sleepTime = (useconds_t)((duration / (double)steps) * 1000000.0);
    
    for (int i = 1; i <= steps; i++) {
        [self setBrightness:(start + delta * (float)i)];
        usleep(sleepTime);
    }
    return [self setBrightness:brightness];
}

- (void)restoreOriginalBrightness {
    if (_hasOriginal && self.isAvailable) {
        for (NSNumber *kbdNum in _keyboardIDs) {
            unsigned long long kbdID = [kbdNum unsignedLongLongValue];
            // Restore macOS default idle dimming & auto brightness
            [_client suspendIdleDimming:NO forKeyboard:kbdID];
            [_client enableAutoBrightness:_originalAutoBrightness forKeyboard:kbdID];
            [_client setBrightness:_originalBrightness forKeyboard:kbdID];
        }
        _lastSetBrightness = _originalBrightness;
        _hardwareSettingsOverridden = NO;
    }
}

- (void)dealloc {
    [self restoreOriginalBrightness];
}

@end
