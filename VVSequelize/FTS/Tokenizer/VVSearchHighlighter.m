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
@property (nonatomic, strong) NSArray<NSArray<NSSet<NSString *> *> *> *kwTokens;
@end

@implementation VVSearchHighlighter

+ (NSArray *)arrangeTokens:(const char *)text mask:(VVTokenMask)mask
{
    static NSCache *_cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _cache = [[NSCache alloc] init];
        _cache.countLimit = 1024;
    });
    NSString *key = [NSString stringWithFormat:@"0x%lX-%@", (unsigned long)mask, [NSString ocStringWithCString:text]];
    NSArray *results = [_cache objectForKey:key];
    if (!results) {
        NSArray<VVToken *> *tokens = [VVTokenSequelizeEnumerator enumerate:text mask:mask];
        results = [self arrange:tokens];
        [_cache setObject:results forKey:key];
    }
    return results;
}

+ (NSArray *)arrange:(NSArray<VVToken *> *)tokens
{
    NSMutableDictionary *commons = [NSMutableDictionary dictionary];
    NSMutableDictionary *syllables = [NSMutableDictionary dictionary];
    for (VVToken *tk in tokens) {
        if (tk.colocated < 3) {
            NSMutableSet *set = commons[@(tk.start)];
            if (!set) set = [NSMutableSet set];
            [set addObject:tk];
            commons[@(tk.start)] = set;
        } else {
            NSMutableSet *set = syllables[@(tk.colocated)];
            if (!set) set = [NSMutableSet set];
            [set addObject:tk];
            syllables[@(tk.colocated)] = set;
        }
    }

    NSMutableArray *arrangedWords = [NSMutableArray array];
    NSMutableArray *arrangedTokens = [NSMutableArray array];

    // commons
    NSArray *commonSorted = [commons.allValues sortedArrayUsingComparator:^NSComparisonResult (NSSet<VVToken *> *s1, NSSet<VVToken *> *s2) {
        return s1.anyObject.start < s2.anyObject.start ? NSOrderedAscending : NSOrderedDescending;
    }];
    NSMutableArray *commonWords = [NSMutableArray arrayWithCapacity:commonSorted.count];
    NSMutableArray *commonTokens = [NSMutableArray arrayWithCapacity:commonSorted.count];
    for (NSSet<VVToken *> *subTokens in commonSorted) {
        NSMutableSet *subWords = [NSMutableSet setWithCapacity:subTokens.count];
        NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:subTokens.count];
        for (VVToken *tk in subTokens) {
            [subWords addObject:tk.token];
            dic[tk.token] = tk;
        }
        [commonWords addObject:subWords];
        [commonTokens addObject:dic];
    }
    [arrangedWords addObject:commonWords];
    [arrangedTokens addObject:commonTokens];

    //syllables
    for (NSSet<VVToken *> *subTokens in syllables.allValues) {
        NSMutableArray *syllableWords = [NSMutableArray arrayWithCapacity:subTokens.count];
        NSMutableArray *syllableTokens = [NSMutableArray arrayWithCapacity:subTokens.count];
        NSArray *subSorted = [VVToken sortedTokens:subTokens.allObjects];
        int pos = 0;
        for (VVToken *tk in subSorted) {
            for (int i = pos; i < tk.start; i++) {
                NSSet *set = commons[@(i)];
                if (!set) continue;
                NSMutableSet *subWords = [NSMutableSet setWithCapacity:set.count];
                NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:set.count];
                for (VVToken *xtk in set) {
                    [subWords addObject:xtk.token];
                    dic[xtk.token] = xtk;
                }
                [syllableWords addObject:subWords];
                [syllableTokens addObject:dic];
            }
            pos = tk.end;
            [syllableWords addObject:[NSSet setWithObject:tk.token]];
            [syllableTokens addObject:@{ tk.token: tk }];
        }
        NSSet *lasts = commonSorted.lastObject;
        VVToken *ltk = lasts.anyObject;
        for (int i = pos; i < ltk.end; i++) {
            NSSet *set = commons[@(i)];
            if (!set) continue;
            NSMutableSet *subWords = [NSMutableSet setWithCapacity:set.count];
            NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:set.count];
            for (VVToken *xtk in set) {
                [subWords addObject:xtk.token];
                dic[xtk.token] = xtk;
            }
            [syllableWords addObject:subWords];
            [syllableTokens addObject:dic];
        }

        [arrangedWords addObject:syllableWords];
        [arrangedTokens addObject:syllableTokens];
    }

    return @[arrangedTokens, arrangedWords];
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

- (void)setup {
    _enumerator = VVTokenSequelizeEnumerator.class;
    _mask = VVTokenMaskDefault;
    _useSingleLine = YES;
}

- (void)setFuzzy:(BOOL)fuzzy
{
    _fuzzy = fuzzy;
    _kwTokens = nil;
}

- (void)setMask:(VVTokenMask)mask
{
    _mask = mask;
    _kwTokens = nil;
}

- (void)setKeyword:(NSString *)keyword
{
    _keyword = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    _kwTokens = nil;
}

