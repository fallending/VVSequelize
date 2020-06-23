
#import "VVTokenEnumerator.h"
#import "NSString+Tokenizer.h"
#import <NaturalLanguage/NaturalLanguage.h>

typedef NS_ENUM (NSUInteger, VVTokenType) {
    VVTokenTypeNone                = 0,
    VVTokenMultilingualPlaneLetter = 0x00000001,
    VVTokenMultilingualPlaneDigit  = 0x00000002,
    VVTokenMultilingualPlaneSymbol = 0x00000003,
    VVTokenMultilingualPlaneOther  = 0x0000FFFF,
    VVTokenAuxiliaryPlaneOther     = 0xFFFFFFFF,
};

//MARK: - Cursor
@interface VVTokenCursor : NSObject
@property (nonatomic, assign) VVTokenType type;
@property (nonatomic, assign) u_long offset;
@property (nonatomic, assign) u_long len;

+ (instancetype)cursor:(VVTokenType)type offset:(u_long)offset len:(u_long)len;
@end

@implementation VVTokenCursor
+ (instancetype)cursor:(VVTokenType)type offset:(u_long)offset len:(u_long)len
{
    VVTokenCursor *cursor = [VVTokenCursor new];
    cursor.type = type;
    cursor.offset = offset;
    cursor.len = len;
    return cursor;
}

@end

//MARK: - Cursor Tuple
@interface VVTokenCursorTuple : NSObject
@property (nonatomic, strong) NSArray<VVTokenCursor *> *cursors;
@property (nonatomic, assign) VVTokenType type;
@property (nonatomic, assign) NSStringEncoding encoding;
@property (nonatomic, assign) BOOL syllable;

+ (instancetype)tuple:(NSArray<VVTokenCursor *> *)cursors type:(VVTokenType)type encoding:(NSStringEncoding)encoding;

@end

@implementation VVTokenCursorTuple

+ (instancetype)tuple:(NSArray<VVTokenCursor *> *)cursors type:(VVTokenType)type encoding:(NSStringEncoding)encoding;
{
    VVTokenCursorTuple *tuple = [VVTokenCursorTuple new];
    tuple.cursors = cursors;
    tuple.type = type;
    tuple.encoding = encoding;
    return tuple;
}

+ (NSArray<VVTokenCursorTuple *> *)group:(NSArray<VVTokenCursor *> *)cursors
{
    NSMutableArray *results = [NSMutableArray array];
    VVTokenType lastType = VVTokenTypeNone;

    NSMutableArray<VVTokenCursor *> *subCursors = [NSMutableArray array];
    for (VVTokenCursor *cursor in cursors) {
        BOOL change = cursor.type != lastType;
        NSStringEncoding encoding = NSUIntegerMax;
        if (change) {
            switch (lastType) {
                case VVTokenMultilingualPlaneLetter: encoding = NSASCIIStringEncoding; break;
                case VVTokenMultilingualPlaneDigit: encoding = NSASCIIStringEncoding; break;
                case VVTokenMultilingualPlaneSymbol: encoding = NSUTF8StringEncoding; break;
                case VVTokenMultilingualPlaneOther: encoding = NSUTF8StringEncoding; break;
                case VVTokenAuxiliaryPlaneOther:  encoding = NSUTF8StringEncoding; break;
                default: break;
            }
            if (encoding != NSUIntegerMax) {
                VVTokenCursorTuple *tuple = [VVTokenCursorTuple tuple:subCursors.copy type:lastType encoding:encoding];
                [results addObject:tuple];
            }
            lastType = cursor.type;
            [subCursors removeAllObjects];
        }
        [subCursors addObject:cursor];
    }
    return results;
}

@end

//MARK: - Token
@implementation VVToken
+ (instancetype)token:(NSString *)token len:(int)len start:(int)start end:(int)end
{
    VVToken *tk = [VVToken new];
    tk.token = token;
    tk.start = start;
    tk.len = len;
    tk.end = end;
    return tk;
}

- (BOOL)isEqual:(id)object
{
    return object != nil && [object isKindOfClass:VVToken.class] && [(VVToken *)object hash] == self.hash;
}

- (NSUInteger)hash {
    return _token.hash ^ @(_start).hash ^ @(_len).hash ^ @(_end).hash;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[%2i-%2i|%2i|0x%09lx]: %@ ", _start, _end, _len, self.hash, _token];
}

@end

//MARK: - Enumerator -
@implementation VVTokenEnumerator

// MARK: - public

