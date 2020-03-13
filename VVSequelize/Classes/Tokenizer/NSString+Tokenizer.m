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

@interface VVPinYin ()
@property (nonatomic, strong) NSCache *cache;
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
    }
    return self;
}

+ (NSDictionary *)dictionaryWithResource:(NSString *)resource
{
    NSBundle *parentBundle = [NSBundle bundleForClass:self];
    NSString *bundlePath = [parentBundle pathForResource:kVVPinYinResourceBundle ofType:nil];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString *path = [bundle pathForResource:resource ofType:nil];
    return [NSDictionary dictionaryWithContentsOfFile:path];
}

- (NSDictionary *)pinyins
{
    if (!_pinyins) {
        _pinyins = [[self class] dictionaryWithResource:kVVPinYinResourceFile];
    }
    return _pinyins;
}

- (NSDictionary *)hanzi2pinyins
{
    if (!_hanzi2pinyins) {
        _hanzi2pinyins = [[self class] dictionaryWithResource:kVVPinYinHanzi2PinyinFile];
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

@implementation VVPinYinFruit

+ (instancetype)fruitWithSimps:(NSArray<NSString *> *)firsts fulls:(NSArray<NSString *> *)fulls
{
    VVPinYinFruit *item = [VVPinYinFruit new];
    item.simps = firsts;
    item.fulls = fulls;
    return item;
}

@end

@implementation NSString (Tokenizer)

+ (void)preloadingForPinyin
{
    [@"中文" pinyinsForMatch];
}

+ (instancetype)ocStringWithCString:(const char *)cString
{
    NSString *str = [NSString stringWithUTF8String:cString];
    if (str) return str;
    str = [NSString stringWithCString:cString encoding:NSASCIIStringEncoding];
    if (str) return str;
    return @"";
}

- (const char *)cString
{
    const char *str = self.UTF8String;
    if (str) return str;
    str = [self cStringUsingEncoding:NSASCIIStringEncoding];
    if (str) return str;
    return "";
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

- (VVPinYinFruit *)pinyinsAtIndex:(NSUInteger)index
{
    if (self.length <= index) {
        return [VVPinYinFruit fruitWithSimps:@[] fulls:@[]];
    }
    NSArray *zcs = @[@"z", @"c", @"s"];
    NSArray *zhchsh = @[@"zh", @"ch", @"sh"];
    NSString *string = self.simplifiedChineseString;
    unichar ch = [string characterAtIndex:index];
    NSString *key = [NSString stringWithFormat:@"%X", ch];
    NSArray *pinyins = [[VVPinYin shared].hanzi2pinyins objectForKey:key];
    NSMutableOrderedSet *fulls = [NSMutableOrderedSet orderedSet];
    NSMutableOrderedSet *simps = [NSMutableOrderedSet orderedSet];
    for (NSString *pinyin in pinyins) {
        if (pinyin.length < 1) continue;
        [fulls addObject:[pinyin substringToIndex:pinyin.length - 1]];
        NSString *first = [pinyin substringToIndex:1];
        [simps addObject:first];
        if ([zcs containsObject:first]) {
            for (NSString *prefix in zhchsh) {
                if ([pinyin hasPrefix:prefix]) {
                    [simps addObject:prefix];
                    break;
                }
            }
        }
    }
    if (fulls.count == 0) {
        NSString *str = [self substringWithRange:NSMakeRange(index, 1)];
        [fulls addObject:str];
        [simps addObject:str];
    }
    return [VVPinYinFruit fruitWithSimps:simps.array fulls:fulls.array];
}

- (VVPinYinFruit *)pinyinsForMatch
{
    return [self pinyinsForMatch:self.length < 5];
}

- (VVPinYinFruit *)pinyinsForMatch:(BOOL)polyphone
{
    if (self.length <= 1) {
        return [VVPinYinFruit fruitWithSimps:@[self] fulls:@[self]];
    }
    NSUInteger count = self.length;
    NSMutableArray<NSArray<NSString *> *> *fulls = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray<NSArray<NSString *> *> *simps = [NSMutableArray arrayWithCapacity:count];

    for (NSUInteger i = 0; i < count; i++) {
        VVPinYinFruit *fruit = [self pinyinsAtIndex:i];
        [fulls addObject:polyphone ? fruit.fulls : @[fruit.fulls.firstObject]];
        [simps addObject:polyphone ? fruit.simps : @[fruit.simps.firstObject]];
    }
    NSArray<NSArray<NSString *> *> *tiledFulls = fulls.tiledArray;
    NSArray<NSArray<NSString *> *> *tiledSimps = simps.tiledArray;
    NSMutableArray<NSString *> *fullPinyins = [NSMutableArray arrayWithCapacity:tiledFulls.count];
    NSMutableArray<NSString *> *simpPinyins = [NSMutableArray arrayWithCapacity:tiledSimps.count];
    for (NSArray<NSString *> *array in tiledFulls) {
        [fullPinyins addObject:[array componentsJoinedByString:@""]];
    }
    for (NSArray<NSString *> *array in tiledSimps) {
        [simpPinyins addObject:[array componentsJoinedByString:@""]];
    }

    return [VVPinYinFruit fruitWithSimps:simpPinyins fulls:fullPinyins];
}

- (NSArray<NSString *> *)numberStringsForTokenize {
    NSNumberFormatter *formatter = [VVPinYin shared].numberFormatter;
    NSNumber *number = [formatter numberFromString:self];
    if (number != nil) {
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
- (NSArray<NSString *> *)legalFirstPinyins
{
    const char *str = self.UTF8String;
    u_long length = strlen(str);
    if (length <= 0) return @[];

    NSString *firstLetter = [self substringToIndex:1];
    NSArray *array = [[VVPinYin shared].pinyins objectForKey:firstLetter];

    NSMutableArray *results = [NSMutableArray array];
    for (NSString *pinyin in array) {
        const char *py = pinyin.cString;
        u_long len = strlen(py);
        if (len < length && strncmp(py, str, len) == 0) {
            [results addObject:pinyin];
        }
    }
    return results;
}

- (NSArray<NSArray<NSString *> *> *)splitedPinyins
{
    return [self.lowercaseString _splitedPinyins];
}

- (NSArray<NSArray<NSString *> *> *)_splitedPinyins
{
    NSMutableArray<NSArray<NSString *> *> *results = [NSMutableArray array];
    @autoreleasepool {
        NSArray<NSString *> *array = [self legalFirstPinyins];
        if (array.count == 0) return @[@[self]];
        for (NSString *first in array) {
            NSString *tail = [self substringFromIndex:first.length];
            NSArray<NSArray<NSString *> *> *components = [tail _splitedPinyins];
            for (NSArray<NSString *> *pinyins in components) {
                NSArray<NSString *> *result = [@[first] arrayByAddingObjectsFromArray:pinyins];
                [results addObject:result];
            }
        }
    }
    return results;
}

@end

@implementation NSArray (Tokenizer)

- (NSUInteger)tiledCount
{
    NSUInteger total = 1;
    for (NSArray *sub in self) {
        NSAssert([sub isKindOfClass:[NSArray class]], @"Invalid source array");
        total = total * sub.count;
    }
    return total;
}

- (NSArray<NSArray *> *)tiledArray
{
    NSUInteger tiledCount = self.tiledCount;
    NSMutableArray<NSMutableArray *> *results = [NSMutableArray arrayWithCapacity:tiledCount];
    for (NSUInteger i = 0; i < tiledCount; i++) {
        [results addObject:[NSMutableArray arrayWithCapacity:self.count]];
    }
    NSUInteger rowRepeat = tiledCount;
    NSUInteger sectionRepeat = 1;
    for (uint64_t col = 0; col < self.count; col++) {
        NSArray *sub = [self objectAtIndex:col];
        rowRepeat = rowRepeat / sub.count;
        NSUInteger section = tiledCount / sectionRepeat;
        for (NSUInteger j = 0; j < sub.count; j++) {
            id obj = [sub objectAtIndex:j];
            for (NSUInteger k = 0; k < sectionRepeat; k++) {
                for (NSUInteger l = 0; l < rowRepeat; l++) {
                    NSUInteger row =  k * section + j * rowRepeat + l;
                    NSMutableArray *result = results[row];
                    result[col] = obj;
                }
            }
        }
        sectionRepeat = sectionRepeat * sub.count;
    }
    return results;
}

@end
