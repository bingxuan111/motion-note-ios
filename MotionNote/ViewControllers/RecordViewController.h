#import <UIKit/UIKit.h>
#import "Models.h"

@class WorkoutStore;
@class HealthService;
@class FeishuService;

NS_ASSUME_NONNULL_BEGIN

@interface RecordViewController : UIViewController

@property (nonatomic, copy) NSArray<ImportedPlan *> *weeklyPlans;
@property (nonatomic, copy) NSString *activeWeeklyPlanID;
@property (nonatomic, copy, nullable) void (^syncPlansHandler)(void);
@property (nonatomic, copy, nullable) void (^planSelectionHandler)(ImportedPlan *plan);

- (instancetype)initWithWorkoutStore:(WorkoutStore *)store
                       healthService:(HealthService *)healthService
                        feishuService:(FeishuService *)feishuService;
- (void)setSyncing:(BOOL)syncing;
- (void)showImportMessage:(NSString *)message;
- (void)refreshDisplayedData;

@end

NS_ASSUME_NONNULL_END
