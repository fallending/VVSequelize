//
//  NSString+Tokenizer.m
//  VVSequelize
//
//  Created by Valo on 2019/3/22.
//

#import "NSString+Tokenizer.h"
#import "VVTransformConst.h"

static NSString *const kVVPinYinResourceBundle = @"VVPinYin.bundle";
static NSString *const kVVPinYinResourceFile = @"pinyin.plist";
static NSString *const kVVPinYinHanzi2PinyinFile = @"hanzi2pinyin.plist";
static NSString *const kVVPinYinPolyphoneFile = @"polyphone.plist";
static NSUInteger _kVVMaxSupportLengthOfPolyphone = 5;

typedef NS_ENUM (NSUInteger, VVStringGroupType) {
    VVStringGroupNone             = 0,
    VVStringGroupMultiPlaneLetter = 0x00000001,
    VVStringGroupMultiPlaneDigit  = 0x00000002,
    VVStringGroupMultiPlaneSymbol = 0x00000003,
    VVStringGroupMultiPlaneOther  = 0x0000FFFF,
    VVStringGroupAuxiPlaneOther   = 0xFFFFFFFF,
};

@interface VVPinYin : NSObject
@property (nonatomic, strong) NSCache *cache;
@property (nonatomic, strong) NSCache *firstLettersCache;
@property (nonatomic, strong) NSDictionary *polyphones;
@property (nonatomic, strong) NSDictionary *hanzi2pinyins;
@property (nonatomic, strong) NSDictionary *pinyins;
@property (nonatomic, strong) NSDictionary *gb2big5Map;
@property (nonatomic, strong) NSDictionary *big52gbMap;
@property (nonatomic, strong) NSCharacterSet *trimmingSet;
@property (nonatomic, strong) NSCharacterSet *clearSet;
@property (nonatomic, strong) NSCharacterSet *symbolSet;
@property (nonatomic, strong) NSNumberFormatter *numberFormatter;
@end

@implementation VVPinYin

+ (instancetype)shared
{
    static VVPinYin *_shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[VVPinYin alloc] init];
    });
    return _shared;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _cache = [[NSCache alloc] init];
        _cache.totalCostLimit = 10 * 1024;
        _firstLettersCache = [[NSCache alloc] init];
        _firstLettersCache.totalCostLimit = 10 * 1024;
    }
    return self;
}

- (NSDictionary *)pinyins
{
    if (!_pinyins) {
        NSBundle *parentBundle = [NSBundle bundleForClass:self.class];
        NSString *bundlePath = [parentBundle pathForResource:kVVPinYinResourceBundle ofType:nil];
        NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
        NSString *path = [bundle pathForResource:kVVPinYinResourceFile ofType:nil];
        _pinyins = [NSDictionary dictionaryWithContentsOfFile:path];
    }
    return _pinyins;
}

- (NSDictionary *)hanzi2pinyins
{
    if (!_hanzi2pinyins) {
        NSBundle *parentBundle = [NSBundle bundleForClass:self.class];
        NSString *bundlePath = [parentBundle pathForResource:kVVPinYinResourceBundle ofType:nil];
        NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
        NSString *path = [bundle pathForResource:kVVPinYinHanzi2PinyinFile ofType:nil];
        _hanzi2pinyins = [NSDictionary dictionaryWithContentsOfFile:path];
    }
    return _hanzi2pinyins;
}

- (NSDictionary *)polyphones
{
    if (!_polyphones) {
        NSBundle *parentBundle = [NSBundle bundleForClass:self.class];
        NSString *bundlePath = [parentBundle pathForResource:kVVPinYinResourceBundle ofType:nil];
        NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
        NSString *path = [bundle pathForResource:kVVPinYinPolyphoneFile ofType:nil];
        _polyphones = [NSDictionary dictionaryWithContentsOfFile:path];
    }
    return _polyphones;
}

- (NSDictionary *)gb2big5Map {
    if (!_gb2big5Map) {
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        for (NSUInteger i = 0; i < VVSimplifiedCodes.length; i++) {
            NSString *gb = [VVSimplifiedCodes substringWithRange:NSMakeRange(i, 1)];
            NSString *big5 = [VVTraditionalCodes substringWithRange:NSMakeRange(i, 1)];
            dic[gb] = big5;
        }
        _gb2big5Map = dic;
    }
    return _gb2big5Map;
}

- (NSDictionary *)big52gbMap {
    if (!_gb2big5Map) {
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        for (NSUInteger i = 0; i < VVSimplifiedCodes.length; i++) {
            NSString *gb = [VVSimplifiedCodes substringWithRange:NSMakeRange(i, 1)];
            NSString *big5 = [VVTraditionalCodes substringWithRange:NSMakeRange(i, 1)];
            dic[big5] = gb;
        }
        _gb2big5Map = dic;
    }
    return _gb2big5Map;
}