- (NSArray<NSArray<NSSet<NSString *> *> *> *)kwTokens
{
    if (_kwTokens) return _kwTokens;
    if (_keyword.length == 0) return @[];
    VVTokenMask mask = (_mask | VVTokenMaskSyllable) & ~VVTokenMaskAbbreviation;
    if (_fuzzy) mask = mask | VVTokenMaskPinyin;
    else mask = mask & ~VVTokenMaskPinyin;
    _kwTokens = [VVSearchHighlighter arrangeTokens:_keyword.UTF8String mask:mask].lastObject;
    return _kwTokens;
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
    return [matchedText vv_attributedStringByTrimmingToLength:maxLen withAttributes:self.highlightAttributes];
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

    NSString *keyword = _keyword.matchingPattern.simplifiedChineseString;
    NSString *comparison = source.matchingPattern.simplifiedChineseString;

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
    NSString *text = self.useSingleLine ? source.singleLine : source;
    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] initWithString:text attributes:self.normalAttributes];
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
    if (self.kwTokens.firstObject.count == 0 && self.kwTokens.lastObject.count == 0) return nil;
    VVTokenMask mask = _fuzzy ? (_mask | VVTokenMaskPinyin) : _mask;
    NSArray *arranged = [VVSearchHighlighter arrangeTokens:cSource mask:mask];
    NSArray<NSArray<NSDictionary<NSString *, VVToken *> *> *> *arrangedTokens = arranged.firstObject;
    NSArray<NSArray<NSSet<NSString *> *> *> *arrangedWords = arranged.lastObject;
    if (arrangedTokens.count == 0 && arrangedWords.count == 0) return nil;

    VVMatchLV1 rlv1 = VVMatchLV1_None;
    BOOL whole = YES;
    NSString *text = self.useSingleLine ? source.singleLine : source;
    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] initWithString:text attributes:self.normalAttributes];
    NSMutableArray *ranges = [NSMutableArray array];
    for (int kc = 0; kc < self.kwTokens.count; kc++) {
        for (int sc = 0; sc < arrangedWords.count; sc++) {
            NSArray<NSSet<NSString *> *> *groupWords = arrangedWords[sc];
            NSArray<NSSet<NSString *> *> *kwGroupWords = self.kwTokens[kc];
            for (NSUInteger i = 0; i < groupWords.count; i++) {
                NSUInteger j = 0;
                NSUInteger k = i;
                int sloc = -1;
                int slen = -1;
                VVMatchLV1 xlv1 = VVMatchLV1_Origin;
                while (j < kwGroupWords.count && k < groupWords.count) {
                    NSSet<NSString *> *set = groupWords[k];
                    NSSet<NSString *> *kwset = kwGroupWords[j];
                    NSString *matchword = nil;
                    if ([set intersectsSet:kwset]) {
                        NSMutableSet<NSString *> *mset = [set mutableCopy];
                        [mset intersectSet:kwset];
                        matchword = mset.anyObject;
                    } else if (j == kwGroupWords.count - 1 && kc > 0) {
                        for (NSString *kwword in kwset) {
                            for (NSString *word in set) {
                                if ([word hasPrefix:kwword]) {
                                    matchword = word;
                                    whole = NO;
                                    break;
                                }
                            }
                            if (matchword) break;
                        }
                    }
                    if (matchword) {
                        NSDictionary *dic = arrangedTokens[sc][k];
                        VVToken *tk = dic[matchword];
                        VVMatchLV1 tlv1 = VVMatchLV1_None;
                        if (kc == 0 && sc == 0) {
                            tlv1 = tk.colocated <= 0 ? VVMatchLV1_Origin : VVMatchLV1_Firsts;
                        } else if (kc > 0 && sc == 0) {
                            tlv1 = VVMatchLV1_Fulls;
                        } else {
                            tlv1 = VVMatchLV1_Fuzzy;
                        }
                        if (tlv1 < xlv1) xlv1 = tlv1;
                        if (sloc < 0) sloc = tk.start;
                        slen = tk.end - sloc;
                        j++;
                        k++;
                    } else {
                        break;
                    }
                }
                if (j > 0 && j == kwGroupWords.count) {
                    if (rlv1 < xlv1) rlv1 = xlv1;
                    NSString *s1 = [[NSString alloc] initWithBytes:cSource length:sloc encoding:NSUTF8StringEncoding];
                    NSString *s2 = [[NSString alloc] initWithBytes:cSource + sloc length:slen encoding:NSUTF8StringEncoding];
                    NSRange range = NSMakeRange(s1.length, s2.length);
                    [attrText addAttributes:self.highlightAttributes range:range];
                    [ranges addObject:[NSValue valueWithRange:range]];
                    if (self.quantity > 0 && ranges.count > self.quantity) break;
                }
            }
            if (ranges.count > 0) break;
        }
        if (ranges.count > 0) break;
    }
    if (ranges.count == 0) return nil;
    NSRange first = [ranges.firstObject rangeValue];
    VVResultMatch *match = [[VVResultMatch alloc] init];
    match.source = source;
    match.ranges = ranges;
    match.attrText = attrText;
    match.lv1 = rlv1;
    match.lv2 = first.location == 0 ? (first.length == attrText.length && whole ? VVMatchLV2_Full : VVMatchLV2_Prefix) : VVMatchLV2_NonPrefix;
    match.lv3 = rlv1 == VVMatchLV1_Origin ? VVMatchLV3_High : rlv1 == VVMatchLV1_Fulls ? VVMatchLV3_Medium : VVMatchLV3_Low;
    return match;
}

@end
