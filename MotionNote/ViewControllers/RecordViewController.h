#import <UIKit/UIKit.h>
#import "Models.h"

@class WorkoutStore;
@class HealthService;
@class FeishuService;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const IPAdress;
FOUNDATION_EXPORT NSString * const appSyncSecret;

@interface RecordViewController : UIViewController

@property (nonatomic, copy) NSArray<ImportedPlan *> *weeklyPlans;
@property (nonatomic, copy) NSString *activeWeeklyPlanID;
@property (nonatomic, copy, nullable) void (^syncPlansHandler)(void);
@property (nonatomic, copy, nullable) void (^planSelectionHandler)(ImportedPlan *plan);
@property (nonatomic, copy, nullable) void (^openVoiceCoachHandler)(NSString *itemIdentifier, NSString *title);

- (instancetype)initWithWorkoutStore:(WorkoutStore *)store
                       healthService:(HealthService *)healthService
                        feishuService:(FeishuService *)feishuService;
- (void)setSyncing:(BOOL)syncing;
- (void)showImportMessage:(NSString *)message;
- (void)refreshDisplayedData;

@end

NS_ASSUME_NONNULL_END
