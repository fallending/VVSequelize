
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

@implementation VVTokenEnumerator

// MARK: - public
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

        default:
            break;
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
        NSArray *cursors = [self cursorsWithCString:cSource];
        [results addObjectsFromArray:[self allOtherTokens:cSource cursors:cursors mask:mask]];
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
        NSArray *cursors = [self cursorsWithCString:cSource];
        [results addObjectsFromArray:[self allOtherTokens:cSource cursors:cursors mask:mask]];
    }

    return results;
}

// MARK: - Sequelize
+ (NSArray<VVToken *> *)enumerateWithSequelize:(const char *)cSource mask:(VVTokenMask)mask
{
    // generate cursors
    NSArray *cursors = [self cursorsWithCString:cSource];

    // pinyin segmentation
    NSArray *syllableTokens = [self syllableTokensWithCString:cSource mask:mask];
    if (syllableTokens.count > 0) return syllableTokens;

    // essential
    NSArray *tokens = [self sequelizeTokensWithCString:cSource cursors:cursors mask:mask];

    // number
    NSArray *numberTokens = [self numberTokensWithCString:cSource mask:mask];

    return [tokens arrayByAddingObjectsFromArray:numberTokens];
}

// MARK: - all the other tokens
+ (NSArray<VVToken *> *)allOtherTokens:(const char *)source cursors:(NSArray<VVTokenCursor *> *)cursors mask:(VVTokenMask)mask
{
    NSMutableArray *results = [NSMutableArray array];
    NSArray *numberTokens = [self numberTokensWithCString:source mask:mask];
    NSArray *syllableTokens = [self syllableTokensWithCString:source mask:mask];
    [results addObjectsFromArray:numberTokens];
    [results addObjectsFromArray:syllableTokens];
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

// MARK: - Word Tokens
+ (NSArray<VVToken *> *)wordTokensByCombine:(const char *)cSource
                                    cursors:(NSArray<VVTokenCursor *> *)cursors
                                   encoding:(NSStringEncoding)encoding
{
    if (cursors.count == 0) return @[];

    VVTokenCursor *last = cursors.lastObject;
    NSInteger ext = last.type < VVTokenMultilingualPlaneSymbol ? 2 : 1;

    NSMutableArray *results = [NSMutableArray array];
    NSInteger count = cursors.count;
    for (NSInteger i = 0; i < count; i++) {
        VVTokenCursor *c1 = cursors[i];
        u_long offset = c1.offset;
        u_long len = c1.len;
        for (NSInteger j = 1; j <= ext && i + j < count; j++) {
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
                                           cursors:(NSArray<VVTokenCursor *> *)cursors
                                              mask:(VVTokenMask)mask
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
                NSArray *tokens = [self wordTokensByCombine:cSource cursors:subCursors encoding:encoding];
                [results addObjectsFromArray:tokens];
                if (lastType == VVTokenMultilingualPlaneOther && (mask & VVTokenMaskPinyin)) {
                    NSArray *pytokens = [self pinyinTokensWithCString:cSource cursors:subCursors mask:mask];
                    [results addObjectsFromArray:pytokens];
                }
            }
            lastType = cursor.type;
            [subCursors removeAllObjects];
        }
        [subCursors addObject:cursor];
    }
    return results;
}

// MARK: - VVTokenMaskPinyin, VVTokenMaskInitial
+ (NSArray<VVToken *> *)pinyinTokensWithCString:(const char *)cSource
                                        cursors:(NSArray<VVTokenCursor *> *)cursors
                                           mask:(VVTokenMask)mask
{
    BOOL flag = strlen(cSource ? : "") < (mask & VVTokenMaskPinyin);
    VVTokenCursor *last = cursors.lastObject;
    if (!flag || cursors.count == 0 || last.type != VVTokenMultilingualPlaneOther) return @[];

    NSMutableArray *results = [NSMutableArray array];
    NSArray *fills = @[@(1)]; // @[@(1), @(2)]; // Now only full pinyin is supported.
    for (NSNumber *f in fills) {
        NSInteger fill = [f integerValue];
        NSInteger count = cursors.count;
        for (NSInteger i = 0; i < count; i++) {
            VVTokenCursor *c1 = cursors[i];
            u_long offset = c1.offset;
            u_long len = c1.len;
            for (NSInteger j = 1; j <= fill && i + j < count; j++) {
                VVTokenCursor *c2 = cursors[i + j];
                len += c2.len;
            }
            NSString *string = [[NSString alloc] initWithBytes:cSource + offset length:len encoding:NSUTF8StringEncoding];
            BOOL valid = (fill == 1 && ((cursors.count >= 2 && string.length == 2) || (cursors.count < 2 && string.length == cursors.count))) || (fill == 2 && ((cursors.count >= 3 && string.length == 3) || (cursors.count < 3 && string.length == cursors.count)));
            if (valid) {
                VVPinYinFruit *fruit = string.pinyins;
                if (fill == 1) {
                    // full pinyin of two charactors
                    for (NSString *tkString in fruit.fulls) {
                        VVToken *tk = [VVToken token:tkString len:(int)(tkString.length) start:(int)offset end:(int)(offset + len)];
                        [results addObject:tk];
                    }
                } else {
                    // abbreviated pinyin of three charactors
                    for (NSString *tkString in fruit.abbrs) {
                        VVToken *tk = [VVToken token:tkString len:(int)(tkString.length) start:(int)offset end:(int)(offset + len)];
                        [results addObject:tk];
                    }
                }
            }
        }
    }
    return results;
}

//MARK: - VVTokenMaskSyllable
+ (NSArray<VVToken *> *)syllableTokensWithCString:(const char *)cString
                                             mask:(VVTokenMask)mask
{
    BOOL flag = (mask & VVTokenMaskSyllable);
    if (!flag) return @[];

    NSString *string = [NSString stringWithUTF8String:cString];
    NSArray<NSString *> *pinyins = string.pinyinSegmentation;

    if (pinyins.count == 0) return @[];
    if (pinyins.count == 1) {
        NSString *pinyin = pinyins.firstObject;
        int len = (int)(pinyin.length);
        VVToken *token = [VVToken new];
        token.start = 0;
        token.end = len;
        token.len = len;
        token.token = pinyin;
        return @[token];
    }

    NSMutableArray *results = [NSMutableArray array];
    int loc = 0;
    for (NSInteger i = 0; i < pinyins.count - 1; i++) {
        NSString *first = pinyins[i];
        NSString *second = pinyins[i + 1];
        int len = (int)(first.length + second.length);
        VVToken *token = [VVToken new];
        token.start = loc;
        token.end = loc + len;
        token.len = len;
        token.token = [first stringByAppendingString:second];
        [results addObject:token];
        loc += first.length;
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
        NSArray *tmpTokens = [self wordTokensByCombine:subSource cursors:subCursors encoding:NSASCIIStringEncoding];
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
