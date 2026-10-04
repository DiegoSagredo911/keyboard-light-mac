//
//  AppController.h
//  keyboard light mac
//

#import <Cocoa/Cocoa.h>
#import "AudioCaptureEngine.h"
#import "TypingSpeedometerEngine.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppController : NSObject <NSApplicationDelegate, AudioCaptureEngineDelegate, TypingSpeedometerDelegate>

- (void)startCLIWithSource:(NSString *)source sensitivity:(float)sensitivity mode:(NSInteger)mode;

@end

NS_ASSUME_NONNULL_END
