//
//  VVFtsHighlighter.m
//  VVSequelize
//
//  Created by Valo on 2019/8/20.
//

#import "VVSearchHighlighter.h"
#import "VVDatabase+FTS.h"
#import "NSString+Tokenizer.h"

#define _VVMatchPinyinLen 30
#define _VVMatchHLRange   256

@interface VVResultMatch ()
@property (nonatomic, assign) VVMatchLV1 lv1;
@property (nonatomic, assign) VVMatchLV2 lv2;
@property (nonatomic, assign) VVMatchLV3 lv3;
@property (nonatomic, strong) NSArray *ranges;
@end

@implementation VVResultMatch
@synthesize lowerWeight = _lowerWeight;
@synthesize upperWeight = _upperWeight;
@synthesize weight = _weight;

- (UInt64)upperWeight
{
    if (_upperWeight == 0 && _ranges.count > 0) {
        _upperWeight = (UInt64)(_lv1 & 0xF) << 28 | (UInt64)(_lv2 & 0xF) << 24 | (UInt64)(_lv3 & 0xF) << 20;
    }
    return _upperWeight;
}

- (UInt64)lowerWeight
{
    if (_upperWeight == 0 && _ranges.count > 0) {
        NSRange range = [_ranges.firstObject rangeValue];
        UInt64 loc = ~range.location & 0xFFFF;
        UInt64 rate = ((UInt64)range.length << 32) / _source.length;
        _lowerWeight = (UInt64)(loc & 0xFFFF) << 16 | (UInt64)(rate & 0xFFFF) << 0;
    }
    return _upperWeight;
}

- (UInt64)weight
{
    if (_weight == 0 && _ranges.count > 0) {
        _weight = self.upperWeight << 32 | self.lowerWeight;
    }
    return _weight;
}

- (NSComparisonResult)compare:(VVResultMatch *)other
{
    return self.weight == other.weight ? NSOrderedSame : self.weight > other.weight ? NSOrderedAscending : NSOrderedDescending;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"[%@|%@|%@|%@|0x%llx]: %@", @(_lv1), @(_lv2), @(_lv3), _ranges.firstObject, self.weight, [_attrText.description stringByReplacingOccurrencesOfString:@"\n" withString:@""]];
}

@end

@interface VVSearchHighlighter ()
@property (nonatomic, strong) NSArray<NSSet<NSString *> *> *kwTokens;
@end

@implementation VVSearchHighlighter

+ (NSArray *)fold:(NSArray<VVToken *> *)tokens
{
    NSMutableArray *foldedTokens = [NSMutableArray array];
    NSMutableArray *foldWords = [NSMutableArray array];
    NSMutableDictionary *tokenMap = [NSMutableDictionary dictionary];
    NSMutableSet *words = [NSMutableSet set];
    VVToken *last = nil;
    for (VVToken *tk in tokens) {
        if (last != nil && tk.start != last.start) {
            [foldedTokens addObject:tokenMap];
            [foldWords addObject:words];
            tokenMap = [NSMutableDictionary dictionary];
            words = [NSMutableSet set];
        }
        tokenMap[tk.token] = tk;
        [words addObject:tk.token];
        last = tk;
    }
    [foldedTokens addObject:tokenMap];
    [foldWords addObject:words];
    return @[foldedTokens, foldWords];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithKeyword:(NSString *)keyword
{
    self = [super init];
    if (self) {
        [self setup];
        self.keyword = keyword;
    }
    return self;
}

- (instancetype)initWithKeyword:(NSString *)keyword orm:(VVOrm *)orm
{
    self = [super init];
    if (self) {
        NSAssert(orm.config.fts && orm.config.ftsTokenizer.length > 0, @"Invalid fts orm!");
        [self setup];

        NSArray *components = [orm.config.ftsTokenizer componentsSeparatedByString:@" "];
        if (components.count > 0) {
            NSString *tokenizer = components[0];
            self.enumerator = [orm.vvdb enumeratorForTokenizer:tokenizer] ? : VVTokenSequelizeEnumerator.class;
        }
        if (components.count > 1) {
            NSString *mask = components[1];
            self.mask = (VVTokenMask)mask.longLongValue;
        }
        self.keyword = keyword;
    }
    return self;
}

- (void)setup
{
    _enumerator = VVTokenSequelizeEnumerator.class;
    _mask = VVTokenMaskDefault;
}

- (void)setMask:(VVTokenMask)mask
{
    _mask = mask;
    [self refreshKeywordTokens];
}

- (void)setKeyword:(NSString *)keyword
{
    _keyword = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self refreshKeywordTokens];
}

