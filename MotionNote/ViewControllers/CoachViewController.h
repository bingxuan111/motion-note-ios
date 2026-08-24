#import <UIKit/UIKit.h>

@class WorkoutStore;
@class SpeechCoach;

NS_ASSUME_NONNULL_BEGIN

@interface CoachViewController : UIViewController

- (instancetype)initWithWorkoutStore:(WorkoutStore *)store speechCoach:(SpeechCoach *)speechCoach;
- (void)resetToFirstStep;

@end

NS_ASSUME_NONNULL_END
