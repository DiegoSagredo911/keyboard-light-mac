//
//  AudioAnalyzer.m
//  keyboard light mac
//

#import "AudioAnalyzer.h"
#import <math.h>

@implementation AudioAnalyzer {
    // Biquad filter state for lowpass (bass/kick isolation)
    float _b0, _b1, _b2, _a1, _a2;
    float _x1, _x2, _y1, _y2;
    double _lastSampleRate;
    
    // Beat & Transient detection state
    float _bassHistory[32];
    int _historyIndex;
    int _historyCount;
    
    float _prevBassEnergy;
    float _prevHighEnergy;
    float _prevFullEnergy;
    
    NSTimeInterval _lastBeatTime;
    NSTimeInterval _flashEndTime;
    NSTimeInterval _lastAudioProcessTime;
    
    // Envelope follower
    float _currentBrightness;
    float _audioLevel;
    BOOL _beatDetected;
}

+ (instancetype)sharedAnalyzer {
    static AudioAnalyzer *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[AudioAnalyzer alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mode = AudioReactionModeStrobe;
        _sensitivity = 1.8f;
        _minBrightness = 0.0f;
        _maxBrightness = 1.0f;
        _decaySpeed = 0.20f;
        _noiseGate = 0.008f;
        _flashDuration = 0.045; // 45 milisegundos de destello estroboscópico
        
        _currentBrightness = 0.0f;
        _audioLevel = 0.0f;
        _beatDetected = NO;
        _lastSampleRate = 0.0;
        _lastBeatTime = 0.0;
        _flashEndTime = 0.0;
        _prevBassEnergy = 0.0f;
        _prevHighEnergy = 0.0f;
        _prevFullEnergy = 0.0f;
        _lastAudioProcessTime = 0.0;
        
        [self reset];
    }
    return self;
}

- (void)reset {
    _x1 = _x2 = _y1 = _y2 = 0.0f;
    _historyIndex = 0;
    _historyCount = 0;
    for (int i = 0; i < 32; i++) {
        _bassHistory[i] = 0.0f;
    }
    _currentBrightness = _minBrightness;
    _audioLevel = 0.0f;
    _beatDetected = NO;
    _lastBeatTime = 0.0;
    _flashEndTime = 0.0;
    _prevBassEnergy = 0.0f;
    _prevHighEnergy = 0.0f;
    _prevFullEnergy = 0.0f;
    _lastAudioProcessTime = [NSDate timeIntervalSinceReferenceDate];
}

- (void)updateBiquadCoefficients:(double)sampleRate {
    if (fabs(sampleRate - _lastSampleRate) < 1.0) return;
    _lastSampleRate = sampleRate;
    
    // 2nd-order Butterworth low-pass filter around 200 Hz
    double cutoff = 200.0;
    if (cutoff > sampleRate * 0.45) cutoff = sampleRate * 0.45;
    
    double omega = 2.0 * M_PI * cutoff / sampleRate;
    double sn = sin(omega);
    double cs = cos(omega);
    double alpha = sn / (2.0 * 0.7071);
    
    double a0 = 1.0 + alpha;
    _b0 = (float)(((1.0 - cs) / 2.0) / a0);
    _b1 = (float)((1.0 - cs) / a0);
    _b2 = (float)(((1.0 - cs) / 2.0) / a0);
    _a1 = (float)((-2.0 * cs) / a0);
    _a2 = (float)((1.0 - alpha) / a0);
}

