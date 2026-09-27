#import "CoachViewController.h"
#import "RecordViewController.h"
#import "Models.h"
#import "SpeechCoach.h"
#import <AFNetworking/AFNetworking.h>
#import <Mantle/Mantle.h>
#import <Masonry/Masonry.h>

static NSString * const apiLatestPlanPreWorkout = @"/api/latest-plan/pre_workout";
static NSString * const apiLatestPlanTrainItem = @"/api/latest-plan/train_item";
static NSString * const apiLatestPlanPostWorkoutStretch = @"/api/latest-plan/post_workout_stretch";

typedef NS_ENUM(NSInteger, CoachStage) {
    CoachStageWaiting,
    CoachStagePreWorkout,
    CoachStageTraining,
    CoachStagePostWorkout,
};

@interface CoachViewController ()
@property (nonatomic, strong) SpeechCoach *speechCoach;
@property (nonatomic, copy) NSString *itemIdentifier;
@property (nonatomic, copy) NSString *planTitle;
@property (nonatomic, assign) NSInteger currentStep;
@property (nonatomic, assign) CoachStage stage;
@property (nonatomic, assign) BOOL hasCurrentContent;
@property (nonatomic, copy) NSString *currentSpeechText;
@property (nonatomic, assign) BOOL voiceGuidanceEnabled;
@property (nonatomic, assign) BOOL speechPlaying;
@property (nonatomic, assign) BOOL speechCompleted;
@property (nonatomic, assign) BOOL scrubbingSpeechProgress;
@property (nonatomic, assign) BOOL acceptsSpeechProgressUpdates;
@property (nonatomic, strong) AFHTTPSessionManager *networkManager;
@property (nonatomic, strong) NSURLSessionDataTask *requestTask;
@property (nonatomic, assign) NSUInteger requestIdentifier;
@property (nonatomic, strong) UILabel *planTitleLabel;
@property (nonatomic, strong) UILabel *stageTitleLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIButton *speakButton;
@property (nonatomic, strong) UISlider *speechProgressSlider;
@property (nonatomic, strong) UILabel *speechProgressLabel;
@property (nonatomic, strong) UIButton *nextButton;
@end

@implementation CoachViewController

- (instancetype)initWithSpeechCoach:(SpeechCoach *)speechCoach {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _speechCoach = speechCoach;
        _itemIdentifier = @"";
        _planTitle = @"";
        _currentSpeechText = @"";
        _stage = CoachStageWaiting;
        _voiceGuidanceEnabled = NO;
        _speechPlaying = NO;
        _speechCompleted = NO;
        self.title = @"语音教练";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"语音教练"
                                                       image:[UIImage systemImageNamed:@"waveform"]
                                                         tag:1];
    }
    return self;
}

- (void)dealloc {
    [_requestTask cancel];
    [_networkManager invalidateSessionCancelingTasks:YES resetSession:NO];
    [_speechCoach stopSpeaking];
    _speechCoach.progressHandler = nil;
    _speechCoach.completionHandler = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    [self buildInterface];
    [self observeSpeechCoach];
    [self updatePlanTitle];
    if (self.itemIdentifier.length > 0) [self loadPreWorkout];
    else [self renderMissingPlan];
}