- (void)refreshKeywordTokens
{
    if (_keyword.length == 0) return;
    VVTokenMask mask = _mask | VVTokenMaskSyllable;
    NSArray<VVToken *> *tokens = [VVTokenSequelizeEnumerator enumerate:_keyword.UTF8String mask:mask];
    _kwTokens = [VVSearchHighlighter fold:tokens].lastObject;
}

- (NSDictionary<NSAttributedStringKey, id> *)normalAttributes {
    if (!_normalAttributes) {
        _normalAttributes = @{};
    }
    return _normalAttributes;
}

- (NSDictionary<NSAttributedStringKey, id> *)highlightAttributes {
    if (!_highlightAttributes) {
        _highlightAttributes = @{};
    }
    return _highlightAttributes;
}

- (NSAttributedString *)trim:(NSAttributedString *)matchedText maxLength:(NSUInteger)maxLen
{
    return [matchedText attributedStringByTrimmingToLength:maxLen withAttributes:self.highlightAttributes];
}

//MARK: - highlight search result
- (NSArray<VVResultMatch *> *)highlight:(NSArray<NSObject *> *)objects field:(NSString *)field
{
    NSAssert(_keyword.length > 0 && field.length > 0, @"Invalid highlight parameters");
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:objects.count];
    for (NSObject *object in objects) {
        NSString *source = [object valueForKey:field];
        BOOL valid = [source isKindOfClass:NSString.class] && source.length > 0;
        if (!valid) source = @"";
        VVResultMatch *match = [self highlight:source];
        [results addObject:match];
    }
    return results;
}

- (VVResultMatch *)highlight:(NSString *)source
{
    VVResultMatch *match = [[VVResultMatch alloc] init];
    match.source = source;
    if (source.length == 0 || self.keyword.length == 0) return match;

    NSString *keyword = _keyword.lowercaseString.simplifiedChineseString;
    NSString *temp = source.length > _VVMatchHLRange ? [source substringToIndex:_VVMatchHLRange] : source;
    NSString *comparison = temp.matchingPattern.simplifiedChineseString;

    const char *cSource = comparison.cLangString;
    long nText = (long)strlen(cSource);
    if (nText == 0) return match;

    match = [self highlight:source comparison:comparison cSource:cSource keyword:keyword];
    return match;
}

- (VVResultMatch *)highlight:(NSString *)source
                  comparison:(NSString *)comparison
                     cSource:(const char *)cSource
                     keyword:(NSString *)keyword
{
    VVResultMatch *nomatch = [[VVResultMatch alloc] init];
    nomatch.source = source;

    VVResultMatch *match = [self highlightUsingRegex:source comparison:comparison keyword:keyword];
    if (match) return match;

    match = [self highlightUsingToken:source cSource:cSource];
    if (match) return match;

    return nomatch;
}

