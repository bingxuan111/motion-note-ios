#import "HealthService.h"
#import <HealthKit/HealthKit.h>

@interface HealthService ()
@property (nonatomic, copy, readwrite) NSString *status;
@property (nonatomic, strong, readwrite, nullable) NSNumber *todayActiveEnergy;
@property (nonatomic, strong, readwrite, nullable) NSNumber *todaySteps;
@property (nonatomic, assign, readwrite) NSInteger recentWorkouts;
@property (nonatomic, strong) HKHealthStore *store;
@end

@implementation HealthService

- (instancetype)init {
    self = [super init];
    if (self) {
        _status = @"尚未连接 Apple 健康";
        _store = [[HKHealthStore alloc] init];
    }
    return self;
}

- (void)requestAuthorizationWithCompletion:(void (^)(void))completion {
    if (![HKHealthStore isHealthDataAvailable]) {
        self.status = @"此设备不支持 Apple 健康";
        completion();
        return;
    }

    NSSet<HKObjectType *> *readTypes = [NSSet setWithArray:@[
        [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned],
        [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate],
        [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount],
        HKWorkoutType.workoutType,
    ]];
    __weak typeof(self) weakSelf = self;
    [self.store requestAuthorizationToShareTypes:[NSSet set]
                                      readTypes:readTypes
                                     completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf;
            if (!self) return;
            if (!success || error) {
                self.status = @"授权未完成，请稍后重试";
                completion();
                return;
            }
            [self refreshTodayWithCompletion:^{
                self.status = @"已连接 Apple 健康";
                completion();
            }];
        });
    }];
}

- (void)refreshTodayWithCompletion:(void (^)(void))completion {
    if (![HKHealthStore isHealthDataAvailable]) {
        completion();
        return;
    }

    NSDate *start = [NSCalendar.currentCalendar startOfDayForDate:NSDate.date];
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:start endDate:NSDate.date options:HKQueryOptionNone];
    dispatch_group_t group = dispatch_group_create();
    __block BOOL failed = NO;

    dispatch_group_enter(group);
    [self querySumForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned
                          unit:HKUnit.kilocalorieUnit
                     predicate:predicate
                    completion:^(NSNumber *value, NSError *error) {
        self.todayActiveEnergy = value;
        failed = failed || error != nil;
        dispatch_group_leave(group);
    }];

    dispatch_group_enter(group);
    [self querySumForIdentifier:HKQuantityTypeIdentifierStepCount
                          unit:HKUnit.countUnit
                     predicate:predicate
                    completion:^(NSNumber *value, NSError *error) {
        self.todaySteps = value;
        failed = failed || error != nil;
        dispatch_group_leave(group);
    }];

    dispatch_group_enter(group);
    [self queryWorkoutCountWithPredicate:predicate completion:^(NSInteger count, NSError *error) {
        self.recentWorkouts = count;
        failed = failed || error != nil;
        dispatch_group_leave(group);
    }];

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (failed) {
            self.status = @"无法读取数据，请在健康 App 中检查授权";
        }
        completion();
    });
}

- (void)querySumForIdentifier:(HKQuantityTypeIdentifier)identifier
                         unit:(HKUnit *)unit
                    predicate:(NSPredicate *)predicate
                   completion:(void (^)(NSNumber * _Nullable, NSError * _Nullable))completion {
    HKQuantityType *type = [HKQuantityType quantityTypeForIdentifier:identifier];
    HKStatisticsQuery *query = [[HKStatisticsQuery alloc]
        initWithQuantityType:type
        quantitySamplePredicate:predicate
        options:HKStatisticsOptionCumulativeSum
        completionHandler:^(HKStatisticsQuery *query, HKStatistics *result, NSError *error) {
            double value = [[result sumQuantity] doubleValueForUnit:unit];
            completion(error ? nil : @(value), error);
        }];
    [self.store executeQuery:query];
}

- (void)queryWorkoutCountWithPredicate:(NSPredicate *)predicate
                             completion:(void (^)(NSInteger, NSError * _Nullable))completion {
    HKSampleQuery *query = [[HKSampleQuery alloc]
        initWithSampleType:HKWorkoutType.workoutType
        predicate:predicate
        limit:HKObjectQueryNoLimit
        sortDescriptors:nil
        resultsHandler:^(HKSampleQuery *query, NSArray<__kindof HKSample *> *results, NSError *error) {
            completion(results.count, error);
        }];
    [self.store executeQuery:query];
}

@end
