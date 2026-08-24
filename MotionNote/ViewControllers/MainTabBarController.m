#import "MainTabBarController.h"
#import "CoachViewController.h"
#import "FeishuService.h"
#import "HealthService.h"
#import "PlanViewController.h"
#import "RecordViewController.h"
#import "SpeechCoach.h"

@interface MainTabBarController ()
@property (nonatomic, strong) WorkoutStore *store;
@property (nonatomic, strong) HealthService *healthService;
@property (nonatomic, strong) SpeechCoach *speechCoach;
@property (nonatomic, strong) FeishuService *feishuService;
@property (nonatomic, strong) PlanViewController *planController;
@property (nonatomic, strong) CoachViewController *coachController;
@property (nonatomic, strong) RecordViewController *recordController;
@property (nonatomic, copy) NSArray<ImportedPlan *> *weeklyPlans;
@property (nonatomic, copy) NSString *activeWeeklyPlanID;
@property (nonatomic, assign) BOOL syncingPlans;
@property (nonatomic, assign) BOOL performedInitialSync;
@end

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.store = [[WorkoutStore alloc] init];
    self.healthService = [[HealthService alloc] init];
    self.speechCoach = [[SpeechCoach alloc] init];
    self.feishuService = [[FeishuService alloc] init];
    self.weeklyPlans = @[];
    self.activeWeeklyPlanID = [NSUserDefaults.standardUserDefaults stringForKey:@"activeWeeklyPlanID"] ?: @"";

    self.planController = [[PlanViewController alloc] initWithWorkoutStore:self.store];
    self.coachController = [[CoachViewController alloc] initWithWorkoutStore:self.store speechCoach:self.speechCoach];
    self.recordController = [[RecordViewController alloc] initWithWorkoutStore:self.store healthService:self.healthService feishuService:self.feishuService];

    __weak typeof(self) weakSelf = self;
    self.planController.startWorkoutHandler = ^{ weakSelf.selectedIndex = 1; };
    self.planController.planSelectionHandler = ^(ImportedPlan *plan) { [weakSelf selectPlan:plan]; };
    self.recordController.planSelectionHandler = ^(ImportedPlan *plan) { [weakSelf selectPlan:plan]; };
    self.recordController.syncPlansHandler = ^{ [weakSelf synchronizePlansSilently:NO]; };

    UINavigationController *planNavigation = [[UINavigationController alloc] initWithRootViewController:self.planController];
    UINavigationController *coachNavigation = [[UINavigationController alloc] initWithRootViewController:self.coachController];
    UINavigationController *recordNavigation = [[UINavigationController alloc] initWithRootViewController:self.recordController];
    planNavigation.tabBarItem = self.planController.tabBarItem;
    coachNavigation.tabBarItem = self.coachController.tabBarItem;
    recordNavigation.tabBarItem = self.recordController.tabBarItem;
    self.viewControllers = @[planNavigation, coachNavigation, recordNavigation];
    self.tabBar.tintColor = [UIColor colorWithRed:0.14 green:0.33 blue:0.23 alpha:1.0];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.performedInitialSync) {
        self.performedInitialSync = YES;
        [self synchronizePlansSilently:YES];
    }
}

- (void)applicationDidBecomeActive {
    if (self.performedInitialSync) [self synchronizePlansSilently:YES];
}

- (void)synchronizePlansSilently:(BOOL)silently {
    if (self.syncingPlans) return;
    if (!self.feishuService.planSyncConfigured) {
        if (!silently) [self.recordController showImportMessage:@"请先完成飞书计划同步配置。"];
        return;
    }
    self.syncingPlans = YES;
    [self.recordController setSyncing:YES];
    __weak typeof(self) weakSelf = self;
    [self.feishuService syncWeeklyPlansWithCompletion:^(NSArray<ImportedPlan *> *plans, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf;
            if (!self) return;
            self.syncingPlans = NO;
            [self.recordController setSyncing:NO];
            if (error) {
                if (!silently) [self.recordController showImportMessage:error.localizedDescription];
                return;
            }
            self.weeklyPlans = plans ?: @[];
            ImportedPlan *selected = nil;
            for (ImportedPlan *plan in self.weeklyPlans) {
                if ([plan.identifier isEqualToString:self.activeWeeklyPlanID]) {
                    selected = plan;
                    break;
                }
            }
            selected = selected ?: self.weeklyPlans.firstObject;
            if (selected) [self selectPlan:selected];
            [self updatePlanDisplays];
            if (!silently) {
                NSUInteger index = [self.weeklyPlans indexOfObject:selected];
                NSString *message = [NSString stringWithFormat:@"已同步本周 %lu 节私教课；当前使用第 %lu 练。", (unsigned long)self.weeklyPlans.count, (unsigned long)index + 1];
                [self.recordController showImportMessage:message];
            }
        });
    }];
}

- (void)selectPlan:(ImportedPlan *)plan {
    BOOL changed = ![self.activeWeeklyPlanID isEqualToString:plan.identifier];
    self.activeWeeklyPlanID = plan.identifier;
    [NSUserDefaults.standardUserDefaults setObject:self.activeWeeklyPlanID forKey:@"activeWeeklyPlanID"];
    NSError *serializationError = nil;
    NSDictionary *planJSON = [plan JSONDictionaryWithError:&serializationError];
    if (planJSON && !serializationError) {
        [NSUserDefaults.standardUserDefaults setObject:planJSON forKey:@"activeWeeklyPlanJSON"];
    }
    [self.store importCoachingNotes:plan.rawContent sourceURL:plan.sourceURL];
    if (changed) [self.coachController resetToFirstStep];
    [self updatePlanDisplays];
}

- (void)updatePlanDisplays {
    self.planController.weeklyPlans = self.weeklyPlans;
    self.planController.activeWeeklyPlanID = self.activeWeeklyPlanID;
    self.recordController.weeklyPlans = self.weeklyPlans;
    self.recordController.activeWeeklyPlanID = self.activeWeeklyPlanID;
    [self.recordController refreshDisplayedData];
}

@end