- (VVResultMatch *)highlightUsingRegex:(NSString *)source
                            comparison:(NSString *)comparison
                               keyword:(NSString *)keyword
{
    VVResultMatch *match = [[VVResultMatch alloc] init];
    match.source = source;

    NSString *pattern = keyword.regexPattern;
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
    NSArray<NSTextCheckingResult *> *results = [expression matchesInString:comparison options:0 range:NSMakeRange(0, comparison.length)];
    if (results.count == 0) return nil;

    if (self.quantity > 0 && results.count > self.quantity) {
        results = [results subarrayWithRange:NSMakeRange(0, self.quantity)];
    }

    NSRange found = results.firstObject.range;
    if (found.location == 0 && found.length == source.length) {
        match.lv2 = VVMatchLV2_Full;
    } else if (found.location == 0 && found.length < source.length) {
        match.lv2 = VVMatchLV2_Prefix;
    } else {
        match.lv2 = VVMatchLV2_NonPrefix;
    }
    match.lv1 = VVMatchLV1_Origin;
    match.lv3 = VVMatchLV3_High;

    NSMutableArray *ranges = [NSMutableArray arrayWithCapacity:results.count];
    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] initWithString:source attributes:self.normalAttributes];
    for (NSTextCheckingResult *result in results) {
        [ranges addObject:[NSValue valueWithRange:result.range]];
        [attrText addAttributes:self.highlightAttributes range:result.range];
    }
    match.ranges = ranges;
    match.attrText = attrText;
    return match;
}

- (VVResultMatch *)highlightUsingToken:(NSString *)source
                               cSource:(const char *)cSource
{
    if (self.kwTokens.count == 0) return nil;
    VVTokenMask mask = _mask & ~VVTokenMaskSyllable;
    NSArray<VVToken *> *sourceTokens = [VVTokenSequelizeEnumerator enumerate:cSource mask:mask];
    if (sourceTokens.count == 0) return nil;
    NSArray *folded = [VVSearchHighlighter fold:sourceTokens];
    NSArray<NSDictionary<NSString *, VVToken *> *> *foldedTokens = folded.firstObject;
    NSArray<NSSet<NSString *> *> *foldedWords = folded.lastObject;

    int colocated = 0;
    NSMutableSet *matchedSet = [NSMutableSet set];
    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] initWithString:source attributes:self.normalAttributes];
    NSMutableArray *ranges = [NSMutableArray array];
    for (NSUInteger i = 0; i < foldedWords.count; i++) {
        NSUInteger j = 0;
        NSUInteger k = i;
        while (j < self.kwTokens.count && k < foldedWords.count) {
            NSSet<NSString *> *kwset = self.kwTokens[j];
            NSSet<NSString *> *set = foldedWords[k];
            if ([set intersectsSet:kwset]) {
                NSMutableSet<NSString *> *mset = [set mutableCopy];
                [mset intersectSet:kwset];
                NSDictionary *dic = foldedTokens[k];
                VVToken *tk = dic[mset.anyObject];
                if (colocated != tk.colocated) {
                    colocated = colocated == 0 ? tk.colocated : 0xF;
                }
                j++; k++;
            } else {
                break;
            }
        }
        if (j == self.kwTokens.count) {
            NSRange range = NSMakeRange(i, j);
            [attrText addAttributes:self.highlightAttributes range:range];
            [ranges addObject:[NSValue valueWithRange:range]];
            if (self.quantity > 0 && ranges.count > self.quantity) break;
        }
    }
    if (ranges.count == 0) return nil;
    NSRange first = [ranges.firstObject rangeValue];
    VVResultMatch *match = [[VVResultMatch alloc] init];
    match.source = source;
    match.ranges = ranges;
    match.attrText = attrText;
    match.lv1 = colocated == 0 ? VVMatchLV1_Origin : colocated == 1 ? VVMatchLV1_Fulls : colocated == 2 ? VVMatchLV1_Firsts : VVMatchLV1_Mix;
    match.lv2 = first.location == 0 ? VVMatchLV2_Prefix : VVMatchLV2_NonPrefix;
    match.lv3 = colocated == 0 ? VVMatchLV3_High : colocated > 2 ? VVMatchLV3_Low : VVMatchLV3_Medium;
    return match;
}

@end