static NSMutableDictionary<NSNumber *, Class<VVTokenEnumeratorProtocol> > *_vv_emumerators;

+ (void)registerEnumerator:(Class<VVTokenEnumeratorProtocol>)cls forMethod:(VVTokenMethod)method {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _vv_emumerators = [NSMutableDictionary dictionary];
    });
    _vv_emumerators[@(method)] = cls;
}

+ (NSArray<VVToken *> *)enumerate:(NSString *)input method:(VVTokenMethod)method mask:(VVTokenMask)mask
{
    if (input.length <= 0) return @[];
    NSString *source = input.lowercaseString;
    if (mask & VVTokenMaskTransform) source = source.simplifiedChineseString;
    const char *cSource = source.cLangString;
    NSArray *array = @[];
    switch (method) {
        case VVTokenMethodApple:
            array = [self enumerateWithApple:cSource mask:mask];
            break;

        case VVTokenMethodSequelize:
            array = [self enumerateWithSequelize:cSource mask:mask];
            break;

        case VVTokenMethodNatual:
            array = [self enumerateWithNatual:cSource mask:mask];
            break;

        default: {
            Class<VVTokenEnumeratorProtocol> cls = _vv_emumerators[@(method)];
            if (cls) array = [cls enumerate:input method:method mask:mask];
        } break;
    }
    NSSet *set = [NSSet setWithArray:array];
    NSArray *results = [set.allObjects sortedArrayUsingComparator:^NSComparisonResult (VVToken *tk1, VVToken *tk2) {
        return tk1.start == tk2.start ? (tk1.end < tk2.end ? NSOrderedAscending : NSOrderedDescending) : (tk1.start < tk2.start ? NSOrderedAscending : NSOrderedDescending);
    }];
    return results;
}

+ (NSArray<VVToken *> *)enumerateCString:(const char *)input method:(VVTokenMethod)method mask:(VVTokenMask)mask
{
    NSString *string = [NSString stringWithUTF8String:(input ? : "")];
    return [self enumerate:string method:method mask:mask];
}

// MARK: - Apple
+ (NSArray<VVToken *> *)enumerateWithApple:(const char *)cSource mask:(VVTokenMask)mask
{
    NSString *source = [NSString stringWithUTF8String:cSource];
    NSMutableArray *results = [NSMutableArray array];

    CFRange range = CFRangeMake(0, source.length);
    CFLocaleRef locale = CFLocaleCopyCurrent(); //need CFRelease!

    // create tokenizer
    CFStringTokenizerRef tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, (CFStringRef)source, range, kCFStringTokenizerUnitWordBoundary, locale);

    //token status
    CFStringTokenizerTokenType tokenType = CFStringTokenizerGoToTokenAtIndex(tokenizer, 0);

    while (tokenType != kCFStringTokenizerTokenNone) {
        @autoreleasepool {
            // get current range
            range = CFStringTokenizerGetCurrentTokenRange(tokenizer);
            NSString *sub = [source substringWithRange:NSMakeRange(range.location, range.length)];
            const char *pre = [source substringWithRange:NSMakeRange(0, range.location)].cLangString;
            const char *token = sub.cLangString;
            int start = (int)strlen(pre);
            int len = (int)strlen(token);
            int end = start + len;

            if (len > 0 && (unsigned char)token[0] >= 0xFC) {
                int hzlen = 3;
                for (int i = 0; i < len; i += 3) {
                    NSString *hz = [[NSString alloc] initWithBytes:token + i length:hzlen encoding:NSUTF8StringEncoding];
                    if (!hz) continue;
                    VVToken *tk = [VVToken token:hz len:hzlen start:(int)(start + i) end:(int)(start + i + hzlen)];
                    [results addObject:tk];
                }
            } else {
                [results addObject:[VVToken token:sub len:len start:start end:end]];
            }
            // get next token
            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer);
        }
    }

    // release
    if (locale != NULL) CFRelease(locale);
    if (tokenizer) CFRelease(tokenizer);

    // other tokens
    if (mask > 0) {
        [results addObjectsFromArray:[self extraTokens:cSource mask:mask]];
    }

    return results;
}