- (void)configureWithItemIdentifier:(NSString *)itemIdentifier title:(NSString *)title {
    [self resetVoiceGuidance];
    self.itemIdentifier = [itemIdentifier stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    self.planTitle = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    self.currentStep = 0;
    self.stage = CoachStagePreWorkout;
    self.hasCurrentContent = NO;
    self.currentSpeechText = @"";
    self.requestIdentifier += 1;
    [self.requestTask cancel];
    self.requestTask = nil;
    if (self.isViewLoaded) {
        [self updatePlanTitle];
        if (self.itemIdentifier.length > 0) [self loadPreWorkout];
        else [self renderMissingPlan];
    }
}

- (void)resetToFirstStep {
    [self resetVoiceGuidance];
    self.currentStep = 0;
    self.stage = self.itemIdentifier.length > 0 ? CoachStagePreWorkout : CoachStageWaiting;
    self.hasCurrentContent = NO;
    if (self.isViewLoaded) {
        if (self.itemIdentifier.length > 0) [self loadPreWorkout];
        else [self renderMissingPlan];
    }
}

#pragma mark - Interface

- (void)buildInterface {
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:scrollView];
    [scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];

    UIStackView *rootStack = [[UIStackView alloc] init];
    rootStack.axis = UILayoutConstraintAxisVertical;
    rootStack.spacing = 18;
    [scrollView addSubview:rootStack];
    [rootStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(scrollView).insets(UIEdgeInsetsMake(18, 18, 28, 18));
        make.width.equalTo(scrollView).offset(-36);
    }];

    [rootStack addArrangedSubview:[self planHeaderView]];

    self.stageTitleLabel = [self labelWithStyle:UIFontTextStyleLargeTitle color:UIColor.labelColor];
    self.stageTitleLabel.font = [UIFont systemFontOfSize:32 weight:UIFontWeightBold];
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.statusLabel = [self labelWithStyle:UIFontTextStyleFootnote color:UIColor.secondaryLabelColor];
    self.statusLabel.hidden = YES;
    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 12;

    UIStackView *stageStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.stageTitleLabel, self.loadingIndicator, self.statusLabel, self.contentStack,
    ]];
    stageStack.axis = UILayoutConstraintAxisVertical;
    stageStack.spacing = 10;
    stageStack.layoutMargins = UIEdgeInsetsMake(18, 18, 18, 18);
    stageStack.layoutMarginsRelativeArrangement = YES;
    stageStack.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    stageStack.layer.cornerRadius = 18;
    [rootStack addArrangedSubview:stageStack];

    self.nextButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *nextConfiguration = [UIButtonConfiguration filledButtonConfiguration];
    nextConfiguration.title = @"下一步";
    nextConfiguration.image = [UIImage systemImageNamed:@"arrow.right.circle.fill"];
    nextConfiguration.imagePlacement = NSDirectionalRectEdgeTrailing;
    nextConfiguration.imagePadding = 8;
    nextConfiguration.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    nextConfiguration.baseBackgroundColor = [UIColor colorWithRed:0.14 green:0.38 blue:0.25 alpha:1.0];
    self.nextButton.configuration = nextConfiguration;
    [self.nextButton addTarget:self action:@selector(goToNextStep) forControlEvents:UIControlEventTouchUpInside];

    self.speakButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *speakConfiguration = [UIButtonConfiguration tintedButtonConfiguration];
    speakConfiguration.title = @"听取语音指导";
    speakConfiguration.image = [UIImage systemImageNamed:@"speaker.wave.2.fill"];
    speakConfiguration.imagePadding = 8;
    speakConfiguration.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    speakConfiguration.baseBackgroundColor = UIColor.systemOrangeColor;
    speakConfiguration.baseForegroundColor = UIColor.systemOrangeColor;
    self.speakButton.configuration = speakConfiguration;
    [self.speakButton addTarget:self action:@selector(speakCurrentContent) forControlEvents:UIControlEventTouchUpInside];

    for (UIButton *button in @[self.nextButton, self.speakButton]) {
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.height.mas_greaterThanOrEqualTo(54);
        }];
    }
    [rootStack addArrangedSubview:self.nextButton];
    [rootStack addArrangedSubview:self.speakButton];
    [rootStack addArrangedSubview:[self speechProgressView]];

    UILabel *warning = [self labelWithStyle:UIFontTextStyleFootnote color:UIColor.secondaryLabelColor];
    warning.text = @"若出现尖锐疼痛、头晕或异常不适，请停止训练并寻求专业建议。";
    warning.textAlignment = NSTextAlignmentCenter;
    warning.backgroundColor = [UIColor.systemOrangeColor colorWithAlphaComponent:0.10];
    warning.layer.cornerRadius = 12;
    warning.layer.masksToBounds = YES;
    [warning mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_greaterThanOrEqualTo(52);
    }];
    [rootStack addArrangedSubview:warning];

    [self setControlsLoading:NO nextEnabled:NO speechEnabled:NO];
    [self updateSpeechButton];
}

- (UIView *)speechProgressView {
    UIColor *accent = UIColor.systemOrangeColor;
    UIImageView *speakerIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"speaker.fill"]];
    speakerIcon.tintColor = accent;
    [speakerIcon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(18);
    }];

    UILabel *titleLabel = [self labelWithStyle:UIFontTextStyleSubheadline color:UIColor.labelColor];
    titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    titleLabel.text = @"语音播放进度";
    self.speechProgressLabel = [self labelWithStyle:UIFontTextStyleFootnote color:UIColor.secondaryLabelColor];
    self.speechProgressLabel.text = @"0%";
    self.speechProgressLabel.textAlignment = NSTextAlignmentRight;

    UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:@[speakerIcon, titleLabel, self.speechProgressLabel]];
    heading.axis = UILayoutConstraintAxisHorizontal;
    heading.spacing = 8;
    heading.alignment = UIStackViewAlignmentCenter;

    self.speechProgressSlider = [[UISlider alloc] init];
    self.speechProgressSlider.minimumValue = 0;
    self.speechProgressSlider.maximumValue = 1;
    self.speechProgressSlider.minimumTrackTintColor = accent;
    self.speechProgressSlider.maximumTrackTintColor = [UIColor.systemGray4Color colorWithAlphaComponent:0.7];
    self.speechProgressSlider.enabled = NO;
    [self.speechProgressSlider addTarget:self action:@selector(speechSliderTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.speechProgressSlider addTarget:self action:@selector(speechSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.speechProgressSlider addTarget:self action:@selector(speechSliderTouchEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];

    UIStackView *container = [[UIStackView alloc] initWithArrangedSubviews:@[heading, self.speechProgressSlider]];
    container.axis = UILayoutConstraintAxisVertical;
    container.spacing = 10;
    container.layoutMargins = UIEdgeInsetsMake(14, 16, 12, 16);
    container.layoutMarginsRelativeArrangement = YES;
    container.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    container.layer.cornerRadius = 16;
    return container;
}

- (UIView *)planHeaderView {
    UIColor *accent = [UIColor colorWithRed:0.14 green:0.38 blue:0.25 alpha:1.0];
    UIView *iconBackground = [[UIView alloc] init];
    iconBackground.backgroundColor = [accent colorWithAlphaComponent:0.14];
    iconBackground.layer.cornerRadius = 14;
    [iconBackground mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(52);
    }];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"waveform.circle.fill"]];
    icon.tintColor = accent;
    [iconBackground addSubview:icon];
    [icon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(iconBackground);
        make.width.height.mas_equalTo(30);
    }];

    UILabel *eyebrow = [self labelWithStyle:UIFontTextStyleCaption1 color:accent];
    eyebrow.text = @"当前训练计划";
    self.planTitleLabel = [self labelWithStyle:UIFontTextStyleTitle2 color:UIColor.labelColor];
    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[eyebrow, self.planTitleLabel]];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 3;

    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[iconBackground, textStack]];
    header.axis = UILayoutConstraintAxisHorizontal;
    header.spacing = 14;
    header.alignment = UIStackViewAlignmentCenter;
    header.layoutMargins = UIEdgeInsetsMake(16, 16, 16, 16);
    header.layoutMarginsRelativeArrangement = YES;
    header.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    header.layer.cornerRadius = 18;
    return header;
}

