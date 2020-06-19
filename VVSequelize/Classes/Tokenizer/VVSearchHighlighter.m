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

- (NSString *)description {
    return [NSString stringWithFormat:@"[%@|%@|%@|%@|0x%llx]: %@", @(_lv1), @(_lv2), @(_lv3), _ranges.firstObject, self.weight, [_attrText.description stringByReplacingOccurrencesOfString:@"\n" withString:@""]];
}

@end

@interface VVSearchHighlighter ()
@property (nonatomic, strong) NSArray<VVToken *> *keywordTokens;
@property (nonatomic, strong) NSString *keywordFullPinyin;
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
        _keyword = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    return self;
}

- (instancetype)initWithKeyword:(NSString *)keyword orm:(VVOrm *)orm
{
    self = [super init];
    if (self) {
        NSAssert(orm.config.fts && orm.config.ftsTokenizer.length > 0, @"Invalid fts orm!");
        [self setup];

        _options = VVMatchOptionPinyin | VVMatchOptionToken;
        _keyword = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        NSArray *components = [orm.config.ftsTokenizer componentsSeparatedByString:@" "];
        if (components.count > 0) {
            NSString *tokenizer = components[0];
            _method = [orm.vvdb methodForTokenizer:tokenizer];
        }
        if (components.count > 1) {
            NSString *mask = components[1];
            _mask = mask.longLongValue;
        }
    }
    return self;
}

- (void)setup {
    _options = VVMatchOptionPinyin;
    _method = VVTokenMethodSequelize;
    _mask = VVTokenMaskDefault;
    _attrTextMaxLength = 17;
}

