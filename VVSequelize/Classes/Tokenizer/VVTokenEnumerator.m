
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
    return [NSString stringWithFormat:@" %@ ,%@,%@,%@,%@", _token, @(_start), @(_end), @(_len), @(self.hash)];
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@" %@ ,%@,%@,%@,%@", _token, @(_start), @(_end), @(_len), @(self.hash)];
}

@end

@implementation VVTokenEnumerator

// MARK: - public
+ (NSArray<VVToken *> *)enumerate:(NSString *)input method:(VVTokenMethod)method mask:(VVTokenMask)mask
{
    if (input.length <= 0) return @[];
    NSString *source = input.lowercaseString;
    if (mask & VVTokenMaskTransform) source = source.simplifiedChineseString;
    const char *cSource = source.UTF8String ? : "";
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
    NSArray *results = [NSOrderedSet orderedSetWithArray:array].array;
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
            const char *pre = [source substringWithRange:NSMakeRange(0, range.location)].UTF8String ? : "";
            const char *token = sub.UTF8String ? : "";
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
    if (mask & VVTokenMaskExtra) {
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
                const char *pre = [tokenizer.string substringToIndex:tokenRange.location].UTF8String;
                const char *token = tk.UTF8String;
                int start = (int)strlen(pre);
                int len   = (int)strlen(token);
                int end   = (int)(start + len);
                [results addObject:[VVToken token:tk len:len start:start end:end]];
                if (*stop) return;
            }
        }];
    }

    // other tokens
    if (mask & VVTokenMaskExtra) {
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

    NSMutableArray *results = [NSMutableArray array];

    // essential
    NSArray *tokens = [self sequelizeTokensWithCString:cSource cursors:cursors mask:mask];
    [results addObjectsFromArray:tokens];

    // other tokens
    if (mask & VVTokenMaskExtra) {
        [results addObjectsFromArray:[self allOtherTokens:cSource cursors:cursors mask:mask]];
    }

    return results;
}

