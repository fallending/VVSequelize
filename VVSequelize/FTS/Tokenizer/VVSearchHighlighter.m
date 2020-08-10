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
@property (nonatomic, strong) NSArray<VVToken *> *kwTokens;
@end

@implementation VVSearchHighlighter

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
    _kwTokens = [_enumerator enumerate:_keyword.UTF8String mask:mask];
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

    match = [self highlight:source comparison:comparison cSource:cSource keyword:keyword lv1:VVMatchLV1_Origin];
    return match;
}

- (VVResultMatch *)highlight:(NSString *)source
                  comparison:(NSString *)comparison
                     cSource:(const char *)cSource
                     keyword:(NSString *)keyword
                         lv1:(VVMatchLV1)lv1
{
    VVResultMatch *nomatch = [[VVResultMatch alloc] init];
    nomatch.source = source;

    VVResultMatch *match = [self highlightUsingRegex:source comparison:comparison keyword:keyword lv1:lv1];
    if (match) return match;

    match = [self highlightUsingToken:source cSource:cSource lv1:lv1];
    if (match) return match;

    return nomatch;
}

- (VVResultMatch *)highlightUsingRegex:(NSString *)source
                            comparison:(NSString *)comparison
                               keyword:(NSString *)keyword
                                   lv1:(VVMatchLV1)lv1
{
    VVResultMatch *match = [[VVResultMatch alloc] init];
    match.lv1 = lv1;
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
    match.lv3 = lv1 == VVMatchLV1_Origin ? VVMatchLV3_High : VVMatchLV3_Medium;

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
                                   lv1:(VVMatchLV1)lv1
{
    NSArray *keywordTokens = self.kwTokens;
    if (keywordTokens.count == 0) return nil;

    VVTokenMask mask = _mask & ~VVTokenMaskSyllable;
    NSArray<VVToken *> *sourceTokens = [_enumerator enumerate:cSource mask:mask];
    if (sourceTokens.count == 0) return nil;

    NSMutableDictionary *originMap = [NSMutableDictionary dictionary];
    NSMutableDictionary *colocatedMap = [NSMutableDictionary dictionary];
    for (VVToken *token in sourceTokens) {
        NSMutableDictionary *map = token.colocated ? colocatedMap : originMap;
        NSMutableSet *set = map[token.token];
        if (!set) {
            set = [NSMutableSet set];
            map[token.token] = set;
        }
        [set addObject:token];
    }
    NSMutableSet *kwtks = [NSMutableSet set];
    for (VVToken *token in keywordTokens) {
        [kwtks addObject:token.token];
    }

    NSMutableSet *matchedSet = [NSMutableSet set];
    for (NSString *tk in kwtks) {
        NSMutableSet *set = originMap[tk];
        if (set) [matchedSet addObjectsFromArray:set.allObjects];
    }
    if (matchedSet.count == 0) {
        for (NSString *tk in kwtks) {
            NSMutableSet *set = colocatedMap[tk];
            if (set) [matchedSet addObjectsFromArray:set.allObjects];
        }
    }
    if (matchedSet.count == 0) return nil;

    NSArray *array = [VVToken sortedTokens:matchedSet.allObjects];

    if (self.quantity > 0 && array.count > self.quantity) {
        array = [array subarrayWithRange:NSMakeRange(0, self.quantity)];
    }

    VVResultMatch *match = [[VVResultMatch alloc] init];
    match.lv1 = lv1;
    match.source = source;

    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] initWithString:source attributes:self.normalAttributes];
    NSMutableArray *ranges = [NSMutableArray arrayWithCapacity:array.count];
    for (VVToken *token in array) {
        NSString *s1 = [[NSString alloc] initWithBytes:cSource length:token.start encoding:NSUTF8StringEncoding] ? : @"";
        NSString *sk = [[NSString alloc] initWithBytes:cSource + token.start length:token.end - token.start encoding:NSUTF8StringEncoding] ? : @"";
        NSRange range = NSMakeRange(s1.length, sk.length);
        [attrText addAttributes:self.highlightAttributes range:range];
        [ranges addObject:[NSValue valueWithRange:range]];
    }

    VVToken *first = array.firstObject;
    match.attrText = attrText;
    match.ranges = ranges;
    match.lv2 = first.start == 0 ? VVMatchLV2_Prefix : VVMatchLV2_NonPrefix;
    match.lv3 = first.colocated ? VVMatchLV3_Low : VVMatchLV3_Medium;

    return match;
}

@end
