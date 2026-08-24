#import <Foundation/Foundation.h>
#import "Models.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const MotionNoteFeishuCallbackNotification;
FOUNDATION_EXPORT NSNotificationName const MotionNoteFeishuStatusDidChangeNotification;

@interface FeishuService : NSObject

@property (nonatomic, copy, readonly) NSString *appID;
@property (nonatomic, copy, readonly) NSString *status;
@property (nonatomic, copy) NSString *gatewayURL;
@property (nonatomic, copy) NSString *planSyncURL;
@property (nonatomic, copy) NSString *planSyncKey;
@property (nonatomic, assign, readonly) BOOL planSyncConfigured;

- (void)openAuthorization;
- (void)syncWeeklyPlansWithCompletion:(void (^)(NSArray<ImportedPlan *> * _Nullable plans, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