// MARK: - all the other tokens
+ (NSArray<VVToken *> *)allOtherTokens:(const char *)source cursors:(NSArray<VVTokenCursor *> *)cursors mask:(VVTokenMask)mask
{
    NSMutableArray *results = [NSMutableArray array];
    NSArray *pinyinTokens = [self pinyinTokensWithCString:source cursors:cursors mask:mask];
    NSArray *splitedPinyinTokens = [self splitedPinyinTokensWithCString:source cursors:cursors mask:mask];
    NSArray *numberTokens = [self numberTokensWithCString:source start:0 mask:mask];
    [results addObjectsFromArray:pinyinTokens];
    [results addObjectsFromArray:splitedPinyinTokens];
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

// MARK: - Word Tokens
+ (NSArray<VVToken *> *)wordTokensByCombine:(const char *)cSource
                                    cursors:(NSArray<VVTokenCursor *> *)cursors
                                   encoding:(NSStringEncoding)encoding
{
    if (cursors.count == 0) return @[];

    NSMutableArray *results = [NSMutableArray array];
    void (^ addToken)(u_long, u_long) = ^(u_long offset, u_long len) {
        NSString *string = [[NSString alloc] initWithBytes:cSource + offset length:len encoding:encoding];
        if (string.length > 0) {
            VVToken *tk = [VVToken token:string len:(int)len start:(int)offset end:(int)(offset + len)];
            [results addObject:tk];
        }
    };

    void (^ addOnceToken)(VVTokenCursor *) = ^(VVTokenCursor *c) {
        NSString *string = [[NSString alloc] initWithBytes:cSource + c.offset length:c.len encoding:encoding];
        if (string.length > 0) {
            //string = [string stringByAppendingString:string];
            VVToken *tk = [VVToken token:string len:(int)c.len start:(int)c.offset end:(int)(c.offset + c.len)];
            [results addObject:tk];
        }
    };

    //addTwiceToken(cursors.firstObject);
    NSUInteger count = cursors.count - 1;
    for (NSUInteger i = 0; i < count; i++) {
        VVTokenCursor *c1 = cursors[i];
        VVTokenCursor *c2 = cursors[i + 1];
        addToken(c1.offset, c1.len + c2.len);
    }
    addOnceToken(cursors.lastObject);
    return results;
}

+ (NSArray<VVToken *> *)sequelizeTokensWithCString:(const char *)cSource
                                           cursors:(NSArray<VVTokenCursor *> *)cursors
                                              mask:(VVTokenMask)mask
{
    NSMutableArray *results = [NSMutableArray array];
    VVTokenType lastType = VVTokenTypeNone;
    BOOL dochar = (mask & VVTokenMaskCharacter);

    NSMutableArray<VVTokenCursor *> *subCursors = [NSMutableArray array];
    for (VVTokenCursor *cursor in cursors) {
        BOOL change = cursor.type != lastType;
        NSStringEncoding encoding = 0;
        if (change) {
            switch (lastType) {
                case VVTokenMultilingualPlaneLetter: encoding = NSASCIIStringEncoding; break;
                case VVTokenMultilingualPlaneDigit: encoding = NSASCIIStringEncoding; break;
                case VVTokenMultilingualPlaneSymbol: encoding = dochar ? 0 : NSUTF8StringEncoding; break;
                case VVTokenMultilingualPlaneOther: encoding =  dochar ? 0 : NSUTF8StringEncoding; break;
                case VVTokenAuxiliaryPlaneOther:  encoding =  dochar ? 0 : NSUTF8StringEncoding; break;
                default: break;
            }
            if (encoding > 0) {
                NSArray *tokens = [self wordTokensByCombine:cSource cursors:subCursors encoding:encoding];
                [results addObjectsFromArray:tokens];
            }
            lastType = cursor.type;
            [subCursors removeAllObjects];
        }

        if (dochar) {
            encoding = 0;
            switch (cursor.type) {
                case VVTokenMultilingualPlaneSymbol: encoding = NSUTF8StringEncoding; break;
                case VVTokenMultilingualPlaneOther: encoding = NSUTF8StringEncoding; break;
                case VVTokenAuxiliaryPlaneOther:  encoding = NSUTF8StringEncoding; break;
                default: break;
            }

            if (encoding > 0) {
                NSString *string = [[NSString alloc] initWithBytes:cSource + cursor.offset length:cursor.len encoding:encoding];
                if (string.length > 0) {
                    VVToken *token = [VVToken token:string len:(int)strlen(string.UTF8String) start:(int)cursor.offset end:(int)(cursor.offset + cursor.len)];
                    [results addObject:token];
                }
            }
        }
        [subCursors addObject:cursor];
    }
    return results;
}

// MARK: - VVTokenMaskPinyin, VVTokenMaskFirstLetter
+ (NSArray<VVToken *> *)pinyinTokensWithCString:(const char *)cSource
                                        cursors:(NSArray<VVTokenCursor *> *)cursors
                                           mask:(VVTokenMask)mask
{
    BOOL flag = strlen(cSource ? : "") < (mask & VVTokenMaskPinyin);
    if (!flag) return @[];

    NSMutableArray *results = [NSMutableArray array];
    for (VVTokenCursor *cursor in cursors) {
        if (cursor.type != VVTokenMultilingualPlaneOther) continue;

        NSString *string = [[NSString alloc] initWithBytes:cSource + cursor.offset length:cursor.len encoding:NSUTF8StringEncoding];
        if (string.length == 0) continue;

        NSArray<NSArray<NSString *> *> *pinyins = [string pinyinsAtIndex:0];
        NSArray<NSString *> *fulls = pinyins.firstObject;
        for (NSString *pinyin in fulls) {
            VVToken *pytk = [VVToken token:pinyin len:(int)pinyin.length start:(int)cursor.offset end:(int)(cursor.offset + cursor.len)];
            [results addObject:pytk];
        }
        if (mask & VVTokenMaskFirstLetter) {
            NSArray<NSString *> *firsts = pinyins.lastObject;
            for (NSString *pinyin in firsts) {
                VVToken *pytk = [VVToken token:pinyin len:(int)pinyin.length start:(int)cursor.offset end:(int)(cursor.offset + cursor.len)];
                [results addObject:pytk];
            }
        }
    }
    return results;
}

// MARK: - VVTokenMaskSplitPinyin
+ (NSArray<VVToken *> *)pinyinTokensBySplit:(NSString *)fragment start:(int)start
{
    NSArray<NSArray<NSString *> *> *splited = [fragment splitIntoPinyins];
    NSMutableSet *set = [NSMutableSet set];
    for (NSArray<NSString *> *pinyins in splited) {
        int offset = 0;
        for (int i = 0; i < pinyins.count - 1; i++) {
            NSString *pinyin = pinyins[i];
            int len = (int)pinyin.length;
            VVToken *tk = [VVToken token:pinyin len:len start:(start + offset) end:(start + offset + len)];
            [set addObject:tk];
            offset += len;
        }
    }
    NSArray *results = [set.allObjects sortedArrayUsingComparator:^NSComparisonResult (VVToken *tk1, VVToken *tk2) {
        return tk1.start < tk2.start ? NSOrderedAscending :
        (tk1.start > tk2.start ? NSOrderedDescending :
         (tk1.len < tk2.len ? NSOrderedAscending :
          (tk1.len > tk2.len ? NSOrderedDescending : NSOrderedSame)));
    }];
    return results;
}

+ (NSArray<VVToken *> *)splitedPinyinTokensWithCString:(const char *)cSource
                                               cursors:(NSArray<VVTokenCursor *> *)cursors
                                                  mask:(VVTokenMask)mask
{
    BOOL flag = (mask & VVTokenMaskSplitPinyin);
    if (!flag) return @[];

    NSMutableArray *results = [NSMutableArray array];
    VVTokenType lastType = VVTokenTypeNone;
    u_long offset = 0;
    u_long len = 0;

    for (VVTokenCursor *cursor in cursors) {
        BOOL change = cursor.type != lastType;
        if (change) {
            if (lastType == VVTokenMultilingualPlaneLetter) {
                NSString *string = [[NSString alloc] initWithBytes:cSource + offset length:len encoding:NSASCIIStringEncoding];
                if (string.length > 0) {
                    NSArray<VVToken *> *tks = [self pinyinTokensBySplit:string start:(int)offset];
                    [results addObjectsFromArray:tks];
                }
            }
            offset = (int)cursor.offset;
            len = 0;
            lastType = cursor.type;
        }
        len += cursor.len;
    }
    return results;
}

// MARK: - VVTokenMaskNumber
+ (NSArray<VVToken *> *)numberTokensWithCString:(const char *)cString
                                          start:(int)start
                                           mask:(VVTokenMask)mask
{
    BOOL flag = (mask & VVTokenMaskNumber);
    if (!flag) return @[];

    unsigned long len = strlen(cString);
    if (len == 0) return @[];

    NSMutableArray *array = [NSMutableArray array];
    NSMutableString *s_num = [NSMutableString string];
    int offset = -1;

    for (int i = 0; i < len; i++) {
        char ch = cString[i];
        if (ch >= '0' && ch <= '9') {
            if (ch > '0' && offset < 0) {
                offset = i;
            }
            if (offset >= 0) {
                [s_num appendFormat:@"%i", ch - '0'];
            }
        } else if (offset >= 0) {
            switch (ch) {
                case ',':
                    [s_num appendString:@","];
                    break;
                default:
                    [array addObject:@[s_num, @(offset)]];
                    s_num = [NSMutableString string];
                    offset = -1;
                    break;
            }
        }
    }
    if (offset >= 0) {
        [array addObject:@[s_num, @(offset)]];
    }

    NSMutableArray *results = [NSMutableArray array];
    for (int i = 0; i < array.count; i++) {
        NSArray *sub = array[i];
        NSString *numstr = sub.firstObject;
        int offset = (int)[sub.lastObject unsignedIntegerValue];
        NSArray<NSString *> *numbers = [numstr numberStringsForTokenize];
        if (numbers.count >= 2) {
            for (NSString *num in numbers) {
                const char *token = num.UTF8String ? : "";
                int len = (int)strlen(token);
                if (len <= 0) continue;
                [results addObject:[VVToken token:num len:len start:start + offset end:start + offset + (int)numstr.length]];
            }
        }
    }
    return results;
}

@end