- (UILabel *)labelWithStyle:(UIFontTextStyle)style color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont preferredFontForTextStyle:style];
    label.textColor = color;
    label.numberOfLines = 0;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (void)updatePlanTitle {
    self.planTitleLabel.text = self.planTitle.length > 0 ? self.planTitle : @"尚未选择训练计划";
}

#pragma mark - Requests

- (AFHTTPSessionManager *)networkManager {
    if (!_networkManager) {
        NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        configuration.URLCache = nil;
        _networkManager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:configuration];
        _networkManager.requestSerializer.timeoutInterval = 15;
        AFJSONResponseSerializer *serializer = [AFJSONResponseSerializer serializer];
        serializer.readingOptions = NSJSONReadingAllowFragments;
        _networkManager.responseSerializer = serializer;
        [_networkManager setTaskWillPerformHTTPRedirectionBlock:^NSURLRequest *(NSURLSession *session, NSURLSessionTask *task, NSURLResponse *response, NSURLRequest *request) {
            return nil;
        }];
    }
    return _networkManager;
}

- (void)loadPreWorkout {
    [self stopSpeechForContentTransition];
    self.stage = CoachStagePreWorkout;
    self.currentStep = 0;
    self.hasCurrentContent = NO;
    [self clearContent];
    [self beginLoadingWithTitle:@"预热" message:@"正在准备预热内容…"];
    NSUInteger requestID = ++self.requestIdentifier;
    __weak typeof(self) weakSelf = self;
    self.requestTask = [self.networkManager GET:[IPAdress stringByAppendingString:apiLatestPlanPreWorkout]
                                    parameters:@{@"itemid": self.itemIdentifier}
                                       headers:@{@"X-MotionNote-Key": appSyncSecret}
                                      progress:nil
                                       success:^(NSURLSessionDataTask *task, id responseObject) {
        typeof(self) self = weakSelf;
        if (!self || requestID != self.requestIdentifier) return;
        self.requestTask = nil;
        if (![responseObject isKindOfClass:NSArray.class]) {
            [self showRequestError:@"预热数据格式不正确"];
            return;
        }
        NSError *mappingError = nil;
        NSArray<PrepareDataModel *> *items = [MTLJSONAdapter modelsOfClass:PrepareDataModel.class
                                                             fromJSONArray:responseObject
                                                                     error:&mappingError];
        if (!items || mappingError) {
            [self showRequestError:@"预热数据解析失败"];
            return;
        }
        [self renderPreWorkoutItems:items];
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        [weakSelf handleRequestFailure:error task:task requestID:requestID fallback:@"预热内容加载失败"];
    }];
}

- (void)loadTrainingStep:(NSInteger)step {
    [self stopSpeechForContentTransition];
    [self beginLoadingWithoutClearingWithMessage:[NSString stringWithFormat:@"正在加载第 %ld 个训练动作…", (long)step]];
    NSUInteger requestID = ++self.requestIdentifier;
    __weak typeof(self) weakSelf = self;
    self.requestTask = [self.networkManager GET:[IPAdress stringByAppendingString:apiLatestPlanTrainItem]
                                    parameters:@{@"itemid": self.itemIdentifier, @"seqn": @(step)}
                                       headers:@{@"X-MotionNote-Key": appSyncSecret}
                                      progress:nil
                                       success:^(NSURLSessionDataTask *task, id responseObject) {
        typeof(self) self = weakSelf;
        if (!self || requestID != self.requestIdentifier) return;
        self.requestTask = nil;
        if (responseObject == NSNull.null) {
            [self loadPostWorkout];
            return;
        }
        if (![responseObject isKindOfClass:NSDictionary.class]) {
            [self showRequestError:@"训练动作数据格式不正确"];
            return;
        }
        NSError *mappingError = nil;
        TrainItemDataModel *item = [MTLJSONAdapter modelOfClass:TrainItemDataModel.class
                                            fromJSONDictionary:responseObject
                                                         error:&mappingError];
        if (!item || mappingError) {
            [self showRequestError:@"训练动作数据解析失败"];
            return;
        }
        self.currentStep = step;
        [self renderTrainingItem:item];
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        typeof(self) self = weakSelf;
        if (!self || requestID != self.requestIdentifier) return;
        NSInteger statusCode = [(NSHTTPURLResponse *)task.response statusCode];
        if (statusCode == 404) {
            self.requestTask = nil;
            [self loadPostWorkout];
            return;
        }
        [self handleRequestFailure:error task:task requestID:requestID fallback:@"训练动作加载失败"];
    }];
}

