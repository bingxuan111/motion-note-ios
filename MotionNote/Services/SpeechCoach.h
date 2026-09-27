#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SpeechCoach : NSObject

@property (nonatomic, copy, nullable) void (^progressHandler)(float progress);
@property (nonatomic, copy, nullable) void (^completionHandler)(void);
@property (nonatomic, assign, readonly, getter=isSpeaking) BOOL speaking;

- (void)speakText:(NSString *)text;
- (void)speakText:(NSString *)text fromProgress:(float)progress;
- (void)seekToProgress:(float)progress;
- (void)stopSpeaking;

@end

NS_ASSUME_NONNULL_END