- (float)processAudioSamples:(const float *)samples count:(NSUInteger)count sampleRate:(double)sampleRate {
    if (!samples || count == 0) return _currentBrightness;
    
    _lastAudioProcessTime = [NSDate timeIntervalSinceReferenceDate];
    [self updateBiquadCoefficients:sampleRate];
    
    float totalSumSq = 0.0f;
    float bassSumSq = 0.0f;
    float highDiffSumSq = 0.0f;
    
    for (NSUInteger i = 0; i < count; i++) {
        float in = samples[i];
        totalSumSq += in * in;
        
        // Lowpass biquad filter for bass / kick
        float out = _b0 * in + _b1 * _x1 + _b2 * _x2 - _a1 * _y1 - _a2 * _y2;
        _x2 = _x1;
        _x1 = in;
        _y2 = _y1;
        _y1 = out;
        bassSumSq += out * out;
        
        // High frequency transient calculation (first difference)
        float diff = in - _x1;
        highDiffSumSq += diff * diff;
    }
    
    float fullRms = sqrtf(totalSumSq / (float)count);
    float bassRms = sqrtf(bassSumSq / (float)count);
    float highRms = sqrtf(highDiffSumSq / (float)count);
    
    // Noise gate
    if (fullRms < _noiseGate) {
        fullRms = 0.0f;
        bassRms = 0.0f;
        highRms = 0.0f;
    }
    
    // Scale by sensitivity
    float scaledFull = fminf(1.0f, fullRms * _sensitivity);
    float scaledBass = fminf(1.0f, bassRms * _sensitivity);
    float scaledHigh = fminf(1.0f, highRms * _sensitivity);
    
    _audioLevel = scaledFull;
    
    // Running history of bass for dynamic baseline
    _bassHistory[_historyIndex] = scaledBass;
    _historyIndex = (_historyIndex + 1) % 32;
    if (_historyCount < 32) _historyCount++;
    
    float avgBass = 0.0f;
    for (int i = 0; i < _historyCount; i++) {
        avgBass += _bassHistory[i];
    }
    avgBass /= (float)_historyCount;
    
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    BOOL beatHit = NO;
    
    // Transient derivatives (positive change in energy)
    float bassDelta = scaledBass - _prevBassEnergy;
    _prevBassEnergy = scaledBass;
    
    float highDelta = scaledHigh - _prevHighEnergy;
    _prevHighEnergy = scaledHigh;
    
    float fullDelta = scaledFull - _prevFullEnergy;
    _prevFullEnergy = scaledFull;
    
    // 1) Sharp kick drum onset (always detects new drum hits regardless of loudness)
    BOOL sharpBassOnset = (bassDelta > 0.035f && scaledBass > 0.07f);
    
    // 2) Bounded adaptive threshold (NEVER exceeds 0.82 so it never locks up!)
    float dynamicMargin = fmaxf(0.025f, (1.0f - avgBass) * 0.18f);
    float boundedBassThreshold = fminf(0.82f, avgBass + dynamicMargin);
    BOOL aboveBassThreshold = (scaledBass > boundedBassThreshold && scaledBass > 0.07f);
    
    // 3) Sharp high frequency onset (snare, claps, synth drops, hi-hats)
    BOOL sharpHighOnset = (highDelta > 0.05f && scaledHigh > 0.09f);
    
    // 4) General sudden volume punch
    BOOL sharpFullOnset = (fullDelta > 0.06f && scaledFull > 0.10f);
    
    BOOL shouldTrigger = sharpBassOnset || aboveBassThreshold || sharpHighOnset || sharpFullOnset;
    
    // Minimum cooldown between flashes
    NSTimeInterval minCooldown = (_mode == AudioReactionModeStrobe) ? 0.040 : 0.080;
    
    if (shouldTrigger && (now - _lastBeatTime) > minCooldown) {
        beatHit = YES;
        _lastBeatTime = now;
        _flashEndTime = now + _flashDuration;
    }
    _beatDetected = beatHit;
    
    // Calculate output brightness based on mode
    switch (_mode) {
        case AudioReactionModeStrobe: {
            if (now < _flashEndTime) {
                _currentBrightness = _maxBrightness;
            } else {
                _currentBrightness = _minBrightness;
            }
            break;
        }
            
        case AudioReactionModeBeat: {
            if (beatHit) {
                _currentBrightness = _maxBrightness;
            } else {
                _currentBrightness -= _decaySpeed;
                if (_currentBrightness < _minBrightness) {
                    _currentBrightness = _minBrightness;
                }
            }
            break;
        }
            
        case AudioReactionModeRMS: {
            float target = _minBrightness + scaledFull * (_maxBrightness - _minBrightness);
            if (target > _currentBrightness) {
                _currentBrightness = target;
            } else {
                _currentBrightness -= _decaySpeed * 0.5f;
                if (_currentBrightness < _minBrightness) {
                    _currentBrightness = _minBrightness;
                }
            }
            break;
        }
            
        case AudioReactionModeHybrid: {
            float ambientGlow = _minBrightness + (scaledFull * 0.35f) * (_maxBrightness - _minBrightness);
            if (now < _flashEndTime) {
                _currentBrightness = _maxBrightness;
            } else {
                if (_currentBrightness > ambientGlow) {
                    _currentBrightness -= _decaySpeed;
                    if (_currentBrightness < ambientGlow) {
                        _currentBrightness = ambientGlow;
                    }
                } else {
                    _currentBrightness = ambientGlow;
                }
            }
            break;
        }
    }
    
    return _currentBrightness;
}

- (float)forceCheckTimeout {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    // If strobe flash duration expired, immediately drop to minBrightness
    if (_mode == AudioReactionModeStrobe) {
        if (now >= _flashEndTime && _currentBrightness > _minBrightness) {
            _currentBrightness = _minBrightness;
            return _currentBrightness;
        }
    }
    
    // If no audio processed in 120ms (e.g. music paused or silent), ensure keyboard stays at minBrightness
    if ((now - _lastAudioProcessTime) > 0.12) {
        _audioLevel = 0.0f;
        _beatDetected = NO;
        if (_currentBrightness > _minBrightness) {
            _currentBrightness -= _decaySpeed;
            if (_currentBrightness < _minBrightness) {
                _currentBrightness = _minBrightness;
            }
        }
    }
    
    return _currentBrightness;
}

- (NSTimeInterval)flashEndTime {
    return _flashEndTime;
}

- (float)currentAudioLevel {
    return _audioLevel;
}

- (float)targetBrightness {
    return _currentBrightness;
}

- (BOOL)isBeatDetected {
    return _beatDetected;
}

@end