- (NSCharacterSet *)trimmingSet
{
    if (!_trimmingSet) {
        NSMutableCharacterSet *set = [[NSMutableCharacterSet alloc] init];
        [set formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        _trimmingSet = set;
    }
    return _trimmingSet;
}

- (NSCharacterSet *)clearSet
{
    if (!_clearSet) {
        NSMutableCharacterSet *set = [[NSMutableCharacterSet alloc] init];
        [set formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet illegalCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet newlineCharacterSet]];
        _clearSet = set;
    }
    return _clearSet;
}

- (NSCharacterSet *)symbolSet
{
    if (!_symbolSet) {
        NSMutableCharacterSet *set = [[NSMutableCharacterSet alloc] init];
        [set formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet nonBaseCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet illegalCharacterSet]];
        _symbolSet = set;
    }
    return _symbolSet;
}

- (NSNumberFormatter *)numberFormatter
{
    if (_numberFormatter) {
        _numberFormatter = [[NSNumberFormatter alloc] init];
        _numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    }
    return _numberFormatter;
}

@end

@implementation NSString (Tokenizer)

+ (void)preloadingForPinyin
{
    [@"中文" pinyinsForTokenize];
}

+ (void)setMaxSupportLengthOfPolyphone:(NSUInteger)maxSupportLength
{
    _kVVMaxSupportLengthOfPolyphone = maxSupportLength;
}

- (NSString *)simplifiedChineseString {
    NSMutableString *string = [NSMutableString string];
    for (NSUInteger i = 0; i < self.length; i++) {
        NSString *ch = [self substringWithRange:NSMakeRange(i, 1)];
        NSString *trans = [VVPinYin shared].big52gbMap[ch] ? : ch;
        [string appendString:trans];
    }
    return string;
}

- (NSString *)traditionalChineseString {
    NSMutableString *string = [NSMutableString string];
    for (NSUInteger i = 0; i < self.length; i++) {
        NSString *ch = [self substringWithRange:NSMakeRange(i, 1)];
        NSString *trans = [VVPinYin shared].gb2big5Map[ch] ? : ch;
        [string appendString:trans];
    }
    return string;
}

- (BOOL)hasChinese
{
    NSString *regex = @".*[\u4e00-\u9fa5].*";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    return [predicate evaluateWithObject:self];
}

- (NSArray<NSString *> *)pinyinTokensOfChineseCharacter
{
    if (self.length != 1) return @[];
    NSString *string = self.simplifiedChineseString;
    unichar ch = [string characterAtIndex:0];
    NSString *key = [NSString stringWithFormat:@"%X", ch];
    NSArray *pinyins = [[VVPinYin shared].hanzi2pinyins objectForKey:key];
    NSMutableOrderedSet *results = [NSMutableOrderedSet orderedSet];
    for (NSString *py in pinyins) {
        [results addObject:[py substringToIndex:1]];
        [results addObject:[py substringToIndex:py.length - 1]];
    }
    return results.array;
}

