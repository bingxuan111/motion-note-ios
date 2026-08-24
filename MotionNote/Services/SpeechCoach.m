#import "SpeechCoach.h"
#import <AVFoundation/AVFoundation.h>
#import "Models.h"

@interface SpeechCoach ()
@property (nonatomic, strong) AVSpeechSynthesizer *synthesizer;
@end

@implementation SpeechCoach

- (instancetype)init {
    self = [super init];
    if (self) {
        _synthesizer = [[AVSpeechSynthesizer alloc] init];
    }
    return self;
}

- (void)speakStep:(WorkoutStep *)step {
    [self.synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    NSString *text = [NSString stringWithFormat:@"现在是%@。%@，%@。注意，%@", step.phaseName, step.name, step.prescription, step.cue];
    AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:text];
    utterance.voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"zh-CN"];
    utterance.rate = 0.48;
    [self.synthesizer speakUtterance:utterance];
}

@end
