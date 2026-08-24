#import <UIKit/UIKit.h>
#import "Models.h"

NS_ASSUME_NONNULL_BEGIN

@interface PlanViewController : UITableViewController

@property (nonatomic, copy) NSArray<ImportedPlan *> *weeklyPlans;
@property (nonatomic, copy) NSString *activeWeeklyPlanID;
@property (nonatomic, copy, nullable) void (^startWorkoutHandler)(void);
@property (nonatomic, copy, nullable) void (^planSelectionHandler)(ImportedPlan *plan);

- (instancetype)initWithWorkoutStore:(WorkoutStore *)store;

@end

NS_ASSUME_NONNULL_END