- (void)loadPostWorkout {
    [self stopSpeechForContentTransition];
    [self beginLoadingWithoutClearingWithMessage:@"正在准备结束后拉伸…"];
    NSUInteger requestID = ++self.requestIdentifier;
    __weak typeof(self) weakSelf = self;
    self.requestTask = [self.networkManager GET:[IPAdress stringByAppendingString:apiLatestPlanPostWorkoutStretch]
                                    parameters:@{@"itemid": self.itemIdentifier}
                                       headers:@{@"X-MotionNote-Key": appSyncSecret}
                                      progress:nil
                                       success:^(NSURLSessionDataTask *task, id responseObject) {
        typeof(self) self = weakSelf;
        if (!self || requestID != self.requestIdentifier) return;
        self.requestTask = nil;
        if (![responseObject isKindOfClass:NSArray.class]) {
            [self showRequestError:@"拉伸数据格式不正确"];
            return;
        }
        NSError *mappingError = nil;
        NSArray<PostDataModel *> *items = [MTLJSONAdapter modelsOfClass:PostDataModel.class
                                                           fromJSONArray:responseObject
                                                                   error:&mappingError];
        if (!items || mappingError) {
            [self showRequestError:@"拉伸数据解析失败"];
            return;
        }
        [self renderPostWorkoutItems:items];
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        [weakSelf handleRequestFailure:error task:task requestID:requestID fallback:@"结束后拉伸加载失败"];
    }];
}

- (void)handleRequestFailure:(NSError *)error task:(NSURLSessionDataTask *)task requestID:(NSUInteger)requestID fallback:(NSString *)fallback {
    if (requestID != self.requestIdentifier ||
        ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled)) return;
    self.requestTask = nil;
    NSInteger statusCode = [(NSHTTPURLResponse *)task.response statusCode];
    NSString *message;
    if (statusCode == 401 || statusCode == 403) message = @"训练服务鉴权失败";
    else if (statusCode > 0) message = [NSString stringWithFormat:@"%@（HTTP %ld）", fallback, (long)statusCode];
    else message = @"无法连接训练服务，请检查 Mac 服务和局域网连接";
    [self showRequestError:message];
}

#pragma mark - Rendering

- (void)renderMissingPlan {
    [self resetVoiceGuidance];
    self.stage = CoachStageWaiting;
    self.currentStep = 0;
    self.hasCurrentContent = NO;
    self.stageTitleLabel.text = @"语音教练";
    [self clearContent];
    self.statusLabel.text = @"请先在“训练档案”中点击一个最近训练计划。";
    self.statusLabel.textColor = UIColor.secondaryLabelColor;
    self.statusLabel.hidden = NO;
    [self setControlsLoading:NO nextEnabled:NO speechEnabled:NO];
}

- (void)renderPreWorkoutItems:(NSArray<PrepareDataModel *> *)items {
    self.stage = CoachStagePreWorkout;
    self.currentStep = 0;
    self.hasCurrentContent = YES;
    self.stageTitleLabel.text = @"预热";
    [self finishLoading];
    [self clearContent];
    [self addSummaryForCount:items.count duration:[self totalDurationForItems:items] accent:UIColor.systemOrangeColor];
    [items enumerateObjectsUsingBlock:^(PrepareDataModel *item, NSUInteger index, BOOL *stop) {
        [self.contentStack addArrangedSubview:[self contentCardWithIndex:index + 1 name:item.name
                                                               duration:[self displayDurationText:item.durationText minutes:item.durationMinutes]
                                                            instructions:item.instructions accent:UIColor.systemOrangeColor]];
    }];
    if (items.count == 0) [self addEmptyContentMessage:@"没有额外预热项目，可以直接进入训练。"];
    self.currentSpeechText = [self speechTextForPreparationItems:items];
    [self setControlsLoading:NO nextEnabled:YES speechEnabled:self.currentSpeechText.length > 0];
    [self prepareSpeechForCurrentContent];
}

- (void)renderTrainingItem:(TrainItemDataModel *)item {
    self.stage = CoachStageTraining;
    self.hasCurrentContent = YES;
    self.stageTitleLabel.text = item.name.length > 0 ? item.name : @"训练动作";
    [self finishLoading];
    [self clearContent];

    UIStackView *badges = [[UIStackView alloc] init];
    badges.axis = UILayoutConstraintAxisHorizontal;
    badges.spacing = 8;
    badges.distribution = UIStackViewDistributionFillProportionally;
    if (item.category.length > 0) [badges addArrangedSubview:[self badgeWithIcon:@"figure.strengthtraining.traditional" text:item.category]];
    NSString *duration = [self displayDurationText:item.durationText minutes:item.durationMinutes];
    if (duration.length > 0) [badges addArrangedSubview:[self badgeWithIcon:@"clock" text:duration]];
    if (badges.arrangedSubviews.count > 0) [self.contentStack addArrangedSubview:badges];

    NSMutableArray<NSArray<NSString *> *> *parameters = [NSMutableArray array];
    if (item.setCount.integerValue > 0) [parameters addObject:@[@"组数", [NSString stringWithFormat:@"%@ 组", item.setCount]]];
    if (item.repetitionsPerSet.length > 0) [parameters addObject:@[@"每组次数", item.repetitionsPerSet]];
    if (item.restSeconds.integerValue > 0) [parameters addObject:@[@"组间休息", [NSString stringWithFormat:@"%@ 秒", item.restSeconds]]];
    if (item.trainingWeight.length > 0) [parameters addObject:@[@"训练重量", item.trainingWeight]];
    if (parameters.count > 0) [self.contentStack addArrangedSubview:[self parameterCard:parameters]];
    if (item.preparation.length > 0) [self.contentStack addArrangedSubview:[self textCardWithTitle:@"做前准备" icon:@"checklist" text:item.preparation accent:UIColor.systemBlueColor]];
    if (item.movementTrajectory.length > 0) [self.contentStack addArrangedSubview:[self textCardWithTitle:@"动作轨迹" icon:@"arrow.triangle.swap" text:item.movementTrajectory accent:UIColor.systemTealColor]];
    if (item.notes.length > 0) [self.contentStack addArrangedSubview:[self actionPointsCardWithText:item.notes]];

    self.currentSpeechText = [self speechTextForTrainingItem:item];
    [self setControlsLoading:NO nextEnabled:YES speechEnabled:self.currentSpeechText.length > 0];
    [self prepareSpeechForCurrentContent];
}

