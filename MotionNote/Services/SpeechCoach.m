#import "SpeechCoach.h"
#import <AVFoundation/AVFoundation.h>

@interface SpeechCoach () <AVSpeechSynthesizerDelegate>
@property (nonatomic, strong) AVSpeechSynthesizer *synthesizer;
@property (nonatomic, copy) NSString *fullText;
@property (nonatomic, strong) NSMapTable<AVSpeechUtterance *, NSValue *> *utteranceRanges;
@property (nonatomic, strong, nullable) AVSpeechUtterance *lastUtterance;
@end

@implementation SpeechCoach

- (instancetype)init {
    self = [super init];
    if (self) {
        _synthesizer = [[AVSpeechSynthesizer alloc] init];
        _synthesizer.delegate = self;
        _fullText = @"";
        _utteranceRanges = [NSMapTable strongToStrongObjectsMapTable];
    }
    return self;
}

- (void)speakText:(NSString *)text {
    [self speakText:text fromProgress:0];
}

- (void)speakText:(NSString *)text fromProgress:(float)progress {
    NSString *spokenText = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (spokenText.length == 0) return;
    self.fullText = [self normalizedSpeechText:spokenText];
    NSUInteger location = [self locationForProgress:progress];
    [self startSpeakingAtLocation:location];
}

- (void)seekToProgress:(float)progress {
    if (self.fullText.length == 0) return;
    if (progress >= 1.0f) {
        [self stopSpeaking];
        [self notifyProgress:1.0f];
        if (self.completionHandler) self.completionHandler();
        return;
    }
    [self startSpeakingAtLocation:[self locationForProgress:progress]];
}

- (void)stopSpeaking {
    self.lastUtterance = nil;
    [self.utteranceRanges removeAllObjects];
    [self.synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
}

- (BOOL)isSpeaking {
    return self.lastUtterance != nil && self.synthesizer.isSpeaking;
}

- (NSUInteger)locationForProgress:(float)progress {
    float clampedProgress = MIN(MAX(progress, 0.0f), 1.0f);
    if (clampedProgress >= 1.0f || self.fullText.length == 0) return self.fullText.length;
    NSUInteger location = MIN((NSUInteger)(clampedProgress * self.fullText.length), self.fullText.length - 1);
    return [self.fullText rangeOfComposedCharacterSequenceAtIndex:location].location;
}

- (void)startSpeakingAtLocation:(NSUInteger)location {
    NSUInteger safeLocation = MIN(location, self.fullText.length);
    if (safeLocation >= self.fullText.length) {
        [self stopSpeaking];
        [self notifyProgress:1.0f];
        if (self.completionHandler) self.completionHandler();
        return;
    }

    [self stopSpeaking];
    NSArray<NSValue *> *paragraphRanges = [self paragraphRangesFromLocation:safeLocation];
    if (paragraphRanges.count == 0) {
        [self notifyProgress:1.0f];
        if (self.completionHandler) self.completionHandler();
        return;
    }

    [self notifyProgress:(float)safeLocation / (float)self.fullText.length];
    AVSpeechSynthesisVoice *preferredVoice = [self preferredChineseVoice];
    [paragraphRanges enumerateObjectsUsingBlock:^(NSValue *rangeValue, NSUInteger index, BOOL *stop) {
        NSRange range = rangeValue.rangeValue;
        NSString *paragraph = [self.fullText substringWithRange:range];
        AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:paragraph];
        utterance.voice = preferredVoice;
        utterance.rate = 0.44;
        utterance.pitchMultiplier = 1.04;
        utterance.postUtteranceDelay = index + 1 < paragraphRanges.count ? 0.45 : 0;
        [self.utteranceRanges setObject:rangeValue forKey:utterance];
        if (index + 1 == paragraphRanges.count) self.lastUtterance = utterance;
        [self.synthesizer speakUtterance:utterance];
    }];
}

