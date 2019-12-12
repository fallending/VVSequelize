
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
    return [NSString stringWithFormat:@"'%@',%@,%@,%@,%@", _token, @(_start), @(_end), @(_len), @(self.hash)];
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"'%@',%@,%@,%@,%@", _token, @(_start), @(_end), @(_len), @(self.hash)];
}

@end

@implementation VVTokenEnumerator

+ (NSArray<VVToken *> *)enumerate:(NSString *)input method:(VVTokenMethod)method mask:(VVTokenMask)mask
{
    VVTokenMask _mask = mask == 0 ? VVTokenMaskDeault : mask;
    switch (method) {
        case VVTokenMethodApple:
            return [self enumerateWithApple:input mask:_mask];

        case VVTokenMethodSequelize:
            return [self enumerateWithVVDB:input mask:_mask];

        case VVTokenMethodNatual:
            return [self enumerateWithNatual:input mask:_mask];

        default:
            return @[];
    }
}

+ (NSArray<VVToken *> *)enumerateWithApple:(NSString *)input mask:(VVTokenMask)mask
{
    if (input.length <= 0) return @[];
    NSString *source = input.lowercaseString;
    if (mask & VVTokenMaskTransform) source = source.simplifiedChineseString;

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
    u_long len = mask & VVTokenMaskPinyin;
    u_long nSource = strlen(source.UTF8String ? : "");
    if (nSource < len) {
        NSArray *pytks = [self enumeratePinyins:source start:0 end:(int)strlen(source.UTF8String ? : "")];
        [results addObjectsFromArray:pytks];
    }
    NSArray *numtks = [self enumerateNumbers:source];
    [results addObjectsFromArray:numtks];

    // release
    if (locale != NULL) CFRelease(locale);
    if (tokenizer) CFRelease(tokenizer);

    return results;
}

+ (NSArray<VVToken *> *)enumerateWithNatual:(NSString *)input mask:(VVTokenMask)mask
{
    if (input.length <= 0) return @[];
    NSString *source = input.lowercaseString.simplifiedChineseString;

    __block NSMutableArray *results = [NSMutableArray array];
    if (@available(iOS 12.0, *)) {
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

    return results;
}

+ (BOOL)isSymbol:(unichar)ch {
    static NSCharacterSet *_symbolSet;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *set = [NSMutableCharacterSet new];
        [set formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet nonBaseCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet illegalCharacterSet]];
        _symbolSet = set;
    });
    return [_symbolSet characterIsMember:ch];
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

+ (NSArray<VVTokenCursor *> *)cursorsWithCString:(const char *)cSource
{
    NSUInteger inputLen = strlen(cSource);
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

+ (NSArray<VVToken *> *)wordTokensWithCString:(const char *)cSource
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
    if (cursors.count == 1) {
        VVTokenCursor *c = cursors.firstObject;
        addToken(c.offset, c.len);
    } else {
        NSUInteger count = cursors.count - 1;
        for (NSUInteger i = 0; i < count; i++) {
            VVTokenCursor *c1 = cursors[i];
            VVTokenCursor *c2 = cursors[i + 1];
            addToken(c1.offset, c1.len + c2.len);
        }
    }
    return results;
}

