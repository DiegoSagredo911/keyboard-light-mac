//
//  TypingSpeedometerEngine.h
//  keyboard light mac
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TypingMode) {
    TypingModeKeyStrobe = 0,      // ⚡️ Destello por cada tecla pulsada
    TypingModeSpeedometerRev = 1, // 🏎 Tacómetro progresivo (brillo sube con las WPM)
    TypingModeTurboStrobe = 2     // 🔥 Turbo (parpadeo rápido al escribir a gran velocidad)
};

@protocol TypingSpeedometerDelegate <NSObject>
@optional
- (void)typingSpeedometerDidUpdateWPM:(float)wpm cps:(float)cps brightness:(float)brightness isKeyStroke:(BOOL)isKeyStroke;
- (void)typingSpeedometerPermissionNeeded;
@end

@interface TypingSpeedometerEngine : NSObject

@property (nonatomic, weak) id<TypingSpeedometerDelegate> delegate;
@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, readonly) float currentWPM;
@property (nonatomic, readonly) float currentCPS;
@property (nonatomic, readonly) float normalizedSpeed; // 0.0 .. 1.0
@property (nonatomic, assign) float targetMaxWPM;     // Default: 80 WPM
@property (nonatomic, assign) TypingMode mode;
@property (nonatomic, assign) NSTimeInterval flashDuration; // Duración flash por tecla (ej. 0.04s)

+ (instancetype)sharedEngine;
+ (BOOL)hasAccessibilityPermission;
+ (void)requestAccessibilityPermission;

- (BOOL)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
