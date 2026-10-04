//
//  TypingSpeedometerEngine.m
//  keyboard light mac
//

#import "TypingSpeedometerEngine.h"
#import "KeyboardController.h"
#import <ApplicationServices/ApplicationServices.h>

#define MAX_TIMESTAMPS 128

@implementation TypingSpeedometerEngine {
    id _globalMonitor;
    id _localMonitor;
    dispatch_source_t _timer;
    
    NSTimeInterval _timestamps[MAX_TIMESTAMPS];
    int _timestampCount;
    int _timestampHead;
    
    NSTimeInterval _lastStrokeTime;
    NSTimeInterval _flashEndTime;
    
    float _currentWPM;
    float _currentCPS;
    float _smoothedSpeed;
    float _currentBrightness;
    
    BOOL _isRunning;
    BOOL _recentKeyHit;
}

+ (instancetype)sharedEngine {
    static TypingSpeedometerEngine *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[TypingSpeedometerEngine alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isRunning = NO;
        _targetMaxWPM = 75.0f; // 75 WPM = velocidad rápida típica
        _mode = TypingModeKeyStrobe;
        _flashDuration = 0.045; // 45ms de destello estroboscópico por tecla
        _currentWPM = 0.0f;
        _currentCPS = 0.0f;
        _smoothedSpeed = 0.0f;
        _currentBrightness = 0.0f;
        _timestampCount = 0;
        _timestampHead = 0;
        _lastStrokeTime = 0.0;
        _flashEndTime = 0.0;
        _recentKeyHit = NO;
    }
    return self;
}

+ (BOOL)hasAccessibilityPermission {
    return AXIsProcessTrusted();
}

+ (void)requestAccessibilityPermission {
    NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
    AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

- (BOOL)start {
    if (_isRunning) return YES;
    
    if (![TypingSpeedometerEngine hasAccessibilityPermission]) {
        [TypingSpeedometerEngine requestAccessibilityPermission];
        if ([self.delegate respondsToSelector:@selector(typingSpeedometerPermissionNeeded)]) {
            [self.delegate typingSpeedometerPermissionNeeded];
        }
    }
    
    _timestampCount = 0;
    _timestampHead = 0;
    _currentWPM = 0.0f;
    _currentCPS = 0.0f;
    _smoothedSpeed = 0.0f;
    _currentBrightness = 0.0f;
    
    [[KeyboardController sharedController] turnOff];
    
    __weak typeof(self) weakSelf = self;
    _globalMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^(NSEvent *event) {
        [weakSelf handleKeyStroke];
    }];
    
    _localMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        [weakSelf handleKeyStroke];
        return event;
    }];
    
    // 50 Hz physics & animation timer
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, 0), 20 * NSEC_PER_MSEC, 5 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(_timer, ^{
        [weakSelf updateSpeedometerTick];
    });
    dispatch_resume(_timer);
    
    _isRunning = YES;
    return YES;
}

- (void)stop {
    if (!_isRunning) return;
    
    if (_globalMonitor) {
        [NSEvent removeMonitor:_globalMonitor];
        _globalMonitor = nil;
    }
    
    if (_localMonitor) {
        [NSEvent removeMonitor:_localMonitor];
        _localMonitor = nil;
    }
    
    if (_timer) {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }
    
    _isRunning = NO;
    _currentWPM = 0.0f;
    _currentCPS = 0.0f;
    _smoothedSpeed = 0.0f;
    [[KeyboardController sharedController] restoreOriginalBrightness];
}

- (void)handleKeyStroke {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    _lastStrokeTime = now;
    _flashEndTime = now + _flashDuration;
    _recentKeyHit = YES;
    
    // Add to circular buffer
    _timestamps[_timestampHead] = now;
    _timestampHead = (_timestampHead + 1) % MAX_TIMESTAMPS;
    if (_timestampCount < MAX_TIMESTAMPS) _timestampCount++;
    
    // Immediate physical feedback
    if (_mode == TypingModeKeyStrobe) {
        [[KeyboardController sharedController] setBrightness:1.0f];
    }
}

- (void)updateSpeedometerTick {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    // Calculate typing speed within sliding 3.0s window
    NSTimeInterval window = 3.0;
    int validStrokes = 0;
    NSTimeInterval oldestInWindow = now;
    
    for (int i = 0; i < _timestampCount; i++) {
        int idx = (_timestampHead - 1 - i + MAX_TIMESTAMPS) % MAX_TIMESTAMPS;
        NSTimeInterval t = _timestamps[idx];
        if (now - t <= window) {
            validStrokes++;
            if (t < oldestInWindow) oldestInWindow = t;
        }
    }
    
    // If no typing for 1.5 seconds, speed drops to 0
    if ((now - _lastStrokeTime) > 1.5) {
        validStrokes = 0;
    }
    
    float span = (now - oldestInWindow);
    if (span < 0.35) span = 0.35; // Avoid division by zero on first stroke
    
    float cps = (validStrokes > 0) ? ((float)validStrokes / (float)span) : 0.0f;
    // Standard formula: 1 word = 5 characters
    float wpm = cps * 60.0f / 5.0f;
    
    _currentCPS = cps;
    _currentWPM = wpm;
    
    float normalized = fminf(1.0f, wpm / _targetMaxWPM);
    _normalizedSpeed = normalized;
    
    // Smooth the speed needle (Tacómetro)
    float attackDecay = (normalized > _smoothedSpeed) ? 0.15f : 0.05f;
    _smoothedSpeed += (normalized - _smoothedSpeed) * attackDecay;
    
    float targetBrightness = 0.0f;
    
    switch (_mode) {
        case TypingModeKeyStrobe: {
            // Destello estroboscópico por cada pulsación de tecla
            if (now < _flashEndTime) {
                targetBrightness = 1.0f;
            } else {
                targetBrightness = 0.0f;
            }
            break;
        }
            
        case TypingModeSpeedometerRev: {
            // Tacómetro puro: El brillo sube progresivamente como el tacómetro de un auto
            targetBrightness = _smoothedSpeed;
            break;
        }
            
        case TypingModeTurboStrobe: {
            // Modo Turbo: Si escribes rápido (> 50 WPM), parpadea a alta frecuencia
            if (normalized > 0.60f) {
                // Parpadeo ultra rápido proporcional a la velocidad
                double freq = 8.0 + (normalized - 0.60f) * 20.0; // 8Hz a 16Hz
                float cycle = sin(now * 2.0 * M_PI * freq);
                targetBrightness = (cycle > 0.0f) ? 1.0f : 0.0f;
            } else {
                // A velocidad moderada, destello individual por tecla
                if (now < _flashEndTime) {
                    targetBrightness = fmaxf(0.5f, normalized);
                } else {
                    targetBrightness = 0.0f;
                }
            }
            break;
        }
    }
    
    _currentBrightness = targetBrightness;
    [[KeyboardController sharedController] setBrightness:_currentBrightness];
    
    BOOL isHit = _recentKeyHit;
    _recentKeyHit = NO;
    
    if ([self.delegate respondsToSelector:@selector(typingSpeedometerDidUpdateWPM:cps:brightness:isKeyStroke:)]) {
        [self.delegate typingSpeedometerDidUpdateWPM:_currentWPM cps:_currentCPS brightness:_currentBrightness isKeyStroke:isHit];
    }
}

- (void)dealloc {
    [self stop];
}

@end
