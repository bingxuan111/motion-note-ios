#import "RecordViewController.h"
#import "FeishuService.h"
#import "HealthService.h"
#import <AFNetworking/AFNetworking.h>
#import <Mantle/Mantle.h>
#import <Masonry/Masonry.h>
#import <WebKit/WebKit.h>

NSString * const IPAdress = @"http://192.168.3.42:3000";
NSString * const appSyncSecret = @"477e700fc1dc9b78f6bd9c0a6ce9e43253433c9183d8a82bad262bc88a1af681";
static NSString * const apiLatestPlanAbstract = @"/api/latest-plan/abstract";

@interface TrainPlanDocumentViewController : UIViewController <WKNavigationDelegate>
@property (nonatomic, strong) NSURL *documentURL;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *errorLabel;
- (instancetype)initWithURL:(NSURL *)URL title:(NSString *)title;
@end

@implementation TrainPlanDocumentViewController

- (instancetype)initWithURL:(NSURL *)URL title:(NSString *)title {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _documentURL = URL;
        self.title = title.length > 0 ? title : @"训练文档";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.websiteDataStore = WKWebsiteDataStore.defaultDataStore;
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    self.webView.navigationDelegate = self;
    self.webView.allowsBackForwardNavigationGestures = YES;
    [self.view addSubview:self.webView];
    [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
        //make.edges.equalTo(self.view.safeAreaLayoutGuide);
        make.edges.equalTo(self.view);
    }];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    [self.spinner mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.view);
    }];

    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.errorLabel.textColor = UIColor.secondaryLabelColor;
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.hidden = YES;
    [self.view addSubview:self.errorLabel];
    [self.errorLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.view);
        make.leading.greaterThanOrEqualTo(self.view).offset(32);
        make.trailing.lessThanOrEqualTo(self.view).offset(-32);
    }];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.clockwise"]
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(reloadDocument)];
    [self reloadDocument];
}

- (void)dealloc {
    _webView.navigationDelegate = nil;
    [_webView stopLoading];
}

- (void)reloadDocument {
    self.errorLabel.hidden = YES;
    self.webView.hidden = NO;
    [self.spinner startAnimating];
    [self.webView loadRequest:[NSURLRequest requestWithURL:self.documentURL
                                               cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                           timeoutInterval:30]];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self.spinner stopAnimating];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self showLoadError:error];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self showLoadError:error];
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    [self showLoadError:nil];
}

- (void)showLoadError:(NSError *)error {
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) return;
    [self.spinner stopAnimating];
    self.webView.hidden = YES;
    self.errorLabel.text = @"文档加载失败\n请检查网络或飞书文档权限，然后点击右上角重试。";
    self.errorLabel.hidden = NO;
}

