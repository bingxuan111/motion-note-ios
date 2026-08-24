#import "PlanViewController.h"
#import <Masonry/Masonry.h>

static NSString * const MNPlanCellReuseIdentifier = @"MNPlanCell";

@interface MNPlanTableViewCell : UITableViewCell

@property (nonatomic, strong) UIImageView *leadingImageView;
@property (nonatomic, strong) UILabel *primaryLabel;
@property (nonatomic, strong) UILabel *secondaryLabel;
@property (nonatomic, strong) UIStackView *textStack;

- (void)resetAppearance;
- (void)setLeadingImage:(nullable UIImage *)image
                    size:(CGSize)size
            cornerRadius:(CGFloat)cornerRadius
             contentMode:(UIViewContentMode)contentMode
               tintColor:(nullable UIColor *)tintColor;

@end

@implementation MNPlanTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _leadingImageView = [[UIImageView alloc] init];
        _leadingImageView.clipsToBounds = YES;
        [_leadingImageView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [_leadingImageView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

        _primaryLabel = [[UILabel alloc] init];
        _primaryLabel.numberOfLines = 1;

        _secondaryLabel = [[UILabel alloc] init];
        _secondaryLabel.numberOfLines = 3;

        _textStack = [[UIStackView alloc] initWithArrangedSubviews:@[_primaryLabel, _secondaryLabel]];
        _textStack.axis = UILayoutConstraintAxisVertical;
        _textStack.alignment = UIStackViewAlignmentFill;
        _textStack.spacing = 4;

        [self.contentView addSubview:_leadingImageView];
        [self.contentView addSubview:_textStack];
        [self setLeadingImage:nil
                        size:CGSizeZero
                cornerRadius:0
                 contentMode:UIViewContentModeScaleAspectFit
                   tintColor:nil];
        [self resetAppearance];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self resetAppearance];
    [self setLeadingImage:nil
                    size:CGSizeZero
            cornerRadius:0
             contentMode:UIViewContentModeScaleAspectFit
               tintColor:nil];
}

- (void)resetAppearance {
    self.accessoryView = nil;
    self.accessoryType = UITableViewCellAccessoryNone;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    self.primaryLabel.text = nil;
    self.primaryLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    self.primaryLabel.textColor = UIColor.labelColor;
    self.primaryLabel.numberOfLines = 1;
    self.secondaryLabel.text = nil;
    self.secondaryLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    self.secondaryLabel.textColor = UIColor.secondaryLabelColor;
    self.secondaryLabel.numberOfLines = 3;
}

- (void)setLeadingImage:(UIImage *)image
                    size:(CGSize)size
            cornerRadius:(CGFloat)cornerRadius
             contentMode:(UIViewContentMode)contentMode
               tintColor:(UIColor *)tintColor {
    BOOL showsImage = image != nil && size.width > 0 && size.height > 0;
    self.leadingImageView.image = image;
    self.leadingImageView.hidden = !showsImage;
    self.leadingImageView.contentMode = contentMode;
    self.leadingImageView.layer.cornerRadius = cornerRadius;
    self.leadingImageView.tintColor = tintColor;

    [self.leadingImageView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).offset(16);
        make.centerY.equalTo(self.contentView);
        make.size.mas_equalTo(showsImage ? size : CGSizeZero);
    }];
    [self.textStack mas_remakeConstraints:^(MASConstraintMaker *make) {
        if (showsImage) {
            make.left.equalTo(self.leadingImageView.mas_right).offset(14);
        } else {
            make.left.equalTo(self.contentView).offset(16);
        }
        make.right.equalTo(self.contentView).offset(-16);
        make.centerY.equalTo(self.contentView);
        make.top.greaterThanOrEqualTo(self.contentView).offset(10);
        make.bottom.lessThanOrEqualTo(self.contentView).offset(-10);
    }];
}

@end

@interface PlanViewController ()
@property (nonatomic, strong) WorkoutStore *store;
@end

@implementation PlanViewController

- (instancetype)initWithWorkoutStore:(WorkoutStore *)store {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _store = store;
        _weeklyPlans = @[];
        _activeWeeklyPlanID = @"";
        self.title = @"Motion Note";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"计划"
                                                       image:[UIImage systemImageNamed:@"figure.strengthtraining.traditional"]
                                                         tag:0];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView registerClass:MNPlanTableViewCell.class forCellReuseIdentifier:MNPlanCellReuseIdentifier];
    self.tableView.rowHeight = 72;
    self.tableView.estimatedRowHeight = 0;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16);
}

- (void)setWeeklyPlans:(NSArray<ImportedPlan *> *)weeklyPlans {
    _weeklyPlans = [weeklyPlans copy];
    [self.tableView reloadData];
}

