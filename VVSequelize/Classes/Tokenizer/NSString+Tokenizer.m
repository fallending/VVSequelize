//
//  NSString+Tokenizer.m
//  VVSequelize
//
//  Created by Valo on 2019/3/22.
//

#import "NSString+Tokenizer.h"

static NSString *const kVVPinYinResourceBundle = @"VVPinYin.bundle";
static NSString *const kVVPinYinResourceFile = @"polyphone.plist";
static NSUInteger _kVVMaxSupportLengthOfPolyphone = 5;

@interface VVPinYin : NSObject
@property (nonatomic, strong) NSCache *cache;
@property (nonatomic, strong) NSDictionary *polyphones;
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
        _cache.totalCostLimit = 100 * 1024 * 1024;
    }
    return self;
}

- (NSDictionary *)polyphones
{
    if (!_polyphones) {
        NSBundle *parentBundle = [NSBundle bundleForClass:self.class];
        NSString *bundlePath = [parentBundle pathForResource:kVVPinYinResourceBundle ofType:nil];
        NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
        NSString *path = [bundle pathForResource:kVVPinYinResourceFile ofType:nil];
        _polyphones = [NSDictionary dictionaryWithContentsOfFile:path];
    }
    return _polyphones;
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

- (BOOL)hasChinese
{
    NSString *regex = @".*[\u4e00-\u9fa5].*";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    return [predicate evaluateWithObject:self];
}

- (NSString *)pinyin
{
    NSMutableString *string = [NSMutableString stringWithString:self];
    CFStringTransform((CFMutableStringRef)string, NULL, kCFStringTransformToLatin, false);
    string = (NSMutableString *)[string stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
    return [string stringByReplacingOccurrencesOfString:@"'" withString:@""];
}

- (NSArray<NSString *> *)pinyinsForTokenize
{
    NSArray *results = [[VVPinYin shared].cache objectForKey:self];
    if (results) return results;

    static NSMutableCharacterSet *set = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        set = [[NSMutableCharacterSet alloc] init];
        [set formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
    });
    NSString *prepared = [self stringByTrimmingCharactersInSet:set];
    NSString *string = [prepared pinyin];

    NSArray *pinyins = [string componentsSeparatedByCharactersInSet:set];
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

    results = [NSSet setWithArray:array].allObjects;
    [[VVPinYin shared].cache setObject:results forKey:self];
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
        NSMutableSet *set = [NSMutableSet set];
        for (NSString *poly in polys) {
            if (poly.length > 1) [set addObject:[poly substringToIndex:poly.length - 1]];
        }
        dic[@(i)] = set.allObjects;
    }
    return dic;
}

+ (NSArray<NSArray *> *)flatten:(NSArray *)pinyins polyphones:(NSDictionary<NSNumber *, NSArray *> *)polyphones
{
    if (polyphones.count == 0) return @[pinyins];
    NSUInteger chineseCount = pinyins.count;
    __block NSMutableSet *results = [NSMutableSet setWithCapacity:0];
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

    return results.allObjects;
}

@end
