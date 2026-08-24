#import "RecordViewController.h"
#import "FeishuService.h"
#import "HealthService.h"
#import <Masonry/Masonry.h>

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
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    [self buildInterface];
    [self refreshDisplayedData];
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