- (NSArray<NSString *> *)grouped
{
    const char *cSource = self.UTF8String ? : "";
    NSUInteger inputLen = strlen(cSource);
    if (inputLen == 0) return @[];

    NSMutableArray *results = [NSMutableArray array];
    __block u_long spos = 0;
    __block u_long slen = 0;
    __block VVStringGroupType stype = VVStringGroupNone;

    u_long offset = 0;
    u_long len = 0;
    VVStringGroupType type = VVStringGroupNone;
    BOOL end = NO;

    void (^ addResult)(u_long, u_long, VVStringGroupType) = ^(u_long offset, u_long len, VVStringGroupType type) {
        NSStringEncoding encoding = 0;
        switch (stype) {
            case VVStringGroupMultiPlaneLetter: encoding = NSASCIIStringEncoding; break;
            case VVStringGroupMultiPlaneDigit: encoding = NSASCIIStringEncoding; break;
            case VVStringGroupMultiPlaneSymbol: encoding = NSUTF8StringEncoding; break;
            case VVStringGroupMultiPlaneOther: encoding = NSUTF8StringEncoding; break;
            case VVStringGroupAuxiPlaneOther:  encoding = NSUTF8StringEncoding; break;
            default: break;
        }
        if (encoding > 0) {
            NSString *str = [[NSString alloc] initWithBytes:cSource + spos length:slen encoding:encoding];
            [results addObject:str];
            spos = offset;
            slen = 0;
        }
        stype = type;
    };

    while (offset < inputLen) {
        @autoreleasepool {
            const unsigned char ch = cSource[offset];
            if (ch < 0xC0) {
                len = 1;
                if (ch >= 0x30 && ch <= 0x39) {
                    type = VVStringGroupMultiPlaneDigit;
                } else if ((ch >= 0x41 && ch <= 0x5a) || (ch >= 0x61 && ch <= 0x7a)) {
                    type = VVStringGroupMultiPlaneLetter;
                } else {
                    BOOL isSymbol = [VVPinYin.shared.symbolSet characterIsMember:ch];
                    type = isSymbol ? VVStringGroupMultiPlaneSymbol : VVStringGroupMultiPlaneOther;
                }
            } else if (ch < 0xF0) {
                unichar unicode = 0;
                if (ch < 0xE0) {
                    len = 2;
                    unicode = ch & 0x1F;
                } else {
                    len = 3;
                    unicode = ch & 0x0F;
                }
                for (u_long j = offset + 1; j < offset + len; ++j) {
                    if (j < inputLen) {
                        unicode = (unicode << 6) | (cSource[j] & 0x3F);
                    } else {
                        type = VVStringGroupNone;
                        len = inputLen - j;
                        end = YES;
                    }
                }
                if (!end) {
                    BOOL isSymbol = [VVPinYin.shared.symbolSet characterIsMember:ch];
                    type = isSymbol ? VVStringGroupMultiPlaneSymbol : VVStringGroupMultiPlaneOther;
                }
            } else {
                type = VVStringGroupAuxiPlaneOther;
                if (ch < 0xF8) {
                    len = 4;
                } else if (ch < 0xFC) {
                    len = 5;
                } else {
                    len = 3; // split every chinese character
                    // len = 6; // split every two chinese characters
                }
            }

            if (end) break;
            if (stype != type) {
                addResult(offset, len, type);
            }
            offset += len;
            slen += len;
        }
    }
    addResult(offset, len, type);

    return results;
}

- (NSString *)pinyin
{
    NSString *prepared = [self.grouped componentsJoinedByString:@" "];
    NSMutableString *string = [NSMutableString stringWithString:prepared];
    CFStringTransform((__bridge CFMutableStringRef)string, NULL, kCFStringTransformToLatin, false);
    NSString *result = [string stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
    return [result stringByReplacingOccurrencesOfString:@"'" withString:@""];
}

- (NSArray<NSString *> *)pinyinsForTokenize
{
    NSArray *results = [[VVPinYin shared].cache objectForKey:self];
    if (results) return results;

    NSString *prepared = [self stringByTrimmingCharactersInSet:[VVPinYin shared].trimmingSet];
    NSString *string = [prepared pinyin];

    NSArray *pinyins = [string componentsSeparatedByString:@" "];
    NSDictionary *polyphones = [prepared polyphonePinyins];
    NSArray *flattened = [NSString flatten:pinyins polyphones:polyphones];
    NSMutableArray *array = [NSMutableArray array];
    for (NSArray *sub in flattened) {
        NSMutableString *totalstring = [NSMutableString stringWithCapacity:0];
        NSMutableString *firstLetters = [NSMutableString stringWithCapacity:flattened.count];
        for (NSString *pinyin in sub) {
            if (pinyin.length < 1) continue;
            [totalstring appendString:pinyin];
            [firstLetters appendString:[pinyin substringToIndex:1]];
        }
        [array addObjectsFromArray:@[totalstring, firstLetters]];
    }

    results = [NSOrderedSet orderedSetWithArray:array].array;
    [[VVPinYin shared].cache setObject:results forKey:self];
    return results;
}

- (NSArray<NSString *> *)firstLettersForFilter
{
    NSArray *results = [[VVPinYin shared].firstLettersCache objectForKey:self];
    if (results) return results;

    NSString *prepared = [self stringByTrimmingCharactersInSet:[VVPinYin shared].trimmingSet];
    NSString *string = [prepared pinyin];

    NSArray *pinyins = [string componentsSeparatedByCharactersInSet:[VVPinYin shared].trimmingSet];
    NSDictionary *polyphones = [prepared polyphonePinyins];
    NSArray *flattened = [NSString flatten:pinyins polyphones:polyphones];
    NSMutableArray *array = [NSMutableArray array];
    for (NSArray *sub in flattened) {
        NSMutableString *firstLetters = [NSMutableString stringWithCapacity:flattened.count];
        for (NSString *pinyin in sub) {
            if (pinyin.length < 1) continue;
            [firstLetters appendString:[pinyin substringToIndex:1]];
        }
        [array addObject:firstLetters];
    }

    results = [NSOrderedSet orderedSetWithArray:array].array;
    [[VVPinYin shared].firstLettersCache setObject:results forKey:self];
    return results;
}

- (NSArray<NSString *> *)polyphonePinyinsAtIndex:(NSUInteger)index
{
    unichar ch = [self characterAtIndex:index];
    NSString *key = [NSString stringWithFormat:@"%X", ch];
    return [[VVPinYin shared].polyphones objectForKey:key];
}

- (NSDictionary<NSNumber *, NSArray *> *)polyphonePinyins
{
    if (self.length > _kVVMaxSupportLengthOfPolyphone) return nil;
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < self.length; i++) {
        NSArray *polys = [self polyphonePinyinsAtIndex:i];
        NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSet];
        for (NSString *poly in polys) {
            if (poly.length > 1) [set addObject:[poly substringToIndex:poly.length - 1]];
        }
        dic[@(i)] = set.array;
    }
    return dic;
}