+ (NSArray<VVToken *> *)wordTokensWithCString:(const char *)cSource
                                      cursors:(NSArray<VVTokenCursor *> *)cursors
                                         mask:(VVTokenMask)mask
{
    NSMutableArray *results = [NSMutableArray array];
    VVTokenType lastType = VVTokenTypeNone;
    u_long offset = 0;
    u_long len = 0;
    BOOL dochar = (mask & VVTokenMaskCharacter);
    BOOL dosplit = (mask & VVTokenMaskSplitPinyin);
    BOOL dopy = strlen(cSource ? : "") < (mask & VVTokenMaskPinyin);

    NSMutableArray<VVTokenCursor *> *array = [NSMutableArray array];
    for (VVTokenCursor *cursor in cursors) {
        BOOL change = cursor.type != lastType;
        if (change) {
            BOOL cansplit = NO;
            switch (lastType) {
                case VVTokenMultilingualPlaneLetter: cansplit = YES;
                case VVTokenMultilingualPlaneDigit: {
                    NSArray *tks = [self wordTokensWithCString:cSource cursors:array encoding:NSASCIIStringEncoding];
                    [results addObjectsFromArray:tks];
                    break;
                }
                default: break;
            }
            //MARK: VVTokenMaskSplitPinyin
            if (dosplit && len > 0 && cansplit) {
                NSString *string = [[NSString alloc] initWithBytes:cSource + offset length:len encoding:NSASCIIStringEncoding];
                NSArray<VVToken *> *tks = [self splitIntoPinyins:string start:(int)offset];
                [results addObjectsFromArray:tks];
            }

            offset = (int)cursor.offset;
            len = 0;
            [array removeAllObjects];
        }

        BOOL canpy = NO;
        NSStringEncoding encoding = 0;
        switch (cursor.type) {
            case VVTokenMultilingualPlaneLetter: encoding = dochar ? NSASCIIStringEncoding : 0; break;
            case VVTokenMultilingualPlaneDigit: encoding = dochar ? NSASCIIStringEncoding : 0; break;
            case VVTokenMultilingualPlaneSymbol: encoding = NSUTF8StringEncoding; break;
            case VVTokenMultilingualPlaneOther: encoding = NSUTF8StringEncoding; canpy = YES; break;
            case VVTokenAuxiliaryPlaneOther:  encoding = NSUTF8StringEncoding; break;
            default: break;
        }

        if (encoding > 0) {
            NSString *string = [[NSString alloc] initWithBytes:cSource + cursor.offset length:cursor.len encoding:encoding];
            if (string.length > 0) {
                //MARK: VVTokenMaskPinyin
                if (dopy && canpy) {
                    NSArray *pinyins = [string pinyinsForTokenize];
                    for (NSString *pinyin in pinyins) {
                        VVToken *pytk = [VVToken token:pinyin len:(int)cursor.len start:(int)cursor.offset end:(int)(cursor.offset + cursor.len)];
                        [results addObject:pytk];
                    }
                }
                VVToken *tk = [VVToken token:string len:(int)cursor.len start:(int)cursor.offset end:(int)(cursor.offset + cursor.len)];
                [results addObject:tk];
            }
        }

        len += cursor.len;
        [array addObject:cursor];
        lastType = cursor.type;
    }
    return results;
}

+ (NSArray<VVToken *> *)enumerateWithVVDB:(NSString *)input mask:(VVTokenMask)mask
{
    if (input.length <= 0) return @[];
    NSString *source = input.lowercaseString;
    if (mask & VVTokenMaskTransform) source = source.simplifiedChineseString;
    const char *cSource = source.UTF8String ? : "";

    // generate cursors
    NSArray *cursors = [self cursorsWithCString:cSource];

    NSMutableArray *array = [NSMutableArray array];

    //MARK: VVTokenMaskEssential
    NSArray *tokens = [self wordTokensWithCString:cSource cursors:cursors mask:mask];
    [array addObjectsFromArray:tokens];

    //MARK: VVTokenMaskNumber
    if (mask & VVTokenMaskNumber) {
        NSArray *numtks = [self enumerateNumbers:source];
        [array addObjectsFromArray:numtks];
    }

    NSArray *results = [NSOrderedSet orderedSetWithArray:array].array;
    return results;
}

+ (NSArray<VVToken *> *)enumerateCString:(const char *)input method:(VVTokenMethod)method mask:(VVTokenMask)mask
{
    const char *source = input ? : "";
    NSString *string = [NSString stringWithUTF8String:source];
    return [self enumerate:string method:method mask:mask];
}

+ (NSArray<VVToken *> *)enumeratePinyins:(NSString *)fragment start:(int)start end:(int)end
{
    NSMutableArray *array = [NSMutableArray array];
    NSArray<NSString *> *pinyins = [fragment pinyinsForTokenize];
    for (NSString *py in pinyins) {
        const char *token = py.UTF8String ? : "";
        int len = (int)strlen(token);
        if (len <= 0 || [py isEqualToString:fragment]) continue;
        [array addObject:[VVToken token:py len:len start:start end:end]];
    }
    return array;
}

+ (NSArray<VVToken *> *)splitIntoPinyins:(NSString *)fragment start:(int)start
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

+ (NSArray<VVToken *> *)enumerateNumbers:(NSString *)whole
{
    const char *cString = whole.UTF8String ? : "";
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
        s_num = [NSMutableString string];
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
                [results addObject:[VVToken token:num len:len start:offset end:offset + (int)numstr.length]];
            }
        }
    }
    return results;
}

@end