- (void)renderPostWorkoutItems:(NSArray<PostDataModel *> *)items {
    self.stage = CoachStagePostWorkout;
    self.hasCurrentContent = YES;
    self.stageTitleLabel.text = @"结束后拉伸";
    [self finishLoading];
    [self clearContent];
    [self addSummaryForCount:items.count duration:[self totalDurationForItems:items] accent:UIColor.systemTealColor];
    [items enumerateObjectsUsingBlock:^(PostDataModel *item, NSUInteger index, BOOL *stop) {
        [self.contentStack addArrangedSubview:[self contentCardWithIndex:index + 1 name:item.name
                                                               duration:[self displayDurationText:item.durationText minutes:item.durationMinutes]
                                                            instructions:item.instructions accent:UIColor.systemTealColor]];
    }];
    if (items.count == 0) [self addEmptyContentMessage:@"本次训练没有额外拉伸项目。"];
    self.currentSpeechText = [self speechTextForPostItems:items];
    [self setControlsLoading:NO nextEnabled:NO speechEnabled:self.currentSpeechText.length > 0];
    [self prepareSpeechForCurrentContent];
}

- (void)beginLoadingWithTitle:(NSString *)title message:(NSString *)message {
    self.stageTitleLabel.text = title;
    [self beginLoadingWithoutClearingWithMessage:message];
}

- (void)beginLoadingWithoutClearingWithMessage:(NSString *)message {
    [self.loadingIndicator startAnimating];
    self.statusLabel.text = message;
    self.statusLabel.textColor = UIColor.secondaryLabelColor;
    self.statusLabel.hidden = NO;
    [self setControlsLoading:YES nextEnabled:NO speechEnabled:NO];
}

- (void)finishLoading {
    [self.loadingIndicator stopAnimating];
    self.statusLabel.hidden = YES;
}

- (void)showRequestError:(NSString *)message {
    [self.loadingIndicator stopAnimating];
    self.statusLabel.text = message;
    self.statusLabel.textColor = UIColor.systemOrangeColor;
    self.statusLabel.hidden = NO;
    [self setControlsLoading:NO nextEnabled:YES speechEnabled:self.currentSpeechText.length > 0];
}

- (void)setControlsLoading:(BOOL)loading nextEnabled:(BOOL)nextEnabled speechEnabled:(BOOL)speechEnabled {
    self.nextButton.enabled = !loading && nextEnabled;
    self.speakButton.enabled = !loading && speechEnabled;
    self.speechProgressSlider.enabled = !loading && speechEnabled;
}

- (void)clearContent {
    for (UIView *view in self.contentStack.arrangedSubviews.copy) {
        [self.contentStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
}

- (void)addSummaryForCount:(NSUInteger)count duration:(NSNumber *)duration accent:(UIColor *)accent {
    NSString *durationText = duration.doubleValue > 0 ? [NSString stringWithFormat:@" · %@ 分钟", [self formattedNumber:duration]] : @"";
    UILabel *summary = [self labelWithStyle:UIFontTextStyleSubheadline color:accent];
    summary.text = [NSString stringWithFormat:@"共 %lu 项%@", (unsigned long)count, durationText];
    [self.contentStack addArrangedSubview:summary];
}

- (UIView *)contentCardWithIndex:(NSUInteger)index name:(NSString *)name duration:(NSString *)duration instructions:(NSString *)instructions accent:(UIColor *)accent {
    UILabel *indexLabel = [[UILabel alloc] init];
    indexLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)index];
    indexLabel.textColor = UIColor.whiteColor;
    indexLabel.backgroundColor = accent;
    indexLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightBold];
    indexLabel.textAlignment = NSTextAlignmentCenter;
    indexLabel.layer.cornerRadius = 13;
    indexLabel.clipsToBounds = YES;
    [indexLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(26);
    }];
    UILabel *nameLabel = [self labelWithStyle:UIFontTextStyleHeadline color:UIColor.labelColor];
    nameLabel.text = name.length > 0 ? name : @"未命名项目";
    UILabel *durationLabel = [self labelWithStyle:UIFontTextStyleSubheadline color:accent];
    durationLabel.text = duration;
    durationLabel.hidden = duration.length == 0;
    UIStackView *titleStack = [[UIStackView alloc] initWithArrangedSubviews:@[nameLabel, durationLabel]];
    titleStack.axis = UILayoutConstraintAxisVertical;
    titleStack.spacing = 2;
    UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:@[indexLabel, titleStack]];
    heading.axis = UILayoutConstraintAxisHorizontal;
    heading.spacing = 10;
    heading.alignment = UIStackViewAlignmentCenter;
    UIStackView *card = [[UIStackView alloc] initWithArrangedSubviews:@[heading]];
    card.axis = UILayoutConstraintAxisVertical;
    card.spacing = 10;
    if (instructions.length > 0) {
        UILabel *instructionsLabel = [self labelWithStyle:UIFontTextStyleBody color:UIColor.secondaryLabelColor];
        instructionsLabel.text = instructions;
        [card addArrangedSubview:instructionsLabel];
    }
    card.layoutMargins = UIEdgeInsetsMake(14, 14, 14, 14);
    card.layoutMarginsRelativeArrangement = YES;
    card.backgroundColor = UIColor.tertiarySystemGroupedBackgroundColor;
    card.layer.cornerRadius = 14;
    return card;
}