- (AVSpeechSynthesisVoice *)preferredChineseVoice {
    AVSpeechSynthesisVoice *bestVoice = nil;
    NSInteger bestScore = NSIntegerMin;
    for (AVSpeechSynthesisVoice *voice in AVSpeechSynthesisVoice.speechVoices) {
        if ([voice.language caseInsensitiveCompare:@"zh-CN"] != NSOrderedSame) continue;

        NSInteger score = 0;
        switch (voice.quality) {
            case AVSpeechSynthesisVoiceQualityPremium:
                score = 300;
                break;
            case AVSpeechSynthesisVoiceQualityEnhanced:
                score = 200;
                break;
            default:
                score = 100;
                break;
        }
        if (voice.gender == AVSpeechSynthesisVoiceGenderFemale) score += 20;
        else if (voice.gender == AVSpeechSynthesisVoiceGenderMale) score += 10;

        if (!bestVoice || score > bestScore) {
            bestVoice = voice;
            bestScore = score;
        }
    }
    return bestVoice ?: [AVSpeechSynthesisVoice voiceWithLanguage:@"zh-CN"];
}

- (NSString *)normalizedSpeechText:(NSString *)text {
    NSString *normalized = [text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    NSArray<NSArray<NSString *> *> *replacements = @[
        @[@"(?i)(?<![A-Za-z])min(?![A-Za-z])", @"分钟"],
        @[@"([0-9]+(?:\\.[0-9]+)?)\\s*[-–—~～]\\s*([0-9]+(?:\\.[0-9]+)?)\\s*次\\s*/\\s*组", @"$1到$2次每组"],
        @[@"次\\s*/\\s*组", @"次每组"],
    ];
    for (NSArray<NSString *> *replacement in replacements) {
        NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:replacement.firstObject options:0 error:nil];
        normalized = [expression stringByReplacingMatchesInString:normalized
                                                           options:0
                                                             range:NSMakeRange(0, normalized.length)
                                                      withTemplate:replacement.lastObject];
    }
    return normalized;
}

- (NSArray<NSValue *> *)paragraphRangesFromLocation:(NSUInteger)location {
    NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
    NSCharacterSet *newlines = NSCharacterSet.newlineCharacterSet;
    NSCharacterSet *trimSet = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    NSUInteger cursor = MIN(location, self.fullText.length);
    while (cursor < self.fullText.length) {
        NSRange searchRange = NSMakeRange(cursor, self.fullText.length - cursor);
        NSRange newlineRange = [self.fullText rangeOfCharacterFromSet:newlines options:0 range:searchRange];
        NSUInteger paragraphEnd = newlineRange.location == NSNotFound ? self.fullText.length : newlineRange.location;
        NSRange rawRange = NSMakeRange(cursor, paragraphEnd - cursor);
        NSString *rawParagraph = [self.fullText substringWithRange:rawRange];
        NSString *paragraph = [rawParagraph stringByTrimmingCharactersInSet:trimSet];
        if (paragraph.length > 0) {
            NSRange trimmedRange = [rawParagraph rangeOfString:paragraph];
            [ranges addObject:[NSValue valueWithRange:NSMakeRange(cursor + trimmedRange.location, trimmedRange.length)]];
        }
        if (newlineRange.location == NSNotFound) break;
        cursor = NSMaxRange(newlineRange);
    }
    return ranges;
}

- (void)notifyProgress:(float)progress {
    if (self.progressHandler) self.progressHandler(MIN(MAX(progress, 0.0f), 1.0f));
}

#pragma mark - AVSpeechSynthesizerDelegate

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer
 willSpeakRangeOfSpeechString:(NSRange)characterRange
                 utterance:(AVSpeechUtterance *)utterance {
    NSValue *rangeValue = [self.utteranceRanges objectForKey:utterance];
    if (!rangeValue || self.fullText.length == 0) return;
    NSUInteger spokenLocation = MIN(rangeValue.rangeValue.location + NSMaxRange(characterRange), self.fullText.length);
    [self notifyProgress:(float)spokenLocation / (float)self.fullText.length];
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
    if (![self.utteranceRanges objectForKey:utterance]) return;
    [self.utteranceRanges removeObjectForKey:utterance];
    if (utterance != self.lastUtterance) return;
    self.lastUtterance = nil;
    [self.utteranceRanges removeAllObjects];
    [self notifyProgress:1.0f];
    if (self.completionHandler) self.completionHandler();
}

@end