- (void)setActiveWeeklyPlanID:(NSString *)activeWeeklyPlanID {
    _activeWeeklyPlanID = [activeWeeklyPlanID copy];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 2;
        case 1: return 1;
        case 2: return MAX(self.weeklyPlans.count, 1);
        case 3: return self.store.steps.count + 1;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 1: return @"动力充值";
        case 2: return @"本周课表";
        case 3: return @"今日训练";
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 2) {
        return @"保留最近两节私教课；选中的课程会作为今日训练与语音教练的依据。";
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return indexPath.row == 0 ? 96 : 92;
    }
    if (indexPath.section == 1) {
        return 132;
    }
    if (indexPath.section == 2) {
        return self.weeklyPlans.count == 0 ? 64 : 84;
    }
    if (indexPath.section == 3) {
        return indexPath.row == 0 ? 64 : 116;
    }
    return 72;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MNPlanTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MNPlanCellReuseIdentifier forIndexPath:indexPath];
    [cell resetAppearance];
    [cell setLeadingImage:nil
                    size:CGSizeZero
            cornerRadius:0
             contentMode:UIViewContentModeScaleAspectFit
               tintColor:nil];

    if (indexPath.section == 0 && indexPath.row == 0) {
        cell.primaryLabel.text = @"零件充电站";
        cell.primaryLabel.font = [UIFont systemFontOfSize:27 weight:UIFontWeightBold];
        cell.secondaryLabel.text = @"给身体的小零件，充个电。";
        UIImage *image = [UIImage imageNamed:@"motion-note-mark"] ?: [UIImage systemImageNamed:@"dumbbell.fill"];
        [cell setLeadingImage:image
                        size:CGSizeMake(64, 64)
                cornerRadius:16
                 contentMode:UIViewContentModeScaleAspectFit
                   tintColor:UIColor.systemGreenColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (indexPath.section == 0) {
        cell.primaryLabel.text = @"今天来练哪个小零件？";
        cell.primaryLabel.font = [UIFont systemFontOfSize:21 weight:UIFontWeightBold];
        cell.secondaryLabel.text = [NSString stringWithFormat:@"%@ · %ld 分钟\n周三 · 训练日 · 不卷，练一下", self.store.goal, (long)self.store.totalMinutes];
        cell.secondaryLabel.numberOfLines = 2;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.section == 1) {
        cell.primaryLabel.text = @"不用等状态满格，\n动起来，电量就会回来。";
        cell.primaryLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
        cell.primaryLabel.numberOfLines = 2;
        cell.secondaryLabel.text = @"今天只要完成热身，也算打卡。";
        UIImage *image = [UIImage imageNamed:@"motivation-hero"] ?: [UIImage systemImageNamed:@"figure.strengthtraining.traditional"];
        [cell setLeadingImage:image
                        size:CGSizeMake(96, 96)
                cornerRadius:14
                 contentMode:UIViewContentModeScaleAspectFill
                   tintColor:UIColor.systemOrangeColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (indexPath.section == 2) {
        if (self.weeklyPlans.count == 0) {
            cell.primaryLabel.text = @"飞书中的私教课会自动同步到这里。";
            cell.primaryLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            cell.primaryLabel.textColor = UIColor.secondaryLabelColor;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            ImportedPlan *plan = self.weeklyPlans[indexPath.row];
            BOOL selected = [plan.identifier isEqualToString:self.activeWeeklyPlanID];
            cell.primaryLabel.text = [NSString stringWithFormat:@"第 %ld 练 · %@%@", (long)indexPath.row + 1, plan.title, selected ? @"（当前依据）" : @""];
            cell.secondaryLabel.text = plan.preview;
            cell.secondaryLabel.numberOfLines = 2;
            UIImage *image = [UIImage systemImageNamed:selected ? @"checkmark.circle.fill" : @"circle"];
            [cell setLeadingImage:image
                            size:CGSizeMake(24, 24)
                    cornerRadius:0
                     contentMode:UIViewContentModeScaleAspectFit
                       tintColor:selected ? UIColor.systemGreenColor : UIColor.secondaryLabelColor];
        }
    } else {
        if (indexPath.row == 0) {
            cell.primaryLabel.text = @"训练目标";
            cell.secondaryLabel.text = self.store.goal;
            cell.secondaryLabel.numberOfLines = 1;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            WorkoutStep *step = self.store.steps[indexPath.row - 1];
            cell.primaryLabel.text = step.name;
            cell.secondaryLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
            cell.secondaryLabel.text = [NSString stringWithFormat:@"%@ · %ld 分钟\n%@\n注意：%@", step.phaseName, (long)step.minutes, step.prescription, step.cue];
            cell.secondaryLabel.numberOfLines = 3;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0 && indexPath.row == 1) {
        if (self.startWorkoutHandler) self.startWorkoutHandler();
    } else if (indexPath.section == 2 && self.weeklyPlans.count > 0) {
        if (self.planSelectionHandler) self.planSelectionHandler(self.weeklyPlans[indexPath.row]);
    } else if (indexPath.section == 3 && indexPath.row == 0) {
        [self presentGoalPicker];
    }
}

- (void)presentGoalPicker {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"训练目标"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray<NSString *> *goals = @[@"全身力量", @"下肢力量", @"上肢力量", @"轻度恢复"];
    __weak typeof(self) weakSelf = self;
    for (NSString *goal in goals) {
        [sheet addAction:[UIAlertAction actionWithTitle:goal style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            weakSelf.store.goal = goal;
            [weakSelf.tableView reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMaxY(self.view.bounds), 1, 1);
    [self presentViewController:sheet animated:YES completion:nil];
}

@end