- (UIView *)parameterCard:(NSArray<NSArray<NSString *> *> *)parameters {
    UIStackView *card = [[UIStackView alloc] init];
    card.axis = UILayoutConstraintAxisVertical;
    card.spacing = 10;
    UILabel *heading = [self labelWithStyle:UIFontTextStyleHeadline color:UIColor.labelColor];
    heading.text = @"训练参数";
    [card addArrangedSubview:heading];
    for (NSArray<NSString *> *pair in parameters) {
        UILabel *keyLabel = [self labelWithStyle:UIFontTextStyleSubheadline color:UIColor.secondaryLabelColor];
        keyLabel.text = pair.firstObject;
        [keyLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        UILabel *valueLabel = [self labelWithStyle:UIFontTextStyleBody color:UIColor.labelColor];
        valueLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        valueLabel.text = pair.lastObject;
        valueLabel.textAlignment = NSTextAlignmentRight;
        UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[keyLabel, valueLabel]];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.spacing = 12;
        row.alignment = UIStackViewAlignmentFirstBaseline;
        [card addArrangedSubview:row];
    }
    card.layoutMargins = UIEdgeInsetsMake(14, 14, 14, 14);
    card.layoutMarginsRelativeArrangement = YES;
    card.backgroundColor = UIColor.tertiarySystemGroupedBackgroundColor;
    card.layer.cornerRadius = 14;
    return card;
}

- (UIView *)textCardWithTitle:(NSString *)title icon:(NSString *)iconName text:(NSString *)text accent:(UIColor *)accent {
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName]];
    icon.tintColor = accent;
    [icon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(20);
    }];
    UILabel *titleLabel = [self labelWithStyle:UIFontTextStyleHeadline color:UIColor.labelColor];
    titleLabel.text = title;
    UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:@[icon, titleLabel]];
    heading.axis = UILayoutConstraintAxisHorizontal;
    heading.spacing = 8;
    heading.alignment = UIStackViewAlignmentCenter;
    UILabel *body = [self labelWithStyle:UIFontTextStyleBody color:UIColor.secondaryLabelColor];
    body.text = text;
    UIStackView *card = [[UIStackView alloc] initWithArrangedSubviews:@[heading, body]];
    card.axis = UILayoutConstraintAxisVertical;
    card.spacing = 10;
    card.layoutMargins = UIEdgeInsetsMake(14, 14, 14, 14);
    card.layoutMarginsRelativeArrangement = YES;
    card.backgroundColor = UIColor.tertiarySystemGroupedBackgroundColor;
    card.layer.cornerRadius = 14;
    return card;
}

- (UIView *)actionPointsCardWithText:(NSString *)text {
    UIColor *accent = UIColor.systemOrangeColor;
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lightbulb.fill"]];
    icon.tintColor = accent;
    [icon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(20);
    }];
    UILabel *titleLabel = [self labelWithStyle:UIFontTextStyleHeadline color:UIColor.labelColor];
    titleLabel.text = @"动作要点";
    UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:@[icon, titleLabel]];
    heading.axis = UILayoutConstraintAxisHorizontal;
    heading.spacing = 8;
    heading.alignment = UIStackViewAlignmentCenter;

    UIStackView *card = [[UIStackView alloc] initWithArrangedSubviews:@[heading]];
    card.axis = UILayoutConstraintAxisVertical;
    card.spacing = 12;
    NSArray<NSString *> *points = [self actionPointsFromText:text];
    [points enumerateObjectsUsingBlock:^(NSString *point, NSUInteger index, BOOL *stop) {
        UILabel *numberLabel = [[UILabel alloc] init];
        numberLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)index + 1];
        numberLabel.textColor = UIColor.whiteColor;
        numberLabel.backgroundColor = accent;
        numberLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightBold];
        numberLabel.textAlignment = NSTextAlignmentCenter;
        numberLabel.layer.cornerRadius = 13;
        numberLabel.clipsToBounds = YES;
        [numberLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.height.mas_equalTo(26);
        }];

        UILabel *pointLabel = [self labelWithStyle:UIFontTextStyleBody color:UIColor.secondaryLabelColor];
        pointLabel.text = point;
        UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[numberLabel, pointLabel]];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.spacing = 10;
        row.alignment = UIStackViewAlignmentTop;
        [card addArrangedSubview:row];
    }];
    card.layoutMargins = UIEdgeInsetsMake(14, 14, 14, 14);
    card.layoutMarginsRelativeArrangement = YES;
    card.backgroundColor = UIColor.tertiarySystemGroupedBackgroundColor;
    card.layer.cornerRadius = 14;
    return card;
}

- (NSArray<NSString *> *)actionPointsFromText:(NSString *)text {
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedText.length == 0) return @[];

    NSString *pattern = @"(?:[0-9]{1,2}\\s*[、\\)）]|[0-9]{1,2}[\\.．]\\s+|[一二三四五六七八九十]+、|[①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳])\\s*";
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:trimmedText options:0 range:NSMakeRange(0, trimmedText.length)];
    NSMutableArray<NSString *> *points = [NSMutableArray array];
    if (matches.count > 0) {
        [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult *match, NSUInteger index, BOOL *stop) {
            NSUInteger start = NSMaxRange(match.range);
            NSUInteger end = index + 1 < matches.count ? matches[index + 1].range.location : trimmedText.length;
            if (end <= start) return;
            NSString *point = [[trimmedText substringWithRange:NSMakeRange(start, end - start)]
                stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (point.length > 0) [points addObject:point];
        }];
    }
    if (points.count > 0) return points;

    [trimmedText enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        NSString *point = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (point.length > 0) [points addObject:point];
    }];
    return points.count > 0 ? points : @[trimmedText];
}