- (void)webView:(WKWebView *)webView
decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSString *scheme = navigationAction.request.URL.scheme.lowercaseString;
    BOOL allowed = [scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"about"];
    if (!allowed) {
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    if (!navigationAction.targetFrame) {
        [webView loadRequest:navigationAction.request];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

@end

@interface RecordViewController () <UITextFieldDelegate>
@property (nonatomic, strong) WorkoutStore *store;
@property (nonatomic, strong) HealthService *healthService;
@property (nonatomic, strong) FeishuService *feishuService;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIStackView *plansStack;
@property (nonatomic, strong) UITextField *gatewayField;
@property (nonatomic, strong) UITextField *syncURLField;
@property (nonatomic, strong) UITextField *syncKeyField;
@property (nonatomic, strong) UITextField *discomfortField;
@property (nonatomic, strong) UILabel *feishuStatusLabel;
@property (nonatomic, strong) UILabel *syncConfiguredLabel;
@property (nonatomic, strong) UILabel *importMessageLabel;
@property (nonatomic, strong) UILabel *healthStatusLabel;
@property (nonatomic, strong) UILabel *healthDetailsLabel;
@property (nonatomic, strong) UILabel *effortLabel;
@property (nonatomic, strong) UIButton *syncButton;
@property (nonatomic, strong) UILabel *latestPlanStatusLabel;
@property (nonatomic, strong) UIStackView *latestPlanStack;
@property (nonatomic, strong) UIActivityIndicatorView *latestPlanSpinner;
@property (nonatomic, strong) NSURLSessionDataTask *latestPlanTask;
@property (nonatomic, assign) NSUInteger latestPlanRequestID;
@property (nonatomic, strong) AFHTTPSessionManager *latestPlanManager;
@property (nonatomic, strong, nullable) TrainPlanAbstractDataModel *latestPlan;
@end

@implementation RecordViewController

- (instancetype)initWithWorkoutStore:(WorkoutStore *)store
                       healthService:(HealthService *)healthService
                        feishuService:(FeishuService *)feishuService {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _store = store;
        _healthService = healthService;
        _feishuService = feishuService;
        _weeklyPlans = @[];
        _activeWeeklyPlanID = @"";
        self.title = @"训练档案";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"训练档案" image:[UIImage systemImageNamed:@"note.text"] tag:2];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(refreshDisplayedData)
                                                     name:MotionNoteFeishuStatusDidChangeNotification
                                                   object:feishuService];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fetchLatestPlanIfVisible)
                                                     name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [_latestPlanTask cancel];
    [_latestPlanManager invalidateSessionCancelingTasks:YES resetSession:NO];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    [self buildInterface];
    [self refreshDisplayedData];
    [self fetchLatestPlan];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshDisplayedData];
}

- (void)buildInterface {
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    [self.view addSubview:scrollView];

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 18;
    [scrollView addSubview:self.contentStack];

    [scrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    [self.contentStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(scrollView).insets(UIEdgeInsetsMake(16, 16, 24, 16));
        make.width.equalTo(scrollView).offset(-32);
    }];

    self.latestPlanStatusLabel = [self detailLabel];
    self.latestPlanSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.latestPlanSpinner.hidesWhenStopped = YES;
    self.latestPlanStack = [[UIStackView alloc] init];
    self.latestPlanStack.axis = UILayoutConstraintAxisVertical;
    self.latestPlanStack.spacing = 12;
    [self.contentStack addArrangedSubview:[self latestPlanSectionWithViews:@[self.latestPlanSpinner,
                                                                            self.latestPlanStatusLabel,
                                                                            self.latestPlanStack]]];

    self.gatewayField = [self textFieldWithPlaceholder:@"本机飞书中转 HTTPS 地址" secure:NO];
    self.gatewayField.keyboardType = UIKeyboardTypeURL;
    UIButton *connectButton = [self actionButtonWithTitle:@"连接飞书" selector:@selector(connectFeishu) filled:NO];
    self.feishuStatusLabel = [self detailLabel];
    UILabel *feishuHelp = [self detailLabel];
    feishuHelp.text = @"授权后，把训练文档发送给 Motion Note 机器人；App 打开或回到前台时会自动检查本周课表。";
    [self.contentStack addArrangedSubview:[self sectionWithTitle:@"飞书连接" views:@[self.gatewayField, connectButton, self.feishuStatusLabel, feishuHelp]]];

    self.syncURLField = [self textFieldWithPlaceholder:@"Railway HTTPS 服务地址" secure:NO];
    self.syncURLField.keyboardType = UIKeyboardTypeURL;
    self.syncKeyField = [self textFieldWithPlaceholder:@"计划同步密钥" secure:YES];
    self.syncConfiguredLabel = [self detailLabel];
    self.syncButton = [self actionButtonWithTitle:@"立即检查" selector:@selector(syncPlans) filled:YES];
    self.importMessageLabel = [self detailLabel];
    self.importMessageLabel.textColor = UIColor.systemGreenColor;
    UILabel *syncHelp = [self detailLabel];
    syncHelp.text = @"机器人收到的最近两份训练文档会自动同步，并按第 1 练、第 2 练保留。";
    [self.contentStack addArrangedSubview:[self sectionWithTitle:@"飞书本周课表" views:@[syncHelp, self.syncURLField, self.syncKeyField, self.syncConfiguredLabel, self.syncButton, self.importMessageLabel]]];

    self.plansStack = [[UIStackView alloc] init];
    self.plansStack.axis = UILayoutConstraintAxisVertical;
    self.plansStack.spacing = 12;
    [self.contentStack addArrangedSubview:[self sectionWithTitle:@"已导入的本周私教课" views:@[self.plansStack]]];

    self.healthStatusLabel = [self detailLabel];
    self.healthStatusLabel.textColor = UIColor.labelColor;
    self.healthDetailsLabel = [self detailLabel];
    UIButton *refreshHealth = [self actionButtonWithTitle:@"刷新今日数据" selector:@selector(refreshHealth) filled:NO];
    UIButton *connectHealth = [self actionButtonWithTitle:@"连接 Apple 健康" selector:@selector(connectHealth) filled:YES];
    [self.contentStack addArrangedSubview:[self sectionWithTitle:@"Apple Watch 与训练数据" views:@[self.healthStatusLabel, self.healthDetailsLabel, refreshHealth, connectHealth]]];

    UISlider *effortSlider = [[UISlider alloc] init];
    effortSlider.minimumValue = 1;
    effortSlider.maximumValue = 10;
    effortSlider.value = self.store.effort;
    [effortSlider addTarget:self action:@selector(effortChanged:) forControlEvents:UIControlEventValueChanged];
    self.effortLabel = [self detailLabel];
    self.discomfortField = [self textFieldWithPlaceholder:@"疼痛、不适或下次调整" secure:NO];
    [self.contentStack addArrangedSubview:[self sectionWithTitle:@"训练后反馈" views:@[effortSlider, self.effortLabel, self.discomfortField]]];
}