- (void)setKeyword:(NSString *)keyword {
    _keyword = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSArray<VVToken *> *)keywordTokens {
    if (!_keywordTokens) {
        NSAssert(_keyword.length > 0, @"Invalid keyword");
        VVTokenMask mask = _mask;
        if ((mask & VVTokenMaskPinyin) > 0) {
            mask = (mask & ~VVTokenMaskAllPinYin) | VVTokenMaskSyllable;
        }
        _keywordTokens = [VVTokenEnumerator enumerate:_keyword method:_method mask:mask];
    }
    return _keywordTokens;
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

- (NSString *)keywordFullPinyin {
    if (!_keywordFullPinyin) {
        if (_keyword.length > _VVMatchPinyinLen) {
            _keywordFullPinyin = @"";
        } else {
            NSString *keyword = _keyword.lowercaseString;
            if (_mask & VVTokenMaskTransform) {
                keyword = keyword.simplifiedChineseString;
            }
            _keywordFullPinyin = [[keyword pinyin] stringByReplacingOccurrencesOfString:@" " withString:@""];
        }
    }
    return _keywordFullPinyin;
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

    match = [self highlight:source keyword:keyword lv1:VVMatchLV1_Origin comparison:comparison cSource:cSource];
    BOOL fuzzy = (self.options & VVMatchOptionPinyin) && (self.options & VVMatchOptionFuzzy);
    if (match.upperWeight == 0 && fuzzy) {
        if (self.keywordFullPinyin.length > 0 && ![self.keywordFullPinyin isEqualToString:self.keyword]) {
            VVResultMatch *otherMatch = [self highlight:source keyword:self.keywordFullPinyin lv1:VVMatchLV1_Fulls comparison:comparison cSource:cSource];
            if (otherMatch.upperWeight > 0) return otherMatch;
        }
    }
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
                     keyword:(NSString *)keyword
                         lv1:(VVMatchLV1)lv1
                  comparison:(NSString *)comparison
                     cSource:(const char *)cSource
{
    VVResultMatch *match = [self highlightUsingRegex:source keyword:keyword lv1:lv1 comparison:comparison];
    if (match) return match;

    if (self.options & VVMatchOptionPinyin) {
        match = [self highlightUsingPinyin:source keyword:keyword lv1:lv1 comparison:comparison];
        if (match) return match;
    }

    if (self.options & VVMatchOptionToken) {
        match = [self highlightUsingToken:source keyword:keyword lv1:lv1 cSource:cSource];
        if (match) return match;
    }

    VVResultMatch *nomatch = [[VVResultMatch alloc] init];
    nomatch.source = source;
    return nomatch;
}

- (VVResultMatch *)highlightUsingRegex:(NSString *)source
                               keyword:(NSString *)keyword
                                   lv1:(VVMatchLV1)lv1
                            comparison:(NSString *)comparison
{
    VVResultMatch *match = [[VVResultMatch alloc] init];
    match.lv1 = lv1;
    match.source = source;

    BOOL hasSpace = [keyword rangeOfString:@" " options:NSLiteralSearch].length > 0;
    NSStringCompareOptions options = (hasSpace ? NSRegularExpressionSearch : 0x0) | NSLiteralSearch;
    NSString *exp = hasSpace ? [keyword stringByReplacingOccurrencesOfString:@" +" withString:@" +" options:options range:NSMakeRange(0, keyword.length)] : keyword;
    NSRange found = [comparison rangeOfString:exp options:options];
    if (found.location != NSNotFound && found.length > 0) {
        if (found.location == 0 && found.length == source.length) {
            match.lv2 = VVMatchLV2_Full;
        } else if (found.location == 0 && found.length < source.length) {
            match.lv2 = VVMatchLV2_Prefix;
        } else {
            match.lv2 = VVMatchLV2_NonPrefix;
        }
        match.ranges = @[[NSValue valueWithRange:found]];
        match.lv3 = lv1 == VVMatchLV1_Origin ? VVMatchLV3_High : VVMatchLV3_Medium;
        match.attrText = [self highlightText:source WithRange:found];
        return match;
    }
    return nil;
}

- (VVResultMatch *)highlightUsingPinyin:(NSString *)source
                                keyword:(NSString *)keyword
                                    lv1:(VVMatchLV1)lv1
                             comparison:(NSString *)comparison
{
    VVResultMatch *match = [[VVResultMatch alloc] init];
    match.lv1 = lv1;
    match.source = source;

    BOOL hasSpace = [keyword rangeOfString:@" " options:NSLiteralSearch].length > 0;
    NSStringCompareOptions options = (hasSpace ? NSRegularExpressionSearch : 0x0) | NSLiteralSearch;
    NSString *exp = hasSpace ? [keyword stringByReplacingOccurrencesOfString:@" +" withString:@" +" options:options range:NSMakeRange(0, keyword.length)] : keyword;
    NSRange found = NSMakeRange(NSNotFound, 0);

    VVPinYinFruit *fruit = [comparison pinyinMatrix];
    NSArray<NSArray<NSString *> *> *matrixes = @[(lv1 == VVMatchLV1_Origin ? fruit.abbrs : @[]), fruit.fulls];
    for (NSInteger i = 0; i < matrixes.count; i++) {
        NSArray *matrix = matrixes[i];
        for (NSArray *pinyins in matrix) {
            NSString *py = [pinyins componentsJoinedByString:@""];
            found = [py rangeOfString:exp options:options];
            if (found.length > 0) {
                VVMatchLV2 lv2 = VVMatchLV2_None;
                if (found.location == 0 && found.length == py.length) {
                    lv2 = keyword.length == 1 ? VVMatchLV2_Prefix : VVMatchLV2_Full;
                } else if (found.location == 0 && found.length < py.length) {
                    lv2 = VVMatchLV2_Prefix;
                } else {
                    lv2 = VVMatchLV2_NonPrefix;
                }
                NSRange ran = [match.ranges.firstObject rangeValue];
                if ((lv2 > match.lv2) || (lv2 == match.lv2 && (found.location < ran.location || i == 1) )) {
                    NSUInteger offset = 0, idx = 0;
                    while (offset < found.location && idx < pinyins.count) {
                        NSString *s = pinyins[idx];
                        offset += s.length;
                        if (offset > NSMaxRange(found)) break;
                        idx++;
                    }
                    BOOL valid = offset == found.location;

                    if (valid) {
                        idx = idx >= pinyins.count ? pinyins.count - 1 : idx;
                        NSUInteger hloc = idx, mlen = 0;
                        while (mlen < found.length && idx < pinyins.count) {
                            NSString *s = pinyins[idx];
                            mlen += s.length;
                            idx++;
                        }
                        valid = mlen == found.length;
                        if (valid) {
                            NSUInteger hlen = idx - hloc;
                            NSRange hlRange = NSMakeRange(hloc, hlen);

                            match.lv2 = lv2;
                            match.ranges = @[[NSValue valueWithRange:hlRange]];
                            match.lv3 = (i == 1) ? VVMatchLV3_Medium : VVMatchLV3_Low;
                            match.attrText = [self highlightText:source WithRange:hlRange];
                        }
                    }
                }
            }
            if (match.lv2 == VVMatchLV2_Full) break;
        }
        if (match.lv2 == VVMatchLV2_Full) break;
    }

    if (match.lv2 != VVMatchLV2_None) {
        return match;
    }

    return nil;
}

- (VVResultMatch *)highlightUsingToken:(NSString *)source
                               keyword:(NSString *)keyword
                                   lv1:(VVMatchLV1)lv1
                               cSource:(const char *)cSource
{
    VVResultMatch *match = [[VVResultMatch alloc] init];
    match.lv1 = lv1;
    match.source = source;

    VVTokenMask mask = self.mask;
    if ((mask & VVTokenMaskPinyin) > 0) {
        mask = mask & ~VVTokenMaskSyllable;
    }

    NSArray<VVToken *> *tokens = [VVTokenEnumerator enumerateCString:cSource method:self.method mask:mask];

    NSMutableDictionary *tokenMap = [NSMutableDictionary dictionary];
    for (VVToken *token in tokens) {
        NSMutableSet *set = tokenMap[token.token];
        if (!set) {
            set = [NSMutableSet set];
            tokenMap[token.token] = set;
        }
        [set addObject:token];
    }
    NSMutableSet *kwtks = [NSMutableSet set];
    for (VVToken *token in self.keywordTokens) {
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