// MARK: - Natual Language
+ (NSArray<VVToken *> *)enumerateWithNatual:(const char *)cSource mask:(VVTokenMask)mask
{
    __block NSMutableArray *results = [NSMutableArray array];
    if (@available(iOS 12.0, *)) {
        NSString *source = [NSString stringWithUTF8String:cSource];
        NLTokenizer *tokenizer = [[NLTokenizer alloc] initWithUnit:NLTokenUnitWord];
        tokenizer.string = source;

        NSRange range = NSMakeRange(0, tokenizer.string.length);
        [tokenizer enumerateTokensInRange:range usingBlock:^(NSRange tokenRange, NLTokenizerAttributes flags, BOOL *stop) {
            @autoreleasepool {
                NSString *tk = [tokenizer.string substringWithRange:tokenRange];
                const char *pre = [tokenizer.string substringToIndex:tokenRange.location].cLangString;
                const char *token = tk.cLangString;
                int start = (int)strlen(pre);
                int len   = (int)strlen(token);
                int end   = (int)(start + len);
                [results addObject:[VVToken token:tk len:len start:start end:end]];
                if (*stop) return;
            }
        }];
    }

    // other tokens
    if (mask > 0) {
        [results addObjectsFromArray:[self extraTokens:cSource mask:mask]];
    }

    return results;
}

// MARK: - Sequelize
+ (NSArray<VVToken *> *)enumerateWithSequelize:(const char *)cSource mask:(VVTokenMask)mask
{
    // generate cursors
    NSArray<VVTokenCursor *> *cursors = [self cursorsWithCString:cSource];
    NSArray<VVTokenCursorTuple *> *tuples = [VVTokenCursorTuple group:cursors];

    NSMutableArray *results = [NSMutableArray array];
    if (mask > 0) {
        NSArray *extras = [self extraTokens:cSource tuples:tuples mask:mask];
        [results addObjectsFromArray:extras];
    }

    // essential
    NSArray *tokens = [self sequelizeTokensWithCString:cSource tuples:tuples];
    [results addObjectsFromArray:tokens];
    return results;
}

// MARK: - Extra Tokens
+ (NSArray<VVToken *> *)extraTokens:(const char *)cSource mask:(VVTokenMask)mask
{
    NSArray<VVTokenCursor *> *cursors = [self cursorsWithCString:cSource];
    NSArray<VVTokenCursorTuple *> *tuples = [VVTokenCursorTuple group:cursors];
    return [self extraTokens:cSource tuples:tuples mask:mask];
}

+ (NSArray<VVToken *> *)extraTokens:(const char *)cSource
                             tuples:(NSArray<VVTokenCursorTuple *> *)tuples
                               mask:(VVTokenMask)mask
{
    // pinyin
    NSArray *pinyinTokens = [self pinyinTokensWithCString:cSource tuples:tuples mask:mask];

    // pinyin segmentation
    NSArray *syllableTokens = [self syllableTokensWithCString:cSource tuples:tuples mask:mask];

    // number
    NSArray *numberTokens = [self numberTokensWithCString:cSource mask:mask];

    NSMutableArray *results = [NSMutableArray array];
    [results addObjectsFromArray:pinyinTokens];
    [results addObjectsFromArray:syllableTokens];
    [results addObjectsFromArray:numberTokens];
    return results;
}

// MARK: - Utils
+ (BOOL)isSymbol:(unichar)ch {
    return [VVPinYin.shared.symbolSet characterIsMember:ch];
}

+ (BOOL)isSupportedPunctuation:(unichar)ch {
    static NSCharacterSet *_symbolSet;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _symbolSet = [NSCharacterSet characterSetWithCharactersInString:@"#@"];
    });
    BOOL ret = [_symbolSet characterIsMember:ch];
    return ret;
}

// MARK: - Curosrs
+ (NSArray<VVTokenCursor *> *)cursorsWithCString:(const char *)cSource
{
    NSUInteger inputLen = strlen(cSource ? : "");
    if (inputLen == 0) return @[];

    NSMutableArray *cursors = [NSMutableArray array];
    u_long len = 0;
    VVTokenType type = VVTokenTypeNone;
    BOOL end = NO;

    for (u_long offset = 0; offset < inputLen;) {
        @autoreleasepool {
            const unsigned char ch = cSource[offset];
            if (ch < 0xC0) {
                len = 1;
                if (ch >= 0x30 && ch <= 0x39) {
                    type = VVTokenMultilingualPlaneDigit;
                } else if ((ch >= 0x41 && ch <= 0x5a) || (ch >= 0x61 && ch <= 0x7a)) {
                    type = VVTokenMultilingualPlaneLetter;
                } else {
                    type = [self isSymbol:ch] ? ([self isSupportedPunctuation:ch] ? VVTokenMultilingualPlaneSymbol : VVTokenTypeNone) : VVTokenMultilingualPlaneOther;
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
                        type = VVTokenTypeNone;
                        len = inputLen - j;
                        end = YES;
                    }
                }
                if (!end) {
                    type = [self isSymbol:unicode] ? VVTokenMultilingualPlaneSymbol : VVTokenMultilingualPlaneOther;
                }
            } else {
                type = VVTokenAuxiliaryPlaneOther;
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

            VVTokenCursor *cursor = [VVTokenCursor cursor:type offset:offset len:len];
            [cursors addObject:cursor];
            offset += len;
        }
    }
    VVTokenCursor *cursor = [VVTokenCursor cursor:VVTokenTypeNone offset:inputLen len:0];
    [cursors addObject:cursor];

    return cursors;
}

