#import "Models.h"

@implementation WorkoutStep

- (instancetype)initWithPhase:(WorkoutPhase)phase
                         name:(NSString *)name
                 prescription:(NSString *)prescription
                          cue:(NSString *)cue
                      minutes:(NSInteger)minutes {
    self = [super init];
    if (self) {
        _identifier = NSUUID.UUID.UUIDString;
        _phase = phase;
        _name = [name copy];
        _prescription = [prescription copy];
        _cue = [cue copy];
        _minutes = minutes;
    }
    return self;
}

- (NSString *)phaseName {
    switch (self.phase) {
        case WorkoutPhaseWarmup: return @"热身";
        case WorkoutPhaseTraining: return @"正式训练";
        case WorkoutPhaseCooldown: return @"拉伸";
    }
}

@end

@implementation WorkoutStore

- (instancetype)init {
    self = [super init];
    if (self) {
        _goal = @"全身力量";
        _minutes = 45;
        _coachingNotes = @"";
        _coachingSourceURL = @"";
        _latestCoachSummary = @"";
        _effort = 6.0;
        _discomfort = @"";
        _steps = @[
            [[WorkoutStep alloc] initWithPhase:WorkoutPhaseWarmup name:@"快走或单车" prescription:@"5 分钟，轻微出汗即可" cue:@"保持能说完整句子的强度。" minutes:5],
            [[WorkoutStep alloc] initWithPhase:WorkoutPhaseWarmup name:@"髋部与踝关节活动" prescription:@"各 8 次，做 2 轮" cue:@"动作慢一些，先找活动范围。" minutes:5],
            [[WorkoutStep alloc] initWithPhase:WorkoutPhaseTraining name:@"高脚杯深蹲" prescription:@"3 组 × 10 次，组间休息 75 秒" cue:@"膝盖朝脚尖方向，核心收紧；出现疼痛立即停止。" minutes:12],
            [[WorkoutStep alloc] initWithPhase:WorkoutPhaseTraining name:@"哑铃罗马尼亚硬拉" prescription:@"3 组 × 10 次，组间休息 75 秒" cue:@"臀部向后送，背部保持中立。" minutes:12],
            [[WorkoutStep alloc] initWithPhase:WorkoutPhaseTraining name:@"坐姿划船" prescription:@"3 组 × 12 次，组间休息 60 秒" cue:@"先沉肩再拉肘，避免耸肩。" minutes:8],
            [[WorkoutStep alloc] initWithPhase:WorkoutPhaseCooldown name:@"臀肌、髋屈肌与胸椎拉伸" prescription:@"每侧 30 秒，做 2 轮" cue:@"只拉到轻微紧张，不要弹震或屏气。" minutes:8],
        ];
    }
    return self;
}

- (NSInteger)totalMinutes {
    NSInteger result = 0;
    for (WorkoutStep *step in self.steps) {
        result += step.minutes;
    }
    return result;
}

- (void)importCoachingNotes:(NSString *)text sourceURL:(NSString *)sourceURL {
    NSCharacterSet *whitespace = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    self.coachingNotes = [text stringByTrimmingCharactersInSet:whitespace];
    self.coachingSourceURL = [sourceURL stringByTrimmingCharactersInSet:whitespace];

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [self.coachingNotes enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        NSString *cleanLine = [line stringByTrimmingCharactersInSet:whitespace];
        if (cleanLine.length > 0 && lines.count < 4) {
            [lines addObject:cleanLine];
        }
    }];
    self.latestCoachSummary = [lines componentsJoinedByString:@"\n"];
}

@end

@implementation ImportedPlan

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{
        @"title": @"title",
        @"rawContent": @"raw_content",
        @"sourceURL": @"source_url",
        @"importedAt": @"imported_at",
    };
}

+ (NSValueTransformer *)importedAtJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(NSString *dateString, BOOL *success, NSError **error) {
        if (![dateString isKindOfClass:NSString.class]) {
            if (success) *success = NO;
            return nil;
        }
        NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
        NSDate *date = [formatter dateFromString:dateString];
        if (!date) {
            formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
            date = [formatter dateFromString:dateString];
        }
        if (success) *success = date != nil;
        return date;
    } reverseBlock:^id(NSDate *date, BOOL *success, NSError **error) {
        if (![date isKindOfClass:NSDate.class]) {
            if (success) *success = NO;
            return nil;
        }
        NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
        return [formatter stringFromDate:date];
    }];
}

- (NSString *)identifier {
    return [NSString stringWithFormat:@"%@|%.0f", self.sourceURL, self.importedAt.timeIntervalSince1970];
}

- (NSDictionary *)JSONDictionaryWithError:(NSError **)error {
    return [MTLJSONAdapter JSONDictionaryFromModel:self error:error];
}

- (NSString *)preview {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [self.rawContent enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        NSString *cleanLine = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (cleanLine.length > 0 && lines.count < 2) {
            [lines addObject:cleanLine];
        }
    }];
    return [lines componentsJoinedByString:@" · "];
}

@end
