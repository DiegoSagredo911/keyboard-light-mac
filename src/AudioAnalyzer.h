//
//  AudioAnalyzer.h
//  keyboard light mac
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AudioReactionMode) {
    AudioReactionModeStrobe = 0,  // ⚡️ Estroboscópico Ultra Rápido (Destellos secos / discoteca)
    AudioReactionModeBeat = 1,    // 🥁 Ritmo / Bajo (Beat Pulse con caída suave)
    AudioReactionModeRMS = 2,     // 🌊 Volumen Fluido (Smooth RMS continuo)
    AudioReactionModeHybrid = 3   // 💫 Híbrido (Base ambiente + destello en beats)
};

@interface AudioAnalyzer : NSObject

@property (nonatomic, assign) AudioReactionMode mode;
@property (nonatomic, assign) float sensitivity;         // 0.2 .. 5.0 (default: 1.8)
@property (nonatomic, assign) float minBrightness;       // 0.0 .. 1.0 (default: 0.0)
@property (nonatomic, assign) float maxBrightness;       // 0.0 .. 1.0 (default: 1.0)
@property (nonatomic, assign) float decaySpeed;          // 0.01 .. 0.5 (default: 0.20)
@property (nonatomic, assign) float noiseGate;           // 0.001 .. 0.05 (default: 0.008)
@property (nonatomic, assign) NSTimeInterval flashDuration; // Duración del flash (0.02s .. 0.10s, default: 0.04s)

// Output states for UI VU meter and lighting
@property (nonatomic, readonly) float currentAudioLevel;  // 0.0 .. 1.0
@property (nonatomic, readonly) float targetBrightness;   // 0.0 .. 1.0
@property (nonatomic, readonly) BOOL isBeatDetected;
@property (nonatomic, readonly) NSTimeInterval flashEndTime;

+ (instancetype)sharedAnalyzer;

- (void)reset;
- (float)processAudioSamples:(const float *)samples count:(NSUInteger)count sampleRate:(double)sampleRate;
- (float)forceCheckTimeout;

@end

NS_ASSUME_NONNULL_END