+ (NSArray<NSArray *> *)flatten:(NSArray *)pinyins polyphones:(NSDictionary<NSNumber *, NSArray *> *)polyphones
{
    if (polyphones.count == 0) return @[pinyins];
    NSUInteger chineseCount = pinyins.count;
    __block NSMutableOrderedSet *results = [NSMutableOrderedSet orderedSet];
    [results addObject:pinyins];
    [polyphones enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, NSArray *polyPinyins, BOOL *stop) {
        NSUInteger idx = key.unsignedIntegerValue;
        if (idx >= chineseCount || polyPinyins.count == 0) { return; }
        for (NSString *poly in polyPinyins) {
            NSMutableArray *tempArray = [pinyins mutableCopy];
            tempArray[idx] = poly;
            [results addObject:tempArray];
        }
    }];

    return results.array;
}

- (NSArray<NSString *> *)numberStringsForTokenize {
    NSNumberFormatter *formatter = [VVPinYin shared].numberFormatter;
    NSNumber *number = [formatter numberFromString:self];
    if (number) {
        NSString *unformatted = number.stringValue;
        NSString *formatted = [formatter stringFromNumber:number];
        return @[unformatted, formatted];
    }
    return @[self];
}

- (NSString *)cleanString
{
    NSArray *array = [self componentsSeparatedByCharactersInSet:[VVPinYin shared].clearSet];
    return [array componentsJoinedByString:@""];
}

//MARK: - pinyin
- (NSArray<NSString *> *)headPinyins
{
    const char *str = self.UTF8String ? : "";
    if (strlen(str) <= 0) return @[];
    NSString *firstLetter = [self substringToIndex:1];
    NSArray *array = [[VVPinYin shared].pinyins objectForKey:firstLetter];
    if (array.count == 0) return @[];
    NSMutableArray *results = [NSMutableArray array];
    for (NSString *pinyin in array) {
        const char *py = pinyin.UTF8String;
        int len = (int)strlen(py);
        if (strncmp(py, str, len) == 0) {
            [results addObject:pinyin];
        }
    }
    return results;
}

- (NSArray<NSArray<NSString *> *> *)splitIntoPinyins
{
    return [self.lowercaseString _splitIntoPinyins];
}

- (NSArray<NSArray<NSString *> *> *)_splitIntoPinyins
{
    NSMutableArray<NSArray<NSString *> *> *results = [NSMutableArray array];
    NSArray<NSString *> *array = [self headPinyins];
    if (array.count == 0) return @[@[self]];
    for (NSString *first in array) {
        NSString *tail = [self substringFromIndex:first.length];
        NSArray<NSArray<NSString *> *> *components = [tail _splitIntoPinyins];
        for (NSArray<NSString *> *pinyins in components) {
            NSArray<NSString *> *result = [@[first] arrayByAddingObjectsFromArray:pinyins];
            [results addObject:result];
        }
    }
    return results;
}

@end

@implementation NSArray (Tokenizer)

- (NSArray *)filteredArrayUsingKeyword:(NSString *)keyword
{
    return [self filteredArrayUsingKeyword:keyword pinyin:YES];
}

- (NSArray *)filteredArrayUsingKeyword:(NSString *)keyword pinyin:(BOOL)pinyin
{
    if (keyword.length == 0) return self;
    NSMutableArray *results = [NSMutableArray array];
    NSString *like = [NSString stringWithFormat:@"*%@*", keyword.lowercaseString.simplifiedChineseString];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF LIKE %@", like];
    for (NSString *string in self) {
        if (string.length == 0) continue;
        NSMutableArray *array = [NSMutableArray array];
        [array addObject:string.lowercaseString.simplifiedChineseString];
        if (pinyin) {
            NSArray *pinyins = [string pinyinsForTokenize];
            [array addObjectsFromArray:pinyins];
        }
        NSArray *filtered = [array filteredArrayUsingPredicate:predicate];
        if (filtered.count > 0) [results addObject:string];
    }
    return results;
}

@end