// MARK: - Combine

+ (NSArray<VVToken *> *)wordTokensByCombine:(const char *)cSource
                                    cursors:(NSArray<VVTokenCursor *> *)cursors
                                   encoding:(NSStringEncoding)encoding
                                   quantity:(NSUInteger)quantity
{
    return [self wordTokensByCombine:cSource cursors:cursors encoding:encoding quantity:quantity tail:YES];
}

+ (NSArray<VVToken *> *)wordTokensByCombine:(const char *)cSource
                                    cursors:(NSArray<VVTokenCursor *> *)cursors
                                   encoding:(NSStringEncoding)encoding
                                   quantity:(NSUInteger)quantity
                                       tail:(BOOL)tail
{
    if (cursors.count == 0 || encoding == NSUIntegerMax || quantity == 0) return @[];

    NSMutableArray *results = [NSMutableArray array];
    NSInteger count = cursors.count;
    NSInteger loop = tail ? count : count - quantity + 1;
    for (NSInteger i = 0; i < loop; i++) {
        VVTokenCursor *c1 = cursors[i];
        u_long offset = c1.offset;
        u_long len = c1.len;
        for (NSInteger j = 1; j < quantity && i + j < count; j++) {
            VVTokenCursor *c2 = cursors[i + j];
            len += c2.len;
        }
        NSString *string = [[NSString alloc] initWithBytes:cSource + offset length:len encoding:encoding];
        if (string.length > 0) {
            VVToken *tk = [VVToken token:string len:(int)len start:(int)offset end:(int)(offset + len)];
            [results addObject:tk];
        }
    }

    return results;
}

+ (NSArray<VVToken *> *)sequelizeTokensWithCString:(const char *)cSource
                                            tuples:(NSArray<VVTokenCursorTuple *> *)tuples
{
    NSMutableArray *results = [NSMutableArray array];
    for (VVTokenCursorTuple *tuple in tuples) {
        if (tuple.syllable) continue;
        NSUInteger quantity = tuple.encoding == NSASCIIStringEncoding ? 3 : 2;
        NSArray<VVToken *> *tokens = [self wordTokensByCombine:cSource cursors:tuple.cursors encoding:tuple.encoding quantity:quantity];
        [results addObjectsFromArray:tokens];
    }
    return results;
}

// MARK: - VVTokenMaskPinyin, VVTokenMaskAbbreviation
+ (NSArray<VVToken *> *)pinyinTokensWithCString:(const char *)cSource
                                         tuples:(NSArray<VVTokenCursorTuple *> *)tuples
                                           mask:(VVTokenMask)mask
{
    BOOL flag = (mask & VVTokenMaskPinyin);
    if (!flag || tuples.count == 0) return @[];
    BOOL abbr = mask & VVTokenMaskAbbreviation;

    NSMutableArray *results = [NSMutableArray array];
    for (VVTokenCursorTuple *tuple in tuples) {
        if (tuple.type != VVTokenMultilingualPlaneOther || tuple.cursors.count == 0) continue;

        NSArray *tokens = [self wordTokensByCombine:cSource cursors:tuple.cursors encoding:tuple.encoding quantity:2];
        for (VVToken *tk in tokens) {
            VVPinYinFruit *fruit = tk.token.pinyins;
            for (NSString *full in fruit.fulls) {
                int len = (int)strlen(full.cLangString ? : "");
                VVToken *token = [VVToken token:full len:len start:tk.start end:tk.end];
                [results addObject:token];
            }
        }

        if (!abbr) continue;
        tokens = [self wordTokensByCombine:cSource cursors:tuple.cursors encoding:tuple.encoding quantity:3 tail:NO];
        for (VVToken *tk in tokens) {
            VVPinYinFruit *fruit = tk.token.pinyins;
            for (NSString *abbr in fruit.abbrs) {
                int len = (int)strlen(abbr.cLangString ? : "");
                VVToken *token = [VVToken token:abbr len:len start:tk.start end:tk.end];
                [results addObject:token];
            }
        }
    }

    return results;
}

