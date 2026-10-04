//
//  KeyboardController.h
//  keyboard light mac
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KeyboardController : NSObject

@property (nonatomic, readonly) BOOL isAvailable;
@property (nonatomic, readonly) float originalBrightness;
@property (nonatomic, readonly) float currentBrightness;
@property (nonatomic, readonly) BOOL originalAutoBrightness;

+ (instancetype)sharedController;

- (BOOL)setBrightness:(float)brightness;
- (BOOL)fadeToBrightness:(float)brightness duration:(NSTimeInterval)duration;
- (void)turnOff;
- (void)restoreOriginalBrightness;

@end

NS_ASSUME_NONNULL_END