- (UIView *)sectionWithTitle:(NSString *)title views:(NSArray<UIView *> *)views {
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.layoutMargins = UIEdgeInsetsMake(16, 16, 16, 16);
    stack.layoutMarginsRelativeArrangement = YES;
    stack.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    stack.layer.cornerRadius = 14;
    for (UIView *view in views) {
        [stack addArrangedSubview:view];
    }
    return stack;
}

- (UIView *)latestPlanSectionWithViews:(NSArray<UIView *> *)views {
    UIColor *accentColor = [UIColor colorWithRed:0.14 green:0.38 blue:0.25 alpha:1.0];

    UIView *iconBackground = [[UIView alloc] init];
    iconBackground.backgroundColor = [accentColor colorWithAlphaComponent:0.13];
    iconBackground.layer.cornerRadius = 12;
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"calendar.badge.clock"]];
    icon.tintColor = accentColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [iconBackground addSubview:icon];
    [iconBackground mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(44);
    }];
    [icon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(iconBackground);
        make.width.height.mas_equalTo(24);
    }];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"最近训练计划";
    titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle2];
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.adjustsFontForContentSizeCategory = YES;

    UILabel *subtitleLabel = [self detailLabel];
    subtitleLabel.text = @"训练概览与语音指导";
    subtitleLabel.textColor = accentColor;

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, subtitleLabel]];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 2;
    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[iconBackground, textStack]];
    header.axis = UILayoutConstraintAxisHorizontal;
    header.spacing = 12;
    header.alignment = UIStackViewAlignmentCenter;

    UIStackView *section = [[UIStackView alloc] initWithArrangedSubviews:@[header]];
    section.axis = UILayoutConstraintAxisVertical;
    section.spacing = 14;
    section.layoutMargins = UIEdgeInsetsMake(18, 18, 18, 18);
    section.layoutMarginsRelativeArrangement = YES;
    section.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    section.layer.cornerRadius = 18;
    section.layer.borderWidth = 1;
    section.layer.borderColor = [accentColor colorWithAlphaComponent:0.12].CGColor;
    for (UIView *view in views) [section addArrangedSubview:view];
    return section;
}

