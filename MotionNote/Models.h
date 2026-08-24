#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WorkoutPhase) {
    WorkoutPhaseWarmup,
    WorkoutPhaseTraining,
    WorkoutPhaseCooldown,
};

@interface WorkoutStep : NSObject

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, assign, readonly) WorkoutPhase phase;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSString *prescription;
@property (nonatomic, copy, readonly) NSString *cue;
@property (nonatomic, assign, readonly) NSInteger minutes;
@property (nonatomic, copy, readonly) NSString *phaseName;

- (instancetype)initWithPhase:(WorkoutPhase)phase
                         name:(NSString *)name
                 prescription:(NSString *)prescription
                          cue:(NSString *)cue
                      minutes:(NSInteger)minutes;

@end

@interface WorkoutStore : NSObject

@property (nonatomic, copy) NSString *goal;
@property (nonatomic, assign) NSInteger minutes;
@property (nonatomic, copy) NSString *coachingNotes;
@property (nonatomic, copy) NSString *coachingSourceURL;
@property (nonatomic, copy) NSString *latestCoachSummary;
@property (nonatomic, assign) double effort;
@property (nonatomic, copy) NSString *discomfort;
@property (nonatomic, copy, readonly) NSArray<WorkoutStep *> *steps;
@property (nonatomic, assign, readonly) NSInteger totalMinutes;

- (void)importCoachingNotes:(NSString *)text sourceURL:(NSString *)sourceURL;

@end

@interface ImportedPlan : MTLModel <MTLJSONSerializing>

@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *rawContent;
@property (nonatomic, copy, readonly) NSString *sourceURL;
@property (nonatomic, strong, readonly) NSDate *importedAt;
@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *preview;

- (nullable NSDictionary *)JSONDictionaryWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
