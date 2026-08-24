#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HealthService : NSObject

@property (nonatomic, copy, readonly) NSString *status;
@property (nonatomic, strong, readonly, nullable) NSNumber *todayActiveEnergy;
@property (nonatomic, strong, readonly, nullable) NSNumber *todaySteps;
@property (nonatomic, assign, readonly) NSInteger recentWorkouts;

- (void)requestAuthorizationWithCompletion:(void (^)(void))completion;
- (void)refreshTodayWithCompletion:(void (^)(void))completion;

@end

NS_ASSUME_NONNULL_END