- (UIView *)badgeWithIcon:(NSString *)iconName text:(NSString *)text {
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName]];
    icon.tintColor = UIColor.secondaryLabelColor;
    [icon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(16);
    }];
    UILabel *label = [self labelWithStyle:UIFontTextStyleFootnote color:UIColor.secondaryLabelColor];
    label.text = text;
    label.numberOfLines = 1;
    UIStackView *badge = [[UIStackView alloc] initWithArrangedSubviews:@[icon, label]];
    badge.axis = UILayoutConstraintAxisHorizontal;
    badge.spacing = 6;
    badge.alignment = UIStackViewAlignmentCenter;
    badge.layoutMargins = UIEdgeInsetsMake(7, 10, 7, 10);
    badge.layoutMarginsRelativeArrangement = YES;
    badge.backgroundColor = UIColor.tertiarySystemGroupedBackgroundColor;
    badge.layer.cornerRadius = 10;
    return badge;
}

- (void)addEmptyContentMessage:(NSString *)message {
    UILabel *label = [self labelWithStyle:UIFontTextStyleBody color:UIColor.secondaryLabelColor];
    label.text = message;
    [self.contentStack addArrangedSubview:label];
}

#pragma mark - Voice and navigation

- (void)observeSpeechCoach {
    __weak typeof(self) weakSelf = self;
    self.speechCoach.progressHandler = ^(float progress) {
        typeof(self) self = weakSelf;
        if (!self || !self.acceptsSpeechProgressUpdates || self.scrubbingSpeechProgress) return;
        self.speechProgressSlider.value = progress;
        [self updateSpeechProgressLabel:progress];
    };
    self.speechCoach.completionHandler = ^{
        typeof(self) self = weakSelf;
        if (!self || !self.acceptsSpeechProgressUpdates) return;
        self.speechPlaying = NO;
        self.speechCompleted = YES;
        self.speechProgressSlider.value = 1;
        [self updateSpeechProgressLabel:1];
        [self updateSpeechButton];
    };
}

- (void)resetVoiceGuidance {
    [self.speechCoach stopSpeaking];
    self.voiceGuidanceEnabled = NO;
    self.speechPlaying = NO;
    self.speechCompleted = NO;
    self.scrubbingSpeechProgress = NO;
    self.acceptsSpeechProgressUpdates = NO;
    [self resetSpeechProgress];
    [self updateSpeechButton];
}

- (void)stopSpeechForContentTransition {
    self.acceptsSpeechProgressUpdates = NO;
    [self.speechCoach stopSpeaking];
    self.speechPlaying = NO;
    self.speechCompleted = NO;
    self.scrubbingSpeechProgress = NO;
    self.currentSpeechText = @"";
    [self resetSpeechProgress];
    [self updateSpeechButton];
}

- (void)prepareSpeechForCurrentContent {
    self.acceptsSpeechProgressUpdates = NO;
    self.speechPlaying = NO;
    self.speechCompleted = NO;
    [self resetSpeechProgress];
    if (self.voiceGuidanceEnabled && self.currentSpeechText.length > 0) {
        [self startCurrentSpeechFromProgress:0];
    } else {
        [self updateSpeechButton];
    }
}

- (void)startCurrentSpeechFromProgress:(float)progress {
    if (self.currentSpeechText.length == 0) return;
    self.voiceGuidanceEnabled = YES;
    self.speechPlaying = YES;
    self.speechCompleted = NO;
    self.acceptsSpeechProgressUpdates = YES;
    [self updateSpeechButton];
    [self.speechCoach speakText:self.currentSpeechText fromProgress:progress];
}

- (void)updateSpeechButton {
    if (!self.speakButton) return;
    UIButtonConfiguration *configuration = [self.speakButton.configuration copy];
    if (self.speechPlaying) {
        configuration.title = @"取消语音播放";
        configuration.image = [UIImage systemImageNamed:@"stop.circle.fill"];
        configuration.baseForegroundColor = UIColor.systemRedColor;
        configuration.baseBackgroundColor = UIColor.systemRedColor;
    } else if (self.speechCompleted) {
        configuration.title = @"再次听取语音播放指导";
        configuration.image = [UIImage systemImageNamed:@"arrow.counterclockwise.circle.fill"];
        configuration.baseForegroundColor = UIColor.systemOrangeColor;
        configuration.baseBackgroundColor = UIColor.systemOrangeColor;
    } else {
        configuration.title = @"听取语音指导";
        configuration.image = [UIImage systemImageNamed:@"speaker.wave.2.fill"];
        configuration.baseForegroundColor = UIColor.systemOrangeColor;
        configuration.baseBackgroundColor = UIColor.systemOrangeColor;
    }
    self.speakButton.configuration = configuration;
}

- (void)updateSpeechProgressLabel:(float)progress {
    NSInteger percentage = (NSInteger)(MIN(MAX(progress, 0.0f), 1.0f) * 100 + 0.5f);
    self.speechProgressLabel.text = [NSString stringWithFormat:@"%ld%%", (long)percentage];
}

- (void)resetSpeechProgress {
    [self.speechProgressSlider setValue:0 animated:NO];
    [self updateSpeechProgressLabel:0];
}

- (void)speechSliderTouchDown:(UISlider *)slider {
    self.scrubbingSpeechProgress = YES;
}