- (UITextField *)textFieldWithPlaceholder:(NSString *)placeholder secure:(BOOL)secure {
    UITextField *field = [[UITextField alloc] init];
    field.placeholder = placeholder;
    field.secureTextEntry = secure;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.delegate = self;
    [field addTarget:self action:@selector(fieldChanged:) forControlEvents:UIControlEventEditingChanged];
    return field;
}

- (UIButton *)actionButtonWithTitle:(NSString *)title selector:(SEL)selector filled:(BOOL)filled {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.configuration = filled ? [UIButtonConfiguration filledButtonConfiguration] : [UIButtonConfiguration borderedButtonConfiguration];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UILabel *)detailLabel {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    label.textColor = UIColor.secondaryLabelColor;
    label.numberOfLines = 0;
    return label;
}

- (void)setWeeklyPlans:(NSArray<ImportedPlan *> *)weeklyPlans {
    _weeklyPlans = [weeklyPlans copy];
    [self rebuildPlans];
}

- (void)setActiveWeeklyPlanID:(NSString *)activeWeeklyPlanID {
    _activeWeeklyPlanID = [activeWeeklyPlanID copy];
    [self rebuildPlans];
}

- (void)rebuildPlans {
    if (!self.plansStack) return;
    for (UIView *view in self.plansStack.arrangedSubviews.copy) {
        [self.plansStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    if (self.weeklyPlans.count == 0) {
        UILabel *empty = [self detailLabel];
        empty.text = @"还没有导入课程内容";
        [self.plansStack addArrangedSubview:empty];
        return;
    }
    [self.weeklyPlans enumerateObjectsUsingBlock:^(ImportedPlan *plan, NSUInteger index, BOOL *stop) {
        BOOL selected = [plan.identifier isEqualToString:self.activeWeeklyPlanID];
        UILabel *label = [self detailLabel];
        label.textColor = UIColor.labelColor;
        label.text = [NSString stringWithFormat:@"第 %lu 练%@\n%@\n%@", (unsigned long)index + 1, selected ? @" · 当前依据" : @"", plan.title, plan.preview];
        UIButton *selectButton = [self actionButtonWithTitle:selected ? @"当前作为训练依据" : @"设为当天训练依据"
                                                    selector:@selector(selectPlan:)
                                                      filled:NO];
        selectButton.tag = index;
        [self.plansStack addArrangedSubview:label];
        [self.plansStack addArrangedSubview:selectButton];
    }];
}

- (void)refreshDisplayedData {
    if (!self.isViewLoaded) return;
    self.gatewayField.text = self.feishuService.gatewayURL;
    self.syncURLField.text = self.feishuService.planSyncURL;
    self.syncKeyField.text = self.feishuService.planSyncKey;
    self.discomfortField.text = self.store.discomfort;
    self.feishuStatusLabel.text = self.feishuService.status;
    self.syncConfiguredLabel.text = self.feishuService.planSyncConfigured ? @"✓ 已启用自动同步" : @"填写服务地址和密钥后启用自动同步";
    self.syncConfiguredLabel.textColor = self.feishuService.planSyncConfigured ? UIColor.systemGreenColor : UIColor.secondaryLabelColor;
    self.healthStatusLabel.text = self.healthService.status;
    NSMutableArray<NSString *> *details = [NSMutableArray array];
    if (self.healthService.todayActiveEnergy) [details addObject:[NSString stringWithFormat:@"今日活动能量：%ld 千卡", (long)self.healthService.todayActiveEnergy.integerValue]];
    if (self.healthService.todaySteps) [details addObject:[NSString stringWithFormat:@"今日步数：%ld 步", (long)self.healthService.todaySteps.integerValue]];
    if ([self.healthService.status isEqualToString:@"已连接 Apple 健康"]) [details addObject:[NSString stringWithFormat:@"今日训练记录：%ld 次", (long)self.healthService.recentWorkouts]];
    self.healthDetailsLabel.text = [details componentsJoinedByString:@"\n"];
    self.effortLabel.text = [NSString stringWithFormat:@"主观用力程度：%ld/10", (long)llround(self.store.effort)];
    [self rebuildPlans];
}

- (void)setSyncing:(BOOL)syncing {
    self.syncButton.enabled = !syncing;
    [self.syncButton setTitle:syncing ? @"正在检查…" : @"立即检查" forState:UIControlStateNormal];
}

- (void)showImportMessage:(NSString *)message {
    self.importMessageLabel.text = message;
    self.importMessageLabel.textColor = [message containsString:@"已同步"] ? UIColor.systemGreenColor : UIColor.systemOrangeColor;
}

- (void)fieldChanged:(UITextField *)field {
    if (field == self.gatewayField) self.feishuService.gatewayURL = field.text ?: @"";
    if (field == self.syncURLField) self.feishuService.planSyncURL = field.text ?: @"";
    if (field == self.syncKeyField) self.feishuService.planSyncKey = field.text ?: @"";
    if (field == self.discomfortField) self.store.discomfort = field.text ?: @"";
    self.syncConfiguredLabel.text = self.feishuService.planSyncConfigured ? @"✓ 已启用自动同步" : @"填写服务地址和密钥后启用自动同步";
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)connectFeishu { [self.feishuService openAuthorization]; }
- (void)syncPlans { if (self.syncPlansHandler) self.syncPlansHandler(); }

- (void)fetchLatestPlanIfVisible {
    if (self.isViewLoaded && self.view.window && !self.latestPlanTask) [self fetchLatestPlan];
}

- (void)setLatestPlanLoading:(BOOL)loading {
    if (loading) [self.latestPlanSpinner startAnimating];
    else [self.latestPlanSpinner stopAnimating];
}

- (void)clearLatestPlanContent {
    for (UIView *view in self.latestPlanStack.arrangedSubviews.copy) {
        [self.latestPlanStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
}

- (void)fetchLatestPlan {
    NSUInteger requestID = ++self.latestPlanRequestID;
    [self.latestPlanTask cancel];
    self.latestPlanTask = nil;
    self.latestPlan = nil;
    [self clearLatestPlanContent];
    [self setLatestPlanLoading:YES];
    self.latestPlanStatusLabel.hidden = NO;
    self.latestPlanStatusLabel.text = @"正在加载计划摘要…";
    self.latestPlanStatusLabel.textColor = UIColor.secondaryLabelColor;

    NSURL *URL = [NSURL URLWithString:[IPAdress stringByAppendingString:apiLatestPlanAbstract]];
    if (!URL) {
        [self showLatestPlanError:@"训练计划服务地址无效"];
        return;
    }
    if (!self.latestPlanManager) {
        NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        configuration.URLCache = nil;
        self.latestPlanManager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:configuration];
        self.latestPlanManager.requestSerializer.timeoutInterval = 15;
        AFJSONResponseSerializer *responseSerializer = [AFJSONResponseSerializer serializer];
        responseSerializer.readingOptions = NSJSONReadingAllowFragments;
        self.latestPlanManager.responseSerializer = responseSerializer;
        [self.latestPlanManager setTaskWillPerformHTTPRedirectionBlock:^NSURLRequest *(NSURLSession *session, NSURLSessionTask *task, NSURLResponse *response, NSURLRequest *request) {
            return nil;
        }];
    }

    __weak typeof(self) weakSelf = self;
    self.latestPlanTask = [self.latestPlanManager GET:URL.absoluteString
                                          parameters:nil
                                             headers:@{@"X-MotionNote-Key": appSyncSecret}
                                            progress:nil
                                             success:^(NSURLSessionDataTask *task, id responseObject) {
        typeof(self) self = weakSelf;
        if (!self || requestID != self.latestPlanRequestID) return;
        self.latestPlanTask = nil;
        [self setLatestPlanLoading:NO];
        if (responseObject == NSNull.null) {
            self.latestPlanStatusLabel.text = @"暂无训练计划";
            return;
        }
        if (![responseObject isKindOfClass:NSDictionary.class]) {
            [self showLatestPlanError:@"训练计划摘要的数据格式不正确"];
            return;
        }
        NSError *mappingError = nil;
        TrainPlanAbstractDataModel *plan = [MTLJSONAdapter modelOfClass:TrainPlanAbstractDataModel.class
                                                    fromJSONDictionary:responseObject
                                                                 error:&mappingError];
        if (!plan || mappingError) {
            [self showLatestPlanError:@"训练计划摘要解析失败"];
            return;
        }
        self.latestPlan = plan;
        self.latestPlanStatusLabel.hidden = YES;
        [self renderLatestPlan:plan];
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        typeof(self) self = weakSelf;
        if (!self || requestID != self.latestPlanRequestID ||
            ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled)) return;
        self.latestPlanTask = nil;
        NSInteger statusCode = [(NSHTTPURLResponse *)task.response statusCode];
        NSString *message;
        if (statusCode == 401 || statusCode == 403) message = @"训练计划服务鉴权失败";
        else if (statusCode == 404) message = @"训练计划摘要接口不存在";
        else if (statusCode > 0) message = [NSString stringWithFormat:@"训练计划加载失败（HTTP %ld）", (long)statusCode];
        else message = @"无法连接训练计划服务，请确认 Mac 服务已启动并与手机处于同一局域网";
        [self showLatestPlanError:message];
    }];
}

- (void)showLatestPlanError:(NSString *)message {
    self.latestPlanTask = nil;
    [self setLatestPlanLoading:NO];
    self.latestPlanStatusLabel.hidden = NO;
    self.latestPlanStatusLabel.text = message;
    self.latestPlanStatusLabel.textColor = UIColor.systemOrangeColor;
}

- (void)renderLatestPlan:(TrainPlanAbstractDataModel *)plan {
    [self clearLatestPlanContent];

    UIColor *coachColor = [UIColor colorWithRed:0.14 green:0.38 blue:0.25 alpha:1.0];
    UIButton *coachButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *coachConfiguration = [UIButtonConfiguration filledButtonConfiguration];
    coachConfiguration.baseBackgroundColor = coachColor;
    coachConfiguration.baseForegroundColor = UIColor.whiteColor;
    coachConfiguration.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    coachConfiguration.contentInsets = NSDirectionalEdgeInsetsMake(16, 16, 16, 16);
    coachConfiguration.image = [UIImage systemImageNamed:@"waveform.circle.fill"];
    coachConfiguration.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:28
                                                                                                                weight:UIImageSymbolWeightMedium];
    coachConfiguration.imagePadding = 12;
    coachConfiguration.titlePadding = 4;
    coachConfiguration.imagePlacement = NSDirectionalRectEdgeLeading;
    coachConfiguration.titleAlignment = UIButtonConfigurationTitleAlignmentLeading;
    coachConfiguration.title = plan.title.length > 0 ? plan.title : @"未命名训练计划";
    coachConfiguration.subtitle = @"点击进入语音教练";
    coachConfiguration.titleLineBreakMode = NSLineBreakByWordWrapping;
    coachConfiguration.subtitleLineBreakMode = NSLineBreakByWordWrapping;
    coachConfiguration.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *attributes) {
        NSMutableDictionary *updated = [attributes mutableCopy];
        updated[NSFontAttributeName] = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        return updated;
    };
    coachConfiguration.subtitleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *attributes) {
        NSMutableDictionary *updated = [attributes mutableCopy];
        updated[NSFontAttributeName] = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        updated[NSForegroundColorAttributeName] = [UIColor.whiteColor colorWithAlphaComponent:0.82];
        return updated;
    };
    coachButton.configuration = coachConfiguration;
    coachButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    coachButton.accessibilityHint = @"切换到语音教练页面";
    [coachButton addTarget:self action:@selector(openVoiceCoach) forControlEvents:UIControlEventTouchUpInside];
    [coachButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_greaterThanOrEqualTo(84);
    }];
    [self.latestPlanStack addArrangedSubview:coachButton];

    UIStackView *metadata = [[UIStackView alloc] init];
    metadata.axis = UILayoutConstraintAxisHorizontal;
    metadata.spacing = 8;
    metadata.alignment = UIStackViewAlignmentFill;
    metadata.distribution = UIStackViewDistributionFillProportionally;
    if (plan.trainingDate) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
        formatter.dateFormat = @"yyyy年M月d日";
        [metadata addArrangedSubview:[self latestPlanBadgeWithIcon:@"calendar" text:[formatter stringFromDate:plan.trainingDate]]];
    }
    if (plan.durationMinutes.integerValue > 0) {
        [metadata addArrangedSubview:[self latestPlanBadgeWithIcon:@"clock" text:[NSString stringWithFormat:@"%@ 分钟", plan.durationMinutes]]];
    }
    if (metadata.arrangedSubviews.count > 0) [self.latestPlanStack addArrangedSubview:metadata];

    [self.latestPlanStack addArrangedSubview:[self latestPlanListWithTitle:@"训练前准备"
                                                                   icon:@"figure.cooldown"
                                                                  items:plan.preWorkoutContents ?: @[]
                                                              tintColor:UIColor.systemOrangeColor]];
    [self.latestPlanStack addArrangedSubview:[self latestPlanListWithTitle:@"训练后拉伸"
                                                                   icon:@"figure.flexibility"
                                                                  items:plan.postWorkoutStretchContents ?: @[]
                                                              tintColor:UIColor.systemTealColor]];

    NSURL *documentURL = [self validDocumentURLFromString:plan.documentURL];
    if (documentURL) {
        UILabel *documentHeading = [self detailLabel];
        documentHeading.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        documentHeading.textColor = UIColor.labelColor;
        documentHeading.text = @"训练文档";
        [self.latestPlanStack addArrangedSubview:documentHeading];

        UIButton *documentButton = [UIButton buttonWithType:UIButtonTypeSystem];
        UIButtonConfiguration *configuration = [UIButtonConfiguration tintedButtonConfiguration];
        configuration.image = [UIImage systemImageNamed:@"doc.text.fill"];
        configuration.imagePadding = 10;
        configuration.cornerStyle = UIButtonConfigurationCornerStyleMedium;
        configuration.title = @"查看原始训练文档";
        configuration.subtitle = plan.title.length > 0 ? plan.title : @"训练文档";
        configuration.titleAlignment = UIButtonConfigurationTitleAlignmentLeading;
        configuration.titleLineBreakMode = NSLineBreakByWordWrapping;
        configuration.subtitleLineBreakMode = NSLineBreakByTruncatingTail;
        documentButton.configuration = configuration;
        documentButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        documentButton.titleLabel.numberOfLines = 2;
        documentButton.accessibilityHint = @"打开训练文档网页";
        [documentButton addTarget:self action:@selector(openLatestPlanDocument) forControlEvents:UIControlEventTouchUpInside];
        [documentButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.height.mas_greaterThanOrEqualTo(52);
        }];
        [self.latestPlanStack addArrangedSubview:documentButton];
    }
}

