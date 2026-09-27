#import <UIKit/UIKit.h>

@class SpeechCoach;

NS_ASSUME_NONNULL_BEGIN

@interface CoachViewController : UIViewController

- (instancetype)initWithSpeechCoach:(SpeechCoach *)speechCoach;
- (void)configureWithItemIdentifier:(NSString *)itemIdentifier title:(NSString *)title;
- (void)resetToFirstStep;

@end

NS_ASSUME_NONNULL_END
