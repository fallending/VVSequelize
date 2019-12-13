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

typedef NS_ENUM (NSUInteger, VVStringGroupType) {
    VVStringGroupNone             = 0,
    VVStringGroupMultiPlaneLetter = 0x00000001,
    VVStringGroupMultiPlaneDigit  = 0x00000002,
    VVStringGroupMultiPlaneSymbol = 0x00000003,
    VVStringGroupMultiPlaneOther  = 0x0000FFFF,
    VVStringGroupAuxiPlaneOther   = 0xFFFFFFFF,
};

@interface VVPinYin ()
@property (nonatomic, strong) NSCache *cache;
@property (nonatomic, strong) NSCache *firstLettersCache;
@property (nonatomic, strong) NSDictionary *hanzi2pinyins;
@property (nonatomic, strong) NSDictionary *pinyins;
@property (nonatomic, strong) NSDictionary *gb2big5Map;
@property (nonatomic, strong) NSDictionary *big52gbMap;
@property (nonatomic, strong) NSCharacterSet *trimmingSet;
@property (nonatomic, strong) NSCharacterSet *cleanSet;
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

- (NSCharacterSet *)cleanSet
{
    if (!_cleanSet) {
        NSMutableCharacterSet *set = [[NSMutableCharacterSet alloc] init];
        [set formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet illegalCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet newlineCharacterSet]];
        _cleanSet = set;
    }
    return _cleanSet;
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
    if (!_numberFormatter) {
        _numberFormatter = [[NSNumberFormatter alloc] init];
        _numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    }
    return _numberFormatter;
}

@end

@implementation NSString (Tokenizer)

+ (void)preloadingForPinyin
{
    [@"中文" pinyinsForMatch];
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

- (NSString *)pinyin
{
    NSMutableString *string = [NSMutableString stringWithString:self];
    CFStringTransform((__bridge CFMutableStringRef)string, NULL, kCFStringTransformToLatin, false);
    NSString *result = [string stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
    return [result stringByReplacingOccurrencesOfString:@"'" withString:@""];
}

- (NSArray<NSArray<NSString *> *> *)pinyinsAtIndex:(NSUInteger)index
{
    NSString *string = self.simplifiedChineseString;
    unichar ch = [string characterAtIndex:index];
    NSString *key = [NSString stringWithFormat:@"%X", ch];
    NSArray *pinyins = [[VVPinYin shared].hanzi2pinyins objectForKey:key];
    NSMutableOrderedSet *fulls = [NSMutableOrderedSet orderedSet];
    NSMutableOrderedSet *firsts = [NSMutableOrderedSet orderedSet];
    for (NSString *pinyin in pinyins) {
        if (pinyin.length < 1) continue;
        [fulls addObject:[pinyin substringToIndex:pinyin.length - 1]];
        [firsts addObject:[pinyin substringToIndex:1]];
    }
    return @[fulls.array, firsts.array];
}

- (NSArray<NSArray<NSString *> *> *)pinyinsForMatch
{
    NSArray *results = [[VVPinYin shared].cache objectForKey:self];
    if (results) return results;

    NSArray<NSArray<NSString *> *> *pinyins = [self pinyinsAtIndex:0];
    NSString *letter = [self substringToIndex:1];
    NSArray<NSString *> *headFulls = pinyins.firstObject.count > 0 ? pinyins.firstObject : @[letter];
    NSArray<NSString *> *headFirsts = pinyins.lastObject.count > 0 ? pinyins.lastObject : @[letter];

    if (self.length == 1) {
        return @[headFulls, headFirsts];
    }
    NSString *substring = [self substringFromIndex:1];
    NSArray<NSArray<NSString *> *> *subPinyins = [substring pinyinsForMatch];
    NSArray<NSString *> *subFulls = subPinyins.firstObject;
    NSArray<NSString *> *subFirsts = subPinyins.lastObject;

    NSMutableArray<NSString *> *fulls = [NSMutableArray array];
    NSMutableArray<NSString *> *firsts = [NSMutableArray array];
    for (NSString *headfull in headFulls) {
        for (NSString *subfull in subFulls) {
            [fulls addObject:[headfull stringByAppendingString:subfull]];
        }
    }
    for (NSString *headfirst in headFirsts) {
        for (NSString *subfirst in subFirsts) {
            [firsts addObject:[headfirst stringByAppendingString:subfirst]];
        }
    }
    results = @[fulls, firsts];
    [[VVPinYin shared].cache setObject:results forKey:self];
    return results;
}

- (NSArray<NSArray<NSArray<NSString *> *> *> *)pinyinMatrix
{
    NSArray<NSArray<NSString *> *> *pinyins = [self pinyinsAtIndex:0];
    NSString *letter = [self substringToIndex:1];
    NSArray<NSString *> *_headFulls = pinyins.firstObject.count > 0 ? pinyins.firstObject : @[letter];
    NSArray<NSString *> *_headFirsts = pinyins.lastObject.count > 0 ? pinyins.lastObject : @[letter];

    NSMutableArray<NSArray<NSString *> *> *headFulls = [NSMutableArray array];
    NSMutableArray<NSArray<NSString *> *> *headFirsts = [NSMutableArray array];
    for (NSString *full in _headFulls) {
        [headFulls addObject:@[full]];
    }
    for (NSString *first in _headFirsts) {
        [headFirsts addObject:@[first]];
    }

    if (self.length == 1) {
        return @[headFulls, headFirsts];
    }
    NSString *substring = [self substringFromIndex:1];
    NSArray<NSArray<NSArray<NSString *> *> *> *subPinyins = [substring pinyinMatrix];
    NSArray<NSArray<NSString *> *> *subFulls = subPinyins.firstObject;
    NSArray<NSArray<NSString *> *> *subFirsts = subPinyins.lastObject;

    NSMutableArray<NSArray<NSString *> *> *fulls = [NSMutableArray array];
    NSMutableArray<NSArray<NSString *> *> *firsts = [NSMutableArray array];
    for (NSArray<NSString *> *headfull in headFulls) {
        for (NSArray<NSString *> *subfull in subFulls) {
            [fulls addObject:[headfull arrayByAddingObjectsFromArray:subfull]];
        }
    }
    for (NSArray<NSString *> *headfirst in headFirsts) {
        for (NSArray<NSString *> *subfirst in subFirsts) {
            [firsts addObject:[headfirst arrayByAddingObjectsFromArray:subfirst]];
        }
    }
    return @[fulls, firsts];
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
    NSArray *array = [self componentsSeparatedByCharactersInSet:[VVPinYin shared].cleanSet];
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
            NSArray *pinyins = [string pinyinsForMatch];
            [array addObjectsFromArray:pinyins];
        }
        NSArray *filtered = [array filteredArrayUsingPredicate:predicate];
        if (filtered.count > 0) [results addObject:string];
    }
    return results;
}

@end