- (UIView *)latestPlanBadgeWithIcon:(NSString *)iconName text:(NSString *)text {
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName]];
    icon.tintColor = UIColor.secondaryLabelColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [icon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(16);
    }];
    UILabel *label = [self detailLabel];
    label.text = text;
    label.numberOfLines = 1;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[icon, label]];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 6;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.layoutMargins = UIEdgeInsetsMake(7, 10, 7, 10);
    stack.layoutMarginsRelativeArrangement = YES;
    stack.backgroundColor = UIColor.tertiarySystemGroupedBackgroundColor;
    stack.layer.cornerRadius = 10;
    return stack;
}

- (UIView *)latestPlanListWithTitle:(NSString *)title
                               icon:(NSString *)iconName
                              items:(NSArray<TrainPlanAbstractContentDataModel *> *)items
                          tintColor:(UIColor *)tintColor {
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:iconName]];
    icon.tintColor = tintColor;
    [icon mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.mas_equalTo(20);
    }];
    UILabel *titleLabel = [self detailLabel];
    titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.text = title;
    UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:@[icon, titleLabel]];
    heading.axis = UILayoutConstraintAxisHorizontal;
    heading.spacing = 8;
    heading.alignment = UIStackViewAlignmentCenter;

    UIStackView *container = [[UIStackView alloc] initWithArrangedSubviews:@[heading]];
    container.axis = UILayoutConstraintAxisVertical;
    container.spacing = 8;
    container.layoutMargins = UIEdgeInsetsMake(12, 12, 12, 12);
    container.layoutMarginsRelativeArrangement = YES;
    container.backgroundColor = UIColor.tertiarySystemGroupedBackgroundColor;
    container.layer.cornerRadius = 12;

    if (items.count == 0) {
        UILabel *emptyLabel = [self detailLabel];
        emptyLabel.text = @"暂无内容";
        [container addArrangedSubview:emptyLabel];
    } else {
        [items enumerateObjectsUsingBlock:^(TrainPlanAbstractContentDataModel *item, NSUInteger index, BOOL *stop) {
            UILabel *numberLabel = [[UILabel alloc] init];
            numberLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold];
            numberLabel.textAlignment = NSTextAlignmentCenter;
            numberLabel.textColor = UIColor.whiteColor;
            numberLabel.backgroundColor = tintColor;
            numberLabel.layer.cornerRadius = 11;
            numberLabel.clipsToBounds = YES;
            numberLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)index + 1];
            [numberLabel mas_makeConstraints:^(MASConstraintMaker *make) {
                make.width.height.mas_equalTo(22);
            }];
            UILabel *nameLabel = [self detailLabel];
            nameLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            nameLabel.textColor = UIColor.labelColor;
            nameLabel.text = item.name.length > 0 ? item.name : @"未命名内容";
            UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[numberLabel, nameLabel]];
            row.axis = UILayoutConstraintAxisHorizontal;
            row.spacing = 10;
            row.alignment = UIStackViewAlignmentCenter;
            [row mas_makeConstraints:^(MASConstraintMaker *make) {
                make.height.mas_greaterThanOrEqualTo(34);
            }];
            [container addArrangedSubview:row];
        }];
    }
    return container;
}

