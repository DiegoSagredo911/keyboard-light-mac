//
//  AudioCaptureEngine.h
//  keyboard light mac
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudio.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AudioSourceType) {
    AudioSourceTypeMicrophone = 0,
    AudioSourceTypeSystemAudio = 1,
    AudioSourceTypeCustomDevice = 2
};

@interface AudioDeviceInfo : NSObject
@property (nonatomic, assign) AudioDeviceID deviceID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *uid;
@end

@protocol AudioCaptureEngineDelegate <NSObject>
@optional
- (void)audioCaptureDidOutputLevel:(float)level brightness:(float)brightness isBeat:(BOOL)isBeat;
- (void)audioCaptureDidFailWithError:(NSString *)errorMessage;
- (void)audioCapturePermissionNeeded:(NSString *)permissionType;
@end

@interface AudioCaptureEngine : NSObject

@property (nonatomic, weak) id<AudioCaptureEngineDelegate> delegate;
@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, assign) AudioSourceType sourceType;
@property (nonatomic, assign) AudioDeviceID selectedDeviceID;

+ (instancetype)sharedEngine;

+ (NSArray<AudioDeviceInfo *> *)availableInputDevices;
+ (BOOL)hasScreenCapturePermission;
+ (void)requestScreenCapturePermission;

- (BOOL)start;
- (void)stop;
- (void)setSourceType:(AudioSourceType)type deviceID:(AudioDeviceID)devID;

@end

NS_ASSUME_NONNULL_END