- (void)speechSliderValueChanged:(UISlider *)slider {
    [self updateSpeechProgressLabel:slider.value];
}

- (void)speechSliderTouchEnded:(UISlider *)slider {
    self.scrubbingSpeechProgress = NO;
    if (self.currentSpeechText.length == 0) return;
    if (slider.value >= 0.999f) {
        self.acceptsSpeechProgressUpdates = NO;
        [self.speechCoach stopSpeaking];
        self.voiceGuidanceEnabled = YES;
        self.speechPlaying = NO;
        self.speechCompleted = YES;
        slider.value = 1;
        [self updateSpeechProgressLabel:1];
        [self updateSpeechButton];
        return;
    }
    [self startCurrentSpeechFromProgress:slider.value];
}

- (void)goToNextStep {
    if (self.itemIdentifier.length == 0 || self.requestTask || self.stage == CoachStagePostWorkout) return;
    self.acceptsSpeechProgressUpdates = NO;
    [self resetSpeechProgress];
    if (self.stage == CoachStagePreWorkout && !self.hasCurrentContent) {
        [self loadPreWorkout];
        return;
    }
    [self loadTrainingStep:self.currentStep + 1];
}

- (void)speakCurrentContent {
    if (self.speechPlaying) {
        [self resetVoiceGuidance];
        return;
    }
    [self startCurrentSpeechFromProgress:0];
}

- (NSString *)speechTextForPreparationItems:(NSArray<PrepareDataModel *> *)items {
    NSMutableArray<NSString *> *paragraphs = [NSMutableArray arrayWithObject:@"现在开始预热。"];
    for (PrepareDataModel *item in items) {
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        if (item.name.length > 0) [parts addObject:item.name];
        NSString *duration = [self displayDurationText:item.durationText minutes:item.durationMinutes];
        if (duration.length > 0) [parts addObject:duration];
        if (item.instructions.length > 0) [parts addObject:item.instructions];
        if (parts.count > 0) [paragraphs addObject:[[parts componentsJoinedByString:@"。"] stringByAppendingString:@"。"]];
    }
    return [paragraphs componentsJoinedByString:@"\n\n"];
}

- (NSString *)speechTextForTrainingItem:(TrainItemDataModel *)item {
    NSMutableArray<NSString *> *summaryParts = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"现在进行第 %ld 步，%@", (long)self.currentStep, item.name ?: @"训练动作"]];
    if (item.setCount.integerValue > 0) [summaryParts addObject:[NSString stringWithFormat:@"%@组", item.setCount]];
    if (item.repetitionsPerSet.length > 0) [summaryParts addObject:item.repetitionsPerSet];
    if (item.restSeconds.integerValue > 0) [summaryParts addObject:[NSString stringWithFormat:@"组间休息%@秒", item.restSeconds]];
    if (item.trainingWeight.length > 0) [summaryParts addObject:[NSString stringWithFormat:@"训练重量，%@", item.trainingWeight]];

    NSMutableArray<NSString *> *paragraphs = [NSMutableArray arrayWithObject:[[summaryParts componentsJoinedByString:@"。"] stringByAppendingString:@"。"]];
    if (item.preparation.length > 0) [paragraphs addObject:[NSString stringWithFormat:@"做前准备。%@。", item.preparation]];
    if (item.movementTrajectory.length > 0) [paragraphs addObject:[NSString stringWithFormat:@"动作轨迹。%@。", item.movementTrajectory]];
    NSArray<NSString *> *actionPoints = [self actionPointsFromText:item.notes ?: @""];
    if (actionPoints.count > 0) {
        [paragraphs addObject:@"动作要点。"];
        [actionPoints enumerateObjectsUsingBlock:^(NSString *point, NSUInteger index, BOOL *stop) {
            [paragraphs addObject:[NSString stringWithFormat:@"第%lu点。%@。", (unsigned long)index + 1, point]];
        }];
    }
    return [paragraphs componentsJoinedByString:@"\n\n"];
}

- (NSString *)speechTextForPostItems:(NSArray<PostDataModel *> *)items {
    NSMutableArray<NSString *> *paragraphs = [NSMutableArray arrayWithObject:@"训练完成，现在进行结束后拉伸。"];
    for (PostDataModel *item in items) {
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        if (item.name.length > 0) [parts addObject:item.name];
        NSString *duration = [self displayDurationText:item.durationText minutes:item.durationMinutes];
        if (duration.length > 0) [parts addObject:duration];
        if (item.instructions.length > 0) [parts addObject:item.instructions];
        if (parts.count > 0) [paragraphs addObject:[[parts componentsJoinedByString:@"。"] stringByAppendingString:@"。"]];
    }
    return [paragraphs componentsJoinedByString:@"\n\n"];
}

- (NSString *)displayDurationText:(NSString *)durationText minutes:(NSNumber *)minutes {
    if (durationText.length > 0) return durationText;
    return minutes.doubleValue > 0 ? [NSString stringWithFormat:@"%@ 分钟", [self formattedNumber:minutes]] : @"";
}

- (NSNumber *)totalDurationForItems:(NSArray *)items {
    double total = 0;
    for (id item in items) {
        NSNumber *minutes = [item valueForKey:@"durationMinutes"];
        if ([minutes isKindOfClass:NSNumber.class]) total += minutes.doubleValue;
    }
    return @(total);
}

- (NSString *)formattedNumber:(NSNumber *)number {
    double value = number.doubleValue;
    return value == floor(value) ? [NSString stringWithFormat:@"%.0f", value] : [NSString stringWithFormat:@"%.1f", value];
}

@end