- (NSURL *)validDocumentURLFromString:(NSString *)value {
    NSURLComponents *components = [NSURLComponents componentsWithString:value ?: @""];
    NSString *scheme = components.scheme.lowercaseString;
    if (components.host.length == 0 || components.user || components.password ||
        (![scheme isEqualToString:@"https"] && ![scheme isEqualToString:@"http"])) return nil;
    return components.URL;
}

- (void)openLatestPlanDocument {
    NSURL *URL = [self validDocumentURLFromString:self.latestPlan.documentURL];
    if (!URL) return;
    TrainPlanDocumentViewController *controller = [[TrainPlanDocumentViewController alloc] initWithURL:URL
                                                                                                  title:self.latestPlan.title];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)openVoiceCoach {
    if (self.openVoiceCoachHandler && self.latestPlan.itemIdentifier.length > 0) {
        self.openVoiceCoachHandler(self.latestPlan.itemIdentifier, self.latestPlan.title ?: @"");
    }
}

- (void)selectPlan:(UIButton *)sender {
    if (sender.tag < self.weeklyPlans.count && self.planSelectionHandler) {
        self.planSelectionHandler(self.weeklyPlans[sender.tag]);
    }
}

- (void)connectHealth {
    __weak typeof(self) weakSelf = self;
    [self.healthService requestAuthorizationWithCompletion:^{ [weakSelf refreshDisplayedData]; }];
}

- (void)refreshHealth {
    __weak typeof(self) weakSelf = self;
    [self.healthService refreshTodayWithCompletion:^{ [weakSelf refreshDisplayedData]; }];
}

- (void)effortChanged:(UISlider *)slider {
    self.store.effort = round(slider.value);
    self.effortLabel.text = [NSString stringWithFormat:@"主观用力程度：%ld/10", (long)self.store.effort];
}

@end