//MARK: - VVTokenMaskSyllable
+ (NSArray<VVToken *> *)syllableTokensWithCString:(const char *)cString
                                           tuples:(NSArray<VVTokenCursorTuple *> *)tuples
                                             mask:(VVTokenMask)mask
{
    BOOL flag = (mask & VVTokenMaskSyllable);
    if (!flag || tuples.count == 0) return @[];

    NSMutableArray *results = [NSMutableArray array];
    for (VVTokenCursorTuple *tuple in tuples) {
        if (tuple.type != VVTokenMultilingualPlaneLetter || tuple.cursors.count == 0) continue;
        u_long offset = tuple.cursors.firstObject.offset;
        u_long len = tuple.cursors.count;
        NSString *string = [[NSString alloc] initWithBytes:cString + offset length:len encoding:tuple.encoding];
        NSArray<NSString *> *pinyins = string.pinyinSegmentation;

        int start = (int)offset;
        for (NSUInteger i = 0; i < pinyins.count; i++) {
            NSString *tkString = pinyins[i];
            int flen = (int)tkString.length;
            int tkLen = flen;
            if (i + 1 < pinyins.count) {
                NSString *second = pinyins[i + 1];
                tkString = [tkString stringByAppendingString:second];
                tkLen += (int)second.length;
            }
            VVToken *token = [VVToken new];
            token.start = start;
            token.end = start + tkLen;
            token.len = tkLen;
            token.token = tkString;
            [results addObject:token];

            tuple.syllable = YES;
            start += flen;
        }
    }

    return results;
}

// MARK: - VVTokenMaskNumber
+ (NSArray<VVToken *> *)numberTokensWithCString:(const char *)cString
                                           mask:(VVTokenMask)mask
{
    BOOL flag = (mask & VVTokenMaskNumber);
    if (!flag) return @[];

    unsigned long len = strlen(cString);
    if (len <= 3) return @[];
    char *copied = (char *)malloc(len + 1);
    strncpy(copied, cString, len);
    copied[len] = 0x0;

    NSMutableArray *array = [NSMutableArray array];
    char *container = (char *)malloc(len + 1);
    memset(container, 0x0, len);

    int offset = 0;
    for (int i = 0; i <= len; i++) {
        char ch = copied[i];
        BOOL flag = (ch >= '0' && ch <= '9') || ch == ',';
        if (flag) {
            container[offset] = ch;
            offset++;
        } else {
            if (offset > 0) {
                NSString *numberString = [[NSString alloc] initWithBytes:container length:offset encoding:NSASCIIStringEncoding];
                [array addObject:@[numberString, @(i - offset)]];
            }
            memset(container, 0x0, len);
            offset = 0;
        }
    }
    free(container);
    free(copied);

    NSMutableArray *results = [NSMutableArray array];
    for (int i = 0; i < array.count; i++) {
        NSArray *sub = array[i];
        NSString *origin = sub.firstObject;
        NSString *number = [origin numberWithoutSeparator];
        if (number.length <= 3 || number.length >= origin.length) continue;
        int offset = (int)[sub.lastObject unsignedIntegerValue];
        const char *subSource = number.cLangString;
        NSArray *subCursors = [self cursorsWithCString:subSource];
        NSArray *tmpTokens = [self wordTokensByCombine:subSource cursors:subCursors encoding:NSASCIIStringEncoding quantity:3];
        NSInteger count = tmpTokens.count;
        NSInteger fill = 3 - count % 3;
        if (fill == 3) fill = 0;

        NSMutableArray *subTokens = [NSMutableArray arrayWithCapacity:number.length];
        for (NSInteger i = 0; i < count - 2; i++) {
            VVToken *token = tmpTokens[i];
            int comma1 = (int)(i + fill) / 3;
            int comma2 =  i >= count - 3 ? 0 : (i + fill) % 3 == 0 ? 0 : 1;
            int pre = offset + comma1;
            token.start += pre;
            token.end += pre + comma2;
            [subTokens addObject:token];
            if ((i + fill) % 3 == 2 && token.token.length == 3) {
                VVToken *tk = [VVToken new];
                tk.start = token.start;
                tk.end = token.end - 1;
                tk.len = token.len - 1;
                tk.token = [token.token substringToIndex:2];
                [subTokens addObject:tk];
            }
        }
        [results addObjectsFromArray:subTokens];
    }
    return results;
}

@end
