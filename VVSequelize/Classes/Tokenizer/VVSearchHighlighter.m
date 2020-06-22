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
@property (nonatomic, strong) NSArray<VVToken *> *pyKwTokens;
@property (nonatomic, strong) NSArray<VVToken *> *fzKwTokens;
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

        self.option = VVMatchOptionPinyin | VVMatchOptionToken;

        NSArray *components = [orm.config.ftsTokenizer componentsSeparatedByString:@" "];
        if (components.count > 0) {
            NSString *tokenizer = components[0];
            self.method = [orm.vvdb methodForTokenizer:tokenizer];
        }
        if (components.count > 1) {
            NSString *mask = components[1];
            self.mask = mask.longLongValue;
        }
        self.keyword = keyword;
    }
    return self;
}

- (void)setup {
    _option = VVMatchOptionDefault;
    _method = VVTokenMethodSequelize;
    _mask = VVTokenMaskDefault;
    _attrTextMaxLength = 17;
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
    VVTokenMask mask = (_mask & ~(VVTokenMaskAllPinYin | VVTokenMaskSyllable));
    VVTokenMask pymask = mask | VVTokenMaskSyllable;
    VVTokenMask fzmask = pymask | VVTokenMaskPinyin;
    _kwTokens = [VVTokenEnumerator enumerate:_keyword method:_method mask:mask];
    _pyKwTokens = [VVTokenEnumerator enumerate:_keyword method:_method mask:pymask];
    _fzKwTokens = [VVTokenEnumerator enumerate:_keyword method:_method mask:fzmask];
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

    NSString *clean = [source stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *comparison = clean.lowercaseString;
    if (self.mask & VVTokenMaskTransform) {
        comparison = comparison.simplifiedChineseString;
    }
    const char *cSource = comparison.cLangString;
    long nText = (long)strlen(cSource);
    if (nText == 0) return match;

    NSString *keyword = _keyword.lowercaseString;
    if (self.mask & VVTokenMaskTransform) {
        keyword = keyword.simplifiedChineseString;
    }

    BOOL fuzzy = (self.option & VVMatchOptionPinyin) && (self.option & VVMatchOptionFuzzy);
    match = [self highlight:source comparison:comparison cSource:cSource keyword:keyword lv1:VVMatchLV1_Origin fuzzy:fuzzy];
    return match;
}

- (NSAttributedString *)highlightText:(NSString *)clean WithRange:(NSRange)range
{
    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] init];
    NSUInteger lower = range.location;
    NSUInteger upper = NSMaxRange(range);
    NSUInteger len = range.length;
    NSUInteger maxLen = self.attrTextMaxLength;

    NSString *s1 = [clean substringToIndex:lower] ? : @"";
    NSString *sk = [clean substringWithRange:range] ? : @"";
    NSString *s2 = [clean substringFromIndex:upper] ? : @"";
    NSAttributedString *a1 = [[NSAttributedString alloc] initWithString:s1 attributes:self.normalAttributes];
    NSAttributedString *ak = [[NSAttributedString alloc] initWithString:sk attributes:self.highlightAttributes];
    NSAttributedString *a2 = [[NSAttributedString alloc] initWithString:s2 attributes:self.normalAttributes];
    [attrText appendAttributedString:a1];
    [attrText appendAttributedString:ak];
    [attrText appendAttributedString:a2];

    if (upper > maxLen && lower > 2) {
        NSInteger rlen = (2 + len > maxLen) ? (lower - 2) : (upper - maxLen);
        [attrText deleteCharactersInRange:NSMakeRange(0, rlen)];
        NSAttributedString *ellipsis = [[NSAttributedString alloc] initWithString:@"..."];
        [attrText insertAttributedString:ellipsis atIndex:0];
    }
    return attrText;
}

- (VVResultMatch *)highlight:(NSString *)source
                  comparison:(NSString *)comparison
                     cSource:(const char *)cSource
                     keyword:(NSString *)keyword
                         lv1:(VVMatchLV1)lv1
                       fuzzy:(BOOL)fuzzy
{
    VVResultMatch *match = [self highlightUsingRegex:source comparison:comparison keyword:keyword lv1:lv1];
    if (match) return match;

    VVResultMatch *nomatch = [[VVResultMatch alloc] init];
    nomatch.source = source;

    NSArray *keywordTokens = nil;
    switch (self.option) {
        case VVMatchOptionToken: keywordTokens = self.kwTokens; break;
        case VVMatchOptionPinyin: keywordTokens = self.pyKwTokens; break;
        case VVMatchOptionFuzzy: keywordTokens = self.fzKwTokens; break;
        default: return nomatch;
    }

    if (keywordTokens.count == 0) {
        return nomatch;
    }

    VVTokenMask mask = self.mask & ~VVTokenMaskSyllable;
    NSArray<VVToken *> *sourceTokens = [VVTokenEnumerator enumerateCString:cSource method:self.method mask:mask];
    match = [self highlightUsingToken:source cSource:cSource lv1:lv1 keywordTokens:keywordTokens sourceTokens:sourceTokens];
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

    BOOL hasSpace = [keyword rangeOfString:@" " options:NSLiteralSearch].length > 0;
    NSStringCompareOptions options = (hasSpace ? NSRegularExpressionSearch : 0x0) | NSLiteralSearch;
    NSString *pattern = hasSpace ? [keyword stringByReplacingOccurrencesOfString:@" +" withString:@" +" options:options range:NSMakeRange(0, keyword.length)] : keyword;
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
    NSArray<NSTextCheckingResult *> *results = [expression matchesInString:comparison options:0 range:NSMakeRange(0, comparison.length)];
    if (results.count == 0) return nil;

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
                         keywordTokens:(NSArray<VVToken *> *)keywordTokens
                          sourceTokens:(NSArray<VVToken *> *)sourceTokens
{
    if (keywordTokens.count == 0 || sourceTokens.count == 0) {
        return nil;
    }

    NSMutableDictionary *tokenMap = [NSMutableDictionary dictionary];
    for (VVToken *token in sourceTokens) {
        NSMutableSet *set = tokenMap[token.token];
        if (!set) {
            set = [NSMutableSet set];
            tokenMap[token.token] = set;
        }
        [set addObject:token];
    }
    NSMutableSet *kwtks = [NSMutableSet set];
    for (VVToken *token in keywordTokens) {
        [kwtks addObject:token.token];
    }

    NSMutableSet *matchedSet = [NSMutableSet set];
    for (NSString *tk in kwtks) {
        NSMutableSet *set = tokenMap[tk];
        if (set) [matchedSet addObjectsFromArray:set.allObjects];
    }

    if (matchedSet.count == 0) {
        return nil;
    }

    NSArray *array = [matchedSet.allObjects sortedArrayUsingComparator:^NSComparisonResult (VVToken *tk1, VVToken *tk2) {
        return tk1.start == tk2.start ? (tk1.end < tk2.end ? NSOrderedAscending : NSOrderedDescending) : (tk1.start < tk2.start ? NSOrderedAscending : NSOrderedDescending);
    }];

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
    match.attrText = attrText;
    match.ranges = ranges;
    if (match.lv2 == VVMatchLV2_None) {
        match.lv2 = VVMatchLV2_Other;
        match.lv3 = VVMatchLV3_Low;
    }

    return match;
}

@end
