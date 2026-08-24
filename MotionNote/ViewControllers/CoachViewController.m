#import "CoachViewController.h"
#import "Models.h"
#import "SpeechCoach.h"
#import <Masonry/Masonry.h>

@interface CoachViewController ()
@property (nonatomic, strong) WorkoutStore *store;
@property (nonatomic, strong) SpeechCoach *speechCoach;
@property (nonatomic, assign) NSInteger currentStep;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *phaseLabel;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *prescriptionLabel;
@property (nonatomic, strong) UILabel *cueLabel;
@property (nonatomic, strong) UIButton *nextButton;
@end

@implementation CoachViewController

- (instancetype)initWithWorkoutStore:(WorkoutStore *)store speechCoach:(SpeechCoach *)speechCoach {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _store = store;
        _speechCoach = speechCoach;
        self.title = @"语音教练";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"语音教练" image:[UIImage systemImageNamed:@"waveform"] tag:1];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [self buildInterface];
    [self refreshStep];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshStep];
}

- (void)buildInterface {
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.tintColor = UIColor.systemOrangeColor;
    self.phaseLabel = [self labelWithStyle:UIFontTextStyleSubheadline alignment:NSTextAlignmentCenter];
    self.phaseLabel.textColor = UIColor.secondaryLabelColor;
    self.nameLabel = [self labelWithStyle:UIFontTextStyleLargeTitle alignment:NSTextAlignmentCenter];
    self.nameLabel.font = [UIFont systemFontOfSize:32 weight:UIFontWeightBold];
    self.prescriptionLabel = [self labelWithStyle:UIFontTextStyleTitle3 alignment:NSTextAlignmentCenter];
    self.cueLabel = [self labelWithStyle:UIFontTextStyleBody alignment:NSTextAlignmentCenter];
    self.cueLabel.backgroundColor = [UIColor.systemOrangeColor colorWithAlphaComponent:0.12];
    self.cueLabel.layer.cornerRadius = 16;
    self.cueLabel.layer.masksToBounds = YES;

    UIButton *speakButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [speakButton setTitle:@"听取语音指导" forState:UIControlStateNormal];
    speakButton.configuration = [UIButtonConfiguration filledButtonConfiguration];
    [speakButton addTarget:self action:@selector(speakCurrentStep) forControlEvents:UIControlEventTouchUpInside];

    self.nextButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.nextButton.configuration = [UIButtonConfiguration borderedButtonConfiguration];
    [self.nextButton addTarget:self action:@selector(goToNextStep) forControlEvents:UIControlEventTouchUpInside];

    UILabel *warning = [self labelWithStyle:UIFontTextStyleFootnote alignment:NSTextAlignmentCenter];
    warning.textColor = UIColor.secondaryLabelColor;
    warning.text = @"若出现尖锐疼痛、头晕或异常不适，请停止训练并寻求专业建议。";

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.progressView, self.phaseLabel, self.nameLabel, self.prescriptionLabel,
        self.cueLabel, speakButton, self.nextButton, warning,
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 20;
    [self.view addSubview:stack];
    [stack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view.mas_safeAreaLayoutGuideLeft).offset(24);
        make.right.equalTo(self.view.mas_safeAreaLayoutGuideRight).offset(-24);
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(28);
    }];
    [self.cueLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.greaterThanOrEqualTo(@72);
    }];
}

- (UILabel *)labelWithStyle:(UIFontTextStyle)style alignment:(NSTextAlignment)alignment {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont preferredFontForTextStyle:style];
    label.textAlignment = alignment;
    label.numberOfLines = 0;
    return label;
}

- (void)refreshStep {
    if (!self.isViewLoaded || self.store.steps.count == 0) return;
    self.currentStep = MIN(self.currentStep, (NSInteger)self.store.steps.count - 1);
    WorkoutStep *step = self.store.steps[self.currentStep];
    self.progressView.progress = (float)(self.currentStep + 1) / (float)self.store.steps.count;
    self.phaseLabel.text = [NSString stringWithFormat:@"第 %ld / %ld 项 · %@", (long)self.currentStep + 1, (long)self.store.steps.count, step.phaseName];
    self.nameLabel.text = step.name;
    self.prescriptionLabel.text = step.prescription;
    self.cueLabel.text = [NSString stringWithFormat:@"“%@”", step.cue];
    NSString *buttonTitle = self.currentStep == self.store.steps.count - 1 ? @"完成训练" : @"下一步";
    [self.nextButton setTitle:buttonTitle forState:UIControlStateNormal];
}

- (void)speakCurrentStep {
    [self.speechCoach speakStep:self.store.steps[self.currentStep]];
}

- (void)goToNextStep {
    self.currentStep = MIN(self.currentStep + 1, (NSInteger)self.store.steps.count - 1);
    [self refreshStep];
    [self speakCurrentStep];
}

- (void)resetToFirstStep {
    self.currentStep = 0;
    [self refreshStep];
}

@end
