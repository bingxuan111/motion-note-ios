#import <Foundation/Foundation.h>

@class WorkoutStep;

NS_ASSUME_NONNULL_BEGIN

@interface SpeechCoach : NSObject

- (void)speakStep:(WorkoutStep *)step;

@end

NS_ASSUME_NONNULL_END
