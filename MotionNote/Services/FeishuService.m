#import "FeishuService.h"
#import <UIKit/UIKit.h>
#import <AFNetworking/AFNetworking.h>
#import <Mantle/Mantle.h>

NSNotificationName const MotionNoteFeishuCallbackNotification = @"MotionNoteFeishuCallbackNotification";
NSNotificationName const MotionNoteFeishuStatusDidChangeNotification = @"MotionNoteFeishuStatusDidChangeNotification";

static NSString * const MotionNotePlanSyncErrorDomain = @"com.motionnote.plansync";

typedef NS_ENUM(NSInteger, MotionNotePlanSyncErrorCode) {
    MotionNotePlanSyncErrorInvalidURL = 1,
    MotionNotePlanSyncErrorMissingKey,
    MotionNotePlanSyncErrorInvalidResponse,
    MotionNotePlanSyncErrorNoPlan,
    MotionNotePlanSyncErrorServerStatus,
};

@interface FeishuService ()
@property (nonatomic, copy, readwrite) NSString *status;
@end

@implementation FeishuService

- (instancetype)init {
    self = [super init];
    if (self) {
        _appID = @"cli_aaf6d50ac2f95be2";
        _status = @"尚未连接飞书";
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        _gatewayURL = [defaults stringForKey:@"feishuGatewayURL"] ?: @"";
        _planSyncURL = [defaults stringForKey:@"planSyncURL"] ?: @"";
        _planSyncKey = [defaults stringForKey:@"planSyncKey"] ?: @"";
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleCallbackNotification:)
                                                     name:MotionNoteFeishuCallbackNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setGatewayURL:(NSString *)gatewayURL {
    _gatewayURL = [gatewayURL copy];
    [NSUserDefaults.standardUserDefaults setObject:_gatewayURL forKey:@"feishuGatewayURL"];
}

- (void)setPlanSyncURL:(NSString *)planSyncURL {
    _planSyncURL = [planSyncURL copy];
    [NSUserDefaults.standardUserDefaults setObject:_planSyncURL forKey:@"planSyncURL"];
}

- (void)setPlanSyncKey:(NSString *)planSyncKey {
    _planSyncKey = [planSyncKey copy];
    [NSUserDefaults.standardUserDefaults setObject:_planSyncKey forKey:@"planSyncKey"];
}

- (BOOL)planSyncConfigured {
    return [self normalizedHTTPSURLString:self.planSyncURL] != nil &&
        [self.planSyncKey stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length > 0;
}

- (void)openAuthorization {
    NSString *gateway = [self normalizedHTTPSURLString:self.gatewayURL];
    if (!gateway) {
        [self updateStatus:@"请先填入本机隧道的 HTTPS 地址"];
        return;
    }
    NSURL *url = [NSURL URLWithString:[gateway stringByAppendingString:@"/api/feishu/start"]];
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
    [self updateStatus:@"已打开飞书授权页面"];
}

- (void)syncWeeklyPlansWithCompletion:(void (^)(NSArray<ImportedPlan *> * _Nullable, NSError * _Nullable))completion {
    NSString *base = [self normalizedHTTPSURLString:self.planSyncURL];
    if (!base) {
        completion(nil, [self errorWithCode:MotionNotePlanSyncErrorInvalidURL message:@"请先填入 Railway 的 HTTPS 服务地址"]);
        return;
    }
    NSString *key = [self.planSyncKey stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (key.length == 0) {
        completion(nil, [self errorWithCode:MotionNotePlanSyncErrorMissingKey message:@"请先填入计划同步密钥"]);
        return;
    }

    NSURL *url = [[NSURL URLWithString:base] URLByAppendingPathComponent:@"api/plans"];
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer.timeoutInterval = 15;
    [manager.requestSerializer setValue:key forHTTPHeaderField:@"X-MotionNote-Key"];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    __weak typeof(self) weakSelf = self;
    [manager GET:url.absoluteString
      parameters:nil
         headers:nil
        progress:nil
         success:^(NSURLSessionDataTask *task, id responseObject) {
        typeof(self) self = weakSelf;
        if (!self || ![responseObject isKindOfClass:NSDictionary.class]) {
            completion(nil, [self errorWithCode:MotionNotePlanSyncErrorInvalidResponse message:@"计划服务返回异常"]);
            return;
        }
        NSArray *payload = [responseObject[@"plans"] isKindOfClass:NSArray.class] ? responseObject[@"plans"] : nil;
        if (!payload) {
            completion(nil, [self errorWithCode:MotionNotePlanSyncErrorInvalidResponse message:@"计划服务返回异常"]);
            return;
        }
        NSError *mappingError = nil;
        NSArray<ImportedPlan *> *plans = [MTLJSONAdapter modelsOfClass:ImportedPlan.class
                                                         fromJSONArray:payload
                                                                 error:&mappingError];
        if (mappingError || !plans) {
            completion(nil, mappingError ?: [self errorWithCode:MotionNotePlanSyncErrorInvalidResponse message:@"计划服务返回异常"]);
            return;
        }
        if (plans.count == 0) {
            completion(nil, [self errorWithCode:MotionNotePlanSyncErrorNoPlan message:@"飞书里还没有可同步的训练计划"]);
            return;
        }
        NSRange range = NSMakeRange(MAX((NSInteger)plans.count - 2, 0), MIN(plans.count, 2));
        completion([plans subarrayWithRange:range], nil);
    }
         failure:^(NSURLSessionDataTask *task, NSError *requestError) {
        NSInteger statusCode = [(NSHTTPURLResponse *)task.response statusCode];
        if (statusCode > 0) {
            NSString *message = [NSString stringWithFormat:@"计划服务暂时不可用（HTTP %ld）", (long)statusCode];
            completion(nil, [weakSelf errorWithCode:MotionNotePlanSyncErrorServerStatus message:message]);
        } else {
            completion(nil, requestError);
        }
    }];
}

- (void)handleCallbackNotification:(NSNotification *)notification {
    NSURL *url = [notification.object isKindOfClass:NSURL.class] ? notification.object : nil;
    if (![url.scheme isEqualToString:@"motionnote"] || ![url.host isEqualToString:@"feishu-connected"]) return;
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    BOOL success = NO;
    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"success"] && [item.value isEqualToString:@"1"]) {
            success = YES;
            break;
        }
    }
    [self updateStatus:success ? @"飞书已连接，可继续导入文档" : @"飞书授权未完成，请重试"];
}

- (nullable NSString *)normalizedHTTPSURLString:(NSString *)value {
    NSString *trimmed = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSURLComponents *components = [NSURLComponents componentsWithString:trimmed];
    if (![components.scheme.lowercaseString isEqualToString:@"https"] || components.host.length == 0) return nil;
    while ([components.path hasSuffix:@"/"] && components.path.length > 0) {
        components.path = [components.path substringToIndex:components.path.length - 1];
    }
    return components.URL.absoluteString;
}

- (NSError *)errorWithCode:(MotionNotePlanSyncErrorCode)code message:(NSString *)message {
    return [NSError errorWithDomain:MotionNotePlanSyncErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

- (void)updateStatus:(NSString *)status {
    self.status = status;
    [[NSNotificationCenter defaultCenter] postNotificationName:MotionNoteFeishuStatusDidChangeNotification object:self];
}

@end
